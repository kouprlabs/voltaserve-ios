// Copyright (c) 2024 Anass Bouassaba.
//
// Use of this software is governed by the Business Source License
// included in the file LICENSE in the root of this repository.
//
// As of the Change Date specified in that file, in accordance with
// the Business Source License, use of this software will be governed
// by the GNU Affero General Public License v3.0 only, included in the file
// AGPL-3.0-only in the root of this repository.

import Combine
import SwiftUI

public struct GroupList: View, ViewDataProvider, LoadStateProvider, TimerLifecycle, SessionDistributing,
    ListItemScrollable
{
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var groupStore = GroupStore()
    @StateObject private var accountStore = AccountStore()
    @StateObject private var invitationStore = InvitationStore()
    @State private var createIsPresented = false
    @State private var overviewIsPresented = false
    @State private var searchText = ""
    @State private var newGroup: VOGroup.Entity?

    public var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView()
                } else if let error {
                    VOErrorMessage(error)
                } else {
                    if let entities = groupStore.entities {
                        Group {
                            if entities.count == 0 {
                                Text("There are no items.")
                                    .foregroundStyle(.secondary)
                            } else {
                                List(entities, id: \.displayID) { group in
                                    NavigationLink {
                                        GroupOverview(group, groupStore: groupStore)
                                    } label: {
                                        GroupRow(group)
                                            .onAppear {
                                                onListItemAppear(group.id)
                                            }
                                    }
                                    .tag(group.id)
                                }
                            }
                        }
                        .refreshable {
                            groupStore.fetchNextPage(replace: true)
                        }
                        .searchable(text: $searchText)
                        .onChange(of: searchText) {
                            groupStore.searchPublisher.send($1)
                        }
                    }
                }
            }
            .navigationTitle("Groups")
            .accountToolbar(accountStore: accountStore, invitationStore: invitationStore)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        createIsPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $createIsPresented) {
                GroupCreate(groupStore: groupStore) { newGroup in
                    self.newGroup = newGroup
                    overviewIsPresented = true
                }
            }
            .navigationDestination(isPresented: $overviewIsPresented) {
                if let newGroup {
                    GroupOverview(newGroup, groupStore: groupStore)
                }
            }
        }
        .onAppear {
            accountStore.sessionStore = sessionStore
            if let session = sessionStore.session {
                assignSessionToStores(session)
                startTimers()
                onAppearOrChange()
            }
        }
        .onDisappear {
            stopTimers()
        }
        .onChange(of: sessionStore.session) { _, newSession in
            if let newSession {
                assignSessionToStores(newSession)
                onAppearOrChange()
            }
        }
        .onChange(of: groupStore.query) {
            groupStore.clear()
            groupStore.fetchNextPage()
        }
    }

    // MARK: - LoadStateProvider

    public var isLoading: Bool {
        groupStore.entitiesIsLoadingFirstTime || accountStore.identityUserIsLoading
            || invitationStore.incomingCountIsLoading
    }

    public var error: String? {
        groupStore.entitiesError ?? accountStore.identityUserError ?? invitationStore.incomingCountError
    }

    // MARK: - ViewDataProvider

    public func onAppearOrChange() {
        fetchData()
    }

    public func fetchData() {
        groupStore.fetchNextPage(replace: true)
        accountStore.fetchIdentityUser()
        invitationStore.fetchIncomingCount()
    }

    // MARK: - TimerLifecycle

    public func startTimers() {
        groupStore.startTimer()
        accountStore.startTimer()
        invitationStore.startTimer()
    }

    public func stopTimers() {
        groupStore.stopTimer()
        accountStore.stopTimer()
        invitationStore.stopTimer()
    }

    // MARK: - SessionDistributing

    public func assignSessionToStores(_ session: VOSession.Value) {
        groupStore.session = session
        accountStore.session = session
        invitationStore.session = session
    }

    // MARK: - ListItemScrollable

    public func onListItemAppear(_ id: String) {
        if groupStore.isEntityThreshold(id) {
            groupStore.fetchNextPage()
        }
    }
}
