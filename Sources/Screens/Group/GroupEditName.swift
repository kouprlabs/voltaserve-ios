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

struct GroupEditName: View, FormValidatable, ErrorPresentable {
    @ObservedObject private var groupStore: GroupStore
    @Environment(\.dismiss) private var dismiss
    @State private var value = ""
    @State private var isSaving = false
    private let onCompletion: ((VOGroup.Entity) -> Void)?

    init(groupStore: GroupStore, onCompletion: ((VOGroup.Entity) -> Void)? = nil) {
        self.groupStore = groupStore
        self.onCompletion = onCompletion
    }

    var body: some View {
        if let current = groupStore.current {
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
            .onChange(of: groupStore.current) { _, newCurrent in
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
        guard let current = groupStore.current else { return }
        isSaving = true
        var updatedGroup: VOGroup.Entity?

        withErrorHandling {
            updatedGroup = try await groupStore.patchName(current.id, name: value)
            return true
        } success: {
            dismiss()
            if let onCompletion, let updatedGroup {
                onCompletion(updatedGroup)
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
        if let current = groupStore.current {
            return !normalizedValue.isEmpty && normalizedValue != current.name
        }
        return false
    }
}
