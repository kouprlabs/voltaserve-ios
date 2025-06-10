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

public struct FileDelete: View {
    @ObservedObject private var fileStore: FileStore
    @Environment(\.dismiss) private var dismiss
    @State private var errorIsPresented = false
    @State private var errorSeverity: ErrorSeverity?
    @State private var errorMessage: String?
    @State private var isDone = false

    public init(fileStore: FileStore) {
        self.fileStore = fileStore
    }

    public var body: some View {
        VStack {
            if errorIsPresented {
                if errorSeverity == .full {
                    VOErrorIcon()
                    if let errorMessage {
                        Text(errorMessage)
                    }
                    Button {
                        dismiss()
                    } label: {
                        VOButtonLabel("Done")
                    }
                    .voSecondaryButton()
                    .padding(.horizontal)
                } else if errorSeverity == .partial {
                    VOWarningIcon()
                    if let errorMessage {
                        Text(errorMessage)
                    }
                    Button {
                        dismiss()
                    } label: {
                        VOButtonLabel("Done")
                    }
                    .voSecondaryButton()
                    .padding(.horizontal)
                }
            } else {
                VOSheetProgressView()
                if fileStore.selection.count > 1 {
                    Text("Deleting \(fileStore.selection.count) items.")
                } else {
                    Text("Deleting item.")
                }
            }
        }
        .onAppear {
            performDelete()
        }
        .presentationDetents([.fraction(0.25)])
        .interactiveDismissDisabled(!isDone)
    }

    private func performDelete() {
        var result: VOFile.DeleteResult?
        withErrorHandling(delaySeconds: 1) {
            result = try await fileStore.delete(Array(fileStore.selection))
            if let result {
                if !result.succeeded.isEmpty {
                    reflectDeleteInStore(result)
                }
                if result.failed.isEmpty {
                    return true
                } else {
                    if result.failed.count > 1 {
                        errorMessage = "Failed to delete \(result.failed.count) items."
                    } else {
                        errorMessage = "Failed to delete item."
                    }
                    if result.failed.count < fileStore.selection.count {
                        errorSeverity = .partial
                    } else if result.failed.count == fileStore.selection.count {
                        errorSeverity = .full
                    }
                    errorIsPresented = true
                }
            }
            return false
        } success: {
            errorIsPresented = false
            dismiss()
        } failure: { message in
            errorMessage = message
            errorSeverity = .full
            errorIsPresented = true
        } anyways: {
            fileStore.selection = []
            isDone = true
        }
    }

    private func reflectDeleteInStore(_ result: VOFile.DeleteResult) {
        fileStore.entities?.removeAll(where: { entity in
            result.succeeded.contains(where: { entity.id == $0 })
        })
    }

    private enum ErrorSeverity {
        case full
        case partial
    }
}
