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

struct WorkspaceEditStorageCapacity: View, FormValidatable, ErrorPresentable {
    @ObservedObject private var workspaceStore: WorkspaceStore
    @Environment(\.dismiss) private var dismiss
    @State private var value: Int?
    @State private var isSaving = false

    init(workspaceStore: WorkspaceStore) {
        self.workspaceStore = workspaceStore
    }

    var body: some View {
        if let current = workspaceStore.current {
            Form {
                VOStoragePicker(value: $value)
                    .disabled(isSaving)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Change Storage Capacity")
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
                value = current.storageCapacity
            }
            .onChange(of: workspaceStore.current) { _, newCurrent in
                if let newCurrent {
                    value = newCurrent.storageCapacity
                }
            }
        }
    }

    private func performSave() {
        guard let value else { return }
        isSaving = true

        withErrorHandling {
            _ = try await workspaceStore.patchStorageCapacity(storageCapacity: value)
            return true
        } success: {
            dismiss()
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
        if let value, let current = workspaceStore.current {
            return value > 0 && current.storageCapacity != value
        }
        return false
    }
}
