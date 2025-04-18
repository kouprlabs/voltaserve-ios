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

public struct WorkspaceSettings: View, ViewDataProvider, LoadStateProvider, ErrorPresentable {
    @EnvironmentObject private var sessionStore: SessionStore
    @ObservedObject private var workspaceStore: WorkspaceStore
    @Environment(\.dismiss) private var dismiss
    @State private var deleteConfirmationIsPresentable = false
    @State private var isDeleting = false
    @Binding private var shouldDismissParent: Bool

    public init(workspaceStore: WorkspaceStore, shouldDismissParent: Binding<Bool>) {
        self.workspaceStore = workspaceStore
        self._shouldDismissParent = shouldDismissParent
    }

    public var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else if let error {
                VOErrorMessage(error)
            } else {
                if let current = workspaceStore.current {
                    Form {
                        Section(header: VOSectionHeader("Storage")) {
                            VStack(alignment: .leading) {
                                if let storageUsage = workspaceStore.storageUsage {
                                    // swift-format-ignore
                                    // swiftlint:disable:next line_length
                                    Text("\(storageUsage.bytes.prettyBytes()) of \(storageUsage.maxBytes.prettyBytes()) used")
                                    ProgressView(value: Double(storageUsage.percentage) / 100.0)
                                } else {
                                    Text("Calculating…")
                                    ProgressView()
                                }
                            }
                            NavigationLink(destination: WorkspaceEditStorageCapacity(workspaceStore: workspaceStore)) {
                                HStack {
                                    Text("Capacity")
                                    Spacer()
                                    Text("\(current.storageCapacity.prettyBytes())")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(isDeleting || current.permission.lt(.owner))
                        }
                        Section(header: VOSectionHeader("Basics")) {
                            NavigationLink {
                                WorkspaceEditName(workspaceStore: workspaceStore) { updatedWorkspace in
                                    workspaceStore.current = updatedWorkspace
                                    if let index = workspaceStore.entities?.firstIndex(where: {
                                        $0.id == updatedWorkspace.id
                                    }) {
                                        workspaceStore.entities?[index] = updatedWorkspace
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
                                    deleteConfirmationIsPresentable = true
                                } label: {
                                    VOFormButtonLabel("Delete Workspace", isLoading: isDeleting)
                                }
                                .disabled(isDeleting)
                                .confirmationDialog("Delete Workspace", isPresented: $deleteConfirmationIsPresentable) {
                                    Button("Delete", role: .destructive) {
                                        performDelete()
                                    }
                                } message: {
                                    Text("Are you sure you want to delete this workspace?")
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            if sessionStore.session != nil {
                onAppearOrChange()
            }
        }
        .onChange(of: sessionStore.session) { _, newSession in
            if newSession != nil {
                onAppearOrChange()
            }
        }
        .voErrorSheet(isPresented: $errorIsPresented, message: errorMessage)
    }

    private func performDelete() {
        let current = workspaceStore.current
        withErrorHandling {
            try await workspaceStore.delete()
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
        workspaceStore.entities?.removeAll(where: { $0.id == id })
    }

    // MARK: - LoadStateProvider

    public var isLoading: Bool {
        workspaceStore.storageUsageIsLoading
    }

    public var error: String? {
        workspaceStore.storageUsageError
    }

    // MARK: - ErrorPresentable

    @State public var errorIsPresented = false
    @State public var errorMessage: String?

    // MARK: - ViewDataProvider

    public func onAppearOrChange() {
        fetchData()
    }

    public func fetchData() {
        workspaceStore.fetchStorageUsage()
    }
}
