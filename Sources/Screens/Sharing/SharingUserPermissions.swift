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

public struct SharingUserPermissions: View, SessionDistributing {
    @EnvironmentObject private var sessionStore: SessionStore
    @ObservedObject private var sharingStore: SharingStore
    @ObservedObject private var fileStore: FileStore
    @StateObject private var userStore = UserStore()
    @State private var user: VOUser.Entity?
    @State private var permission: VOPermission.Value?
    private let fileID: String
    private let organization: VOOrganization.Entity

    public init(
        _ fileID: String,
        organization: VOOrganization.Entity,
        sharingStore: SharingStore,
        fileStore: FileStore
    ) {
        self.fileID = fileID
        self.organization = organization
        self.sharingStore = sharingStore
        self.fileStore = fileStore
    }

    public var body: some View {
        VStack {
            if let userPermissions = sharingStore.userPermissions {
                if userPermissions.isEmpty {
                    VStack {
                        Text("Not shared with any users.")
                            .foregroundStyle(.secondary)
                        NavigationLink {
                            SharingUserForm(
                                fileIDs: [fileID],
                                organization: organization,
                                sharingStore: sharingStore,
                                fileStore: fileStore
                            )
                        } label: {
                            Label("Share", systemImage: "plus")
                        }
                    }
                } else {
                    List(userPermissions, id: \.id) { userPermission in
                        NavigationLink {
                            SharingUserForm(
                                fileIDs: [fileID],
                                organization: organization,
                                sharingStore: sharingStore,
                                fileStore: fileStore,
                                predefinedUser: userPermission.user,
                                defaultPermission: userPermission.permission,
                                enableRevoke: true
                            )
                        } label: {
                            SharingUserRow(
                                userPermission,
                                userPictureURL: userStore.urlForPicture(
                                    userPermission.user.id,
                                    fileExtension: userPermission.user.picture?.fileExtension
                                )
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            userStore.organizationID = organization.id
            if let session = sessionStore.session {
                assignSessionToStores(session)
            }
        }
        .onChange(of: sessionStore.session) { _, newSession in
            if let newSession {
                assignSessionToStores(newSession)
            }
        }
    }

    // MARK: - SessionDistributing

    public func assignSessionToStores(_ session: VOSession.Value) {
        userStore.session = session
    }
}
