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

public struct SharingGroupForm: View, FormValidatable, ErrorPresentable {
    @ObservedObject private var sharingStore: SharingStore
    @ObservedObject private var fileStore: FileStore
    @Environment(\.dismiss) private var dismiss
    @State private var group: VOGroup.Entity?
    @State private var permission: VOPermission.Value?
    @State private var isGranting = false
    @State private var isRevoking = false
    @State private var revokeConfirmationIsPresented = false
    private let fileIDs: [String]
    private let organization: VOOrganization.Entity
    private let predefinedGroup: VOGroup.Entity?
    private let defaultPermission: VOPermission.Value?
    private let enableCancel: Bool
    private let enableRevoke: Bool

    public init(
        fileIDs: [String],
        organization: VOOrganization.Entity,
        sharingStore: SharingStore,
        fileStore: FileStore,
        predefinedGroup: VOGroup.Entity? = nil,
        defaultPermission: VOPermission.Value? = nil,
        enableCancel: Bool = false,
        enableRevoke: Bool = false
    ) {
        self.fileIDs = fileIDs
        self.organization = organization
        self.sharingStore = sharingStore
        self.fileStore = fileStore
        self.predefinedGroup = predefinedGroup
        self.defaultPermission = defaultPermission
        self.enableCancel = enableCancel
        self.enableRevoke = enableRevoke
    }

    public var body: some View {
        Form {
            Section(header: VOSectionHeader("Group Permission")) {
                NavigationLink {
                    GroupSelector(organizationID: organization.id) { group in
                        self.group = group
                    }
                } label: {
                    HStack {
                        Text("Group")
                        if let group {
                            Spacer()
                            Text(group.name)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(predefinedGroup != nil || isProcessing)
                Picker("Permission", selection: $permission) {
                    Text("Viewer").tag(VOPermission.Value.viewer)
                    Text("Editor").tag(VOPermission.Value.editor)
                    Text("Owner").tag(VOPermission.Value.owner)
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
            if let predefinedGroup {
                group = predefinedGroup
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
        guard let group, let permission else { return }
        withErrorHandling {
            try await sharingStore.grantGroupPermission(ids: fileIDs, groupID: group.id, permission: permission)
            try await sharingStore.syncGroupPermissions()
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
        guard let group, fileIDs.count == 1, let fileID = fileIDs.first else { return }
        withErrorHandling {
            try await sharingStore.revokeGroupPermission(id: fileID, groupID: group.id)
            try await sharingStore.syncGroupPermissions()
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
        group != nil && permission != nil
    }
}
