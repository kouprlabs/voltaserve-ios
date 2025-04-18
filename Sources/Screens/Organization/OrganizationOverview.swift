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

public struct OrganizationOverview: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @ObservedObject private var organizationStore: OrganizationStore
    @Environment(\.dismiss) private var dismiss
    @State private var shouldDismissSelf = false
    private let organization: VOOrganization.Entity

    public init(_ organization: VOOrganization.Entity, organizationStore: OrganizationStore) {
        self.organization = organization
        self.organizationStore = organizationStore
    }

    public var body: some View {
        VStack {
            VStack {
                VOAvatar(name: organization.name, size: 100)
                    .padding()
                Form {
                    NavigationLink {
                        OrganizationMemberList(organizationStore: organizationStore)
                    } label: {
                        Label("Members", systemImage: "person.2")
                    }
                    if organization.permission.ge(.owner) {
                        NavigationLink {
                            InvitationOutgoingList(organization.id)
                        } label: {
                            Label("Invitations", systemImage: "paperplane")
                        }
                    }
                    NavigationLink {
                        OrganizationSettings(
                            organizationStore: organizationStore, shouldDismissParent: $shouldDismissSelf)
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(organization.name)
        .onAppear {
            organizationStore.current = organization
        }
        .onChange(of: shouldDismissSelf) { _, newValue in
            if newValue {
                dismiss()
            }
        }
    }
}
