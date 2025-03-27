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

public struct WorkspaceList: View, ViewDataProvider, LoadStateProvider, TimerLifecycle, TokenDistributing,
    ListItemScrollable
{
    @EnvironmentObject private var tokenStore: TokenStore
    @StateObject private var workspaceStore = WorkspaceStore()
    @StateObject private var accountStore = AccountStore()
    @StateObject private var invitationStore = InvitationStore()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var createIsPresented = false
    @State private var overviewIsPresented = false
    @State private var newWorkspace: VOWorkspace.Entity?

    public var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView()
                } else if let error {
                    VOErrorMessage(error)
                } else {
                    if let entities = workspaceStore.entities {
                        Group {
                            if entities.count == 0 {
                                Text("There are no items.")
                                    .foregroundStyle(.secondary)
                            } else {
                                List(entities, id: \.id) { workspace in
                                    NavigationLink {
                                        WorkspaceOverview(workspace, workspaceStore: workspaceStore)
                                    } label: {
                                        WorkspaceRow(workspace)
                                            .onAppear {
                                                onListItemAppear(workspace.id)
                                            }
                                    }
                                }
                            }
                        }
                        .refreshable {
                            workspaceStore.fetchNextPage(replace: true)
                        }
                        .searchable(text: $searchText)
                        .onChange(of: searchText) {
                            workspaceStore.searchPublisher.send($1)
                        }
                    }
                }
            }
            .navigationTitle("Workspaces")
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
                WorkspaceCreate(workspaceStore: workspaceStore) { newWorkspace in
                    self.newWorkspace = newWorkspace
                    overviewIsPresented = true
                }
            }
            .navigationDestination(isPresented: $overviewIsPresented) {
                if let newWorkspace {
                    WorkspaceOverview(newWorkspace, workspaceStore: workspaceStore)
                }
            }
        }
        .onAppear {
            accountStore.tokenStore = tokenStore
            if let token = tokenStore.token {
                assignTokenToStores(token)
                startTimers()
                onAppearOrChange()
            }
        }
        .onDisappear {
            stopTimers()
        }
        .onChange(of: tokenStore.token) { _, newToken in
            if let newToken {
                assignTokenToStores(newToken)
                onAppearOrChange()
            }
        }
        .onChange(of: workspaceStore.query) {
            workspaceStore.clear()
            workspaceStore.fetchNextPage()
        }
    }

    // MARK: - LoadStateProvider

    public var isLoading: Bool {
        workspaceStore.entitiesIsLoadingFirstTime || accountStore.identityUserIsLoading
            || invitationStore.incomingCountIsLoading
    }

    public var error: String? {
        workspaceStore.entitiesError ?? accountStore.identityUserError ?? invitationStore.incomingCountError
    }

    // MARK: - ViewDataProvider

    public func onAppearOrChange() {
        fetchData()
    }

    public func fetchData() {
        workspaceStore.fetchNextPage(replace: true)
        accountStore.fetchIdentityUser()
        invitationStore.fetchIncomingCount()
    }

    // MARK: - TimerLifecycle

    public func startTimers() {
        workspaceStore.startTimer()
        accountStore.startTimer()
        invitationStore.startTimer()
    }

    public func stopTimers() {
        workspaceStore.stopTimer()
        accountStore.stopTimer()
        invitationStore.stopTimer()
    }

    // MARK: - TokenDistributing

    public func assignTokenToStores(_ token: VOToken.Value) {
        workspaceStore.token = token
        accountStore.token = token
        invitationStore.token = token
    }

    // MARK: - ListItemScrollable

    public func onListItemAppear(_ id: String) {
        if workspaceStore.isEntityThreshold(id) {
            workspaceStore.fetchNextPage()
        }
    }
}
