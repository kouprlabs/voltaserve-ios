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

public struct SharingGroupPermissions: View {
    @ObservedObject private var sharingStore: SharingStore
    @State private var group: VOGroup.Entity?
    @State private var permission: VOPermission.Value?
    private let fileID: String
    private let organization: VOOrganization.Entity

    public init(_ fileID: String, organization: VOOrganization.Entity, sharingStore: SharingStore) {
        self.fileID = fileID
        self.organization = organization
        self.sharingStore = sharingStore
    }

    public var body: some View {
        if let groupPermissions = sharingStore.groupPermissions {
            if groupPermissions.isEmpty {
                Text("Not shared with any groups.")
            } else {
                List(groupPermissions, id: \.id) { groupPermission in
                    NavigationLink {
                        SharingGroupForm(
                            fileIDs: [fileID],
                            organization: organization,
                            sharingStore: sharingStore,
                            predefinedGroup: groupPermission.group,
                            defaultPermission: groupPermission.permission,
                            enableRevoke: true
                        )
                    } label: {
                        SharingGroupRow(groupPermission)
                    }
                }
            }
        }
    }
}
