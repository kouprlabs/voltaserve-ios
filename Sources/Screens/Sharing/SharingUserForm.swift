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

public struct SharingUserForm: View, FormValidatable, ErrorPresentable {
    @ObservedObject private var sharingStore: SharingStore
    @ObservedObject private var fileStore: FileStore
    @Environment(\.dismiss) private var dismiss
    @State private var user: VOUser.Entity?
    @State private var permission: VOPermission.Value?
    @State private var revokeConfirmationIsPresented = false
    @State private var isGranting = false
    @State private var isRevoking = false
    private let fileIDs: [String]
    private let organization: VOOrganization.Entity
    private let predefinedUser: VOUser.Entity?
    private let defaultPermission: VOPermission.Value?
    private let enableCancel: Bool
    private let enableRevoke: Bool

    public init(
        fileIDs: [String],
        organization: VOOrganization.Entity,
        sharingStore: SharingStore,
        fileStore: FileStore,
        predefinedUser: VOUser.Entity? = nil,
        defaultPermission: VOPermission.Value? = nil,
        enableCancel: Bool = false,
        enableRevoke: Bool = false
    ) {
        self.fileIDs = fileIDs
        self.organization = organization
        self.sharingStore = sharingStore
        self.fileStore = fileStore
        self.predefinedUser = predefinedUser
        self.defaultPermission = defaultPermission
        self.enableCancel = enableCancel
        self.enableRevoke = enableRevoke
    }

    public var body: some View {
        Form {
            Section(header: VOSectionHeader("User Permission")) {
                NavigationLink {
                    UserSelector(organizationID: organization.id, excludeMe: true) { user in
                        self.user = user
                    }
                } label: {
                    HStack {
                        Text("User")
                        if let user {
                            Spacer()
                            Text(user.fullName)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(predefinedUser != nil || isProcessing)
                Picker("Permission", selection: $permission) {
                    Text("Viewer")
                        .tag(VOPermission.Value.viewer)
                    Text("Editor")
                        .tag(VOPermission.Value.editor)
                    Text("Owner")
                        .tag(VOPermission.Value.owner)
                }
                .disabled(isProcessing)
            }
            if enableRevoke, fileIDs.count == 1 {
                Section(header: VOSectionHeader("Actions")) {
                    Button(role: .destructive) {
                        revokeConfirmationIsPresented = true
                    } label: {
                        HStack {
                            Text("Revoke Permission")
                            if isRevoking {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRevoking)
                    .confirmationDialog(
                        "Revoke Permission", isPresented: $revokeConfirmationIsPresented, titleVisibility: .visible
                    ) {
                        Button("Revoke", role: .destructive) {
                            performRevoke()
                        }
                    } message: {
                        Text("Are you sure you want to revoke this permission?")
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(fileIDs.count > 1 ? "Sharing (\(fileIDs.count)) Items" : "Sharing")
        .toolbar {
            if enableCancel {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isGranting {
                    ProgressView()
                } else {
                    Button("Apply") {
                        performGrant()
                    }
                    .disabled(!isValid() || isRevoking)
                }
            }
        }
        .onAppear {
            if let predefinedUser {
                user = predefinedUser
            }
            if let defaultPermission {
                permission = defaultPermission
            }
        }
        .voErrorSheet(isPresented: $errorIsPresented, message: errorMessage)
    }

    private var isProcessing: Bool {
        isGranting || isRevoking
    }

    private func performGrant() {
        guard let user, let permission else { return }
        withErrorHandling {
            try await sharingStore.grantUserPermission(ids: fileIDs, userID: user.id, permission: permission)
            try await sharingStore.syncUserPermissions()
            try await fileStore.syncEntities()
            return true
        } before: {
            isGranting = true
        } success: {
            dismiss()
        } failure: { message in
            errorMessage = message
            errorIsPresented = true
        } anyways: {
            isGranting = false
        }
    }

    private func performRevoke() {
        guard let user, fileIDs.count == 1, let fileID = fileIDs.first else { return }
        withErrorHandling {
            try await sharingStore.revokeUserPermission(id: fileID, userID: user.id)
            try await sharingStore.syncUserPermissions()
            try await fileStore.syncEntities()
            return true
        } before: {
            isRevoking = true
        } success: {
            dismiss()
        } failure: { message in
            errorMessage = message
            errorIsPresented = true
        } anyways: {
            isRevoking = false
        }
    }

    // MARK: - ErrorPresentable

    @State public var errorIsPresented = false
    @State public var errorMessage: String?

    // MARK: - FormValidatable

    public func isValid() -> Bool {
        user != nil && permission != nil
    }
}
