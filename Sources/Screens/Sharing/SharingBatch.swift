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

struct SharingBatch: View, SessionDistributing {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var sharingStore = SharingStore()
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Tag = .users
    @State private var user: VOUser.Entity?
    @State private var group: VOGroup.Entity?
    @State private var permission: VOPermission.Value?
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorTitle: String?
    @State private var errorMessage: String?
    private let fileIDs: [String]
    private let organization: VOOrganization.Entity

    public init(_ fileIDs: [String], organization: VOOrganization.Entity) {
        self.fileIDs = fileIDs
        self.organization = organization
    }

    public var body: some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            TabView(selection: $selection) {
                Tab("Users", systemImage: "person", value: Tag.users) {
                    NavigationStack {
                        SharingUserForm(
                            fileIDs: fileIDs,
                            organization: organization,
                            sharingStore: sharingStore,
                            enableCancel: true
                        )
                    }
                }
                Tab("Groups", systemImage: "person.2", value: Tag.groups) {
                    NavigationStack {
                        SharingGroupForm(
                            fileIDs: fileIDs,
                            organization: organization,
                            sharingStore: sharingStore,
                            enableCancel: true
                        )
                    }
                }
            }
            .onAppear {
                if let session = sessionStore.session {
                    assignSessionToStores(session)
                }
            }
        }
    }

    public enum Tag {
        case users
        case groups
    }

    // MARK: - SessionDistributing

    public func assignSessionToStores(_ session: VOSession.Value) {
        sharingStore.session = session
    }
}
