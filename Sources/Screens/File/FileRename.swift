// Copyright (c) 2024 Anass Bouassaba.
//
// Use of this software is governed by the Business Source License
// included in the file LICENSE in the root of this repository.
//
// As of the Change Date specified in that file, in accordance with
// the Business Source License, use of this software will be governed
// by the GNU Affero General Public License v3.0 only, included in the file
// AGPL-3.0-only in the root of this repository.

import SwiftUI

public struct FileRename: View, LoadStateProvider, SessionDistributing, FormValidatable, ErrorPresentable {
    @EnvironmentObject private var sessionStore: SessionStore
    @ObservedObject private var fileStore: FileStore
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var value = ""
    private let file: VOFile.Entity
    private let onCompletion: ((VOFile.Entity) -> Void)?

    public init(_ file: VOFile.Entity, fileStore: FileStore, onCompletion: ((VOFile.Entity) -> Void)? = nil) {
        self.fileStore = fileStore
        self.file = file
        self.onCompletion = onCompletion
    }

    public var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView()
                } else if let error {
                    VOErrorMessage(error)
                } else {
                    if !value.isEmpty {
                        Form {
                            TextField("Name", text: $value)
                                .disabled(isProcessing)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Rename")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isProcessing {
                        ProgressView()
                    } else {
                        Button("Save") {
                            performRename()
                        }
                        .disabled(!isValid())
                    }
                }
            }
        }
        .onAppear {
            value = file.name
            if let session = sessionStore.session {
                assignSessionToStores(session)
            }
        }
        .onChange(of: sessionStore.session) { _, newSession in
            if let newSession {
                assignSessionToStores(newSession)
            }
        }
        .voErrorSheet(isPresented: $errorIsPresented, message: errorMessage)
    }

    private var normalizedValue: String {
        value.trimmingCharacters(in: .whitespaces)
    }

    private func performRename() {
        var updatedFile: VOFile.Entity?
        withErrorHandling {
            updatedFile = try await fileStore.patchName(file.id, name: normalizedValue)
            if let updatedFile, updatedFile.name != file.name {
                reflectRenameInStore(updatedFile)
                await try fileStore.syncEntities()
            }
            return true
        } before: {
            isProcessing = true
        } success: {
            dismiss()
            if let onCompletion, let updatedFile {
                onCompletion(updatedFile)
            }
        } failure: { message in
            errorMessage = message
            errorIsPresented = true
        } anyways: {
            isProcessing = false
            fileStore.selection = []
        }
    }

    private func reflectRenameInStore(_ updatedFile: VOFile.Entity) {
        if let index = fileStore.entities?.firstIndex(where: { $0.id == updatedFile.id }) {
            fileStore.entities?[index] = updatedFile
        }
    }

    // MARK: - LoadStateProvider

    public var isLoading: Bool {
        fileStore.fileIsLoading
    }

    public var error: String? {
        fileStore.fileError
    }

    // MARK: - ErrorPresentable

    @State public var errorIsPresented = false
    @State public var errorMessage: String?

    // MARK: - SessionDistributing

    public func assignSessionToStores(_ session: VOSession.Value) {
        fileStore.session = session
    }

    // MARK: - FormValidatable

    public func isValid() -> Bool {
        if let file = fileStore.file {
            return !normalizedValue.isEmpty && normalizedValue != file.name
        }
        return false
    }
}
