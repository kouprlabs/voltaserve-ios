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

public struct GroupSettings: View, ErrorPresentable {
    @EnvironmentObject private var sessionStore: SessionStore
    @ObservedObject private var groupStore: GroupStore
    @Environment(\.dismiss) private var dismiss
    @State private var deleteConfirmationIsPresented = false
    @State private var isDeleting = false
    @Binding private var shouldDismissParent: Bool

    public init(groupStore: GroupStore, shouldDismissParent: Binding<Bool>) {
        self.groupStore = groupStore
        self._shouldDismissParent = shouldDismissParent
    }

    public var body: some View {
        Group {
            if let current = groupStore.current {
                Form {
                    Section(header: VOSectionHeader("Basics")) {
                        NavigationLink {
                            GroupEditName(groupStore: groupStore) { updatedGroup in
                                groupStore.current = updatedGroup
                                if let index = groupStore.entities?.firstIndex(where: { $0.id == updatedGroup.id }) {
                                    groupStore.entities?[index] = updatedGroup
                                }
                            }
                        } label: {
                            HStack {
                                Text("Name")
                                Spacer()
                                Text(current.name)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(isDeleting || current.permission.lt(.editor))
                    }
                    if current.permission.ge(.owner) {
                        Section(header: VOSectionHeader("Advanced")) {
                            Button(role: .destructive) {
                                deleteConfirmationIsPresented = true
                            } label: {
                                VOFormButtonLabel("Delete Group", isLoading: isDeleting)
                            }
                            .disabled(isDeleting)
                            .confirmationDialog("Delete Group", isPresented: $deleteConfirmationIsPresented) {
                                Button("Delete", role: .destructive) {
                                    performDelete()
                                }
                            } message: {
                                Text("Are you sure you want to delete this group?")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .voErrorSheet(isPresented: $errorIsPresented, message: errorMessage)
    }

    private func performDelete() {
        let current = groupStore.current
        withErrorHandling {
            try await groupStore.delete()
            return true
        } before: {
            isDeleting = true
        } success: {
            dismiss()
            if let current {
                reflectDeleteInStore(current.id)
            }
            shouldDismissParent = true
        } failure: { message in
            errorMessage = message
            errorIsPresented = true
        } anyways: {
            isDeleting = false
        }
    }

    private func reflectDeleteInStore(_ id: String) {
        groupStore.entities?.removeAll(where: { $0.id == id })
    }

    // MARK: - ErrorPresentable

    @State public var errorIsPresented = false
    @State public var errorMessage: String?
}
