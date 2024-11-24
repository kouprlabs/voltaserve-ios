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
import VoltaserveCore

struct WorkspaceEditName: View, FormValidatable, ErrorPresentable {
    @ObservedObject private var workspaceStore: WorkspaceStore
    @Environment(\.dismiss) private var dismiss
    @State private var value = ""
    @State private var isSaving = false
    private let onCompletion: ((VOWorkspace.Entity) -> Void)?

    init(workspaceStore: WorkspaceStore, onCompletion: ((VOWorkspace.Entity) -> Void)? = nil) {
        self.workspaceStore = workspaceStore
        self.onCompletion = onCompletion
    }

    var body: some View {
        if let current = workspaceStore.current {
            Form {
                TextField("Name", text: $value)
                    .disabled(isSaving)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Change Name")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            performSave()
                        }
                        .disabled(!isValid())
                    }
                }
            }
            .voErrorSheet(isPresented: $errorIsPresented, message: errorMessage)
            .onAppear {
                value = current.name
            }
            .onChange(of: workspaceStore.current) { _, newCurrent in
                if let newCurrent {
                    value = newCurrent.name
                }
            }
        }
    }

    private var normalizedValue: String {
        value.trimmingCharacters(in: .whitespaces)
    }

    private func performSave() {
        guard let current = workspaceStore.current else { return }
        isSaving = true
        var updatedWorkspace: VOWorkspace.Entity?

        withErrorHandling {
            updatedWorkspace = try await workspaceStore.patchName(current.id, name: normalizedValue)
            return true
        } success: {
            dismiss()
            if let onCompletion, let updatedWorkspace {
                onCompletion(updatedWorkspace)
            }
        } failure: { message in
            errorMessage = message
            errorIsPresented = true
        } anyways: {
            isSaving = false
        }
    }

    // MARK: - ErrorPresentable

    @State var errorIsPresented: Bool = false
    @State var errorMessage: String?

    // MARK: - FormValidatable

    func isValid() -> Bool {
        if let current = workspaceStore.current,
            !normalizedValue.isEmpty,
            normalizedValue != current.name
        {
            return true
        }
        return false
    }
}
