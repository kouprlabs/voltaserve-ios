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

public struct GroupOverview: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @ObservedObject private var groupStore: GroupStore
    @Environment(\.dismiss) private var dismiss
    @State private var shouldDismissSelf = false
    private let group: VOGroup.Entity

    public init(_ group: VOGroup.Entity, groupStore: GroupStore) {
        self.group = group
        self.groupStore = groupStore
    }

    public var body: some View {
        VStack {
            VStack {
                VOAvatar(name: group.name, size: 100)
                    .padding()
                Form {
                    NavigationLink {
                        GroupMemberList(groupStore: groupStore)
                    } label: {
                        Label("Members", systemImage: "person.2")
                    }
                    NavigationLink {
                        GroupSettings(groupStore: groupStore, shouldDismissParent: $shouldDismissSelf)
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(group.name)
        .onAppear {
            groupStore.current = group
        }
        .onChange(of: shouldDismissSelf) { _, newValue in
            if newValue {
                dismiss()
            }
        }
    }
}
