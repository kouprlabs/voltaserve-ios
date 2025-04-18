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

public struct OrganizationList: View, ViewDataProvider, LoadStateProvider, TimerLifecycle, SessionDistributing,
    ListItemScrollable
{
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var organizationStore = OrganizationStore()
    @StateObject private var accountStore = AccountStore()
    @StateObject private var invitationStore = InvitationStore()
    @State private var createIsPresented = false
    @State private var overviewIsPresented = false
    @State private var searchText = ""
    @State private var newOrganization: VOOrganization.Entity?

    public var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView()
                } else if let error {
                    VOErrorMessage(error)
                } else {
                    if let entities = organizationStore.entities {
                        Group {
                            if entities.count == 0 {
                                Text("There are no items.")
                                    .foregroundStyle(.secondary)
                            } else {
                                List(entities, id: \.displayID) { organization in
                                    NavigationLink {
                                        OrganizationOverview(organization, organizationStore: organizationStore)
                                    } label: {
                                        OrganizationRow(organization)
                                            .onAppear {
                                                onListItemAppear(organization.id)
                                            }
                                    }
                                    .tag(organization.id)
                                }
                            }
                        }
                        .refreshable {
                            organizationStore.fetchNextPage(replace: true)
                        }
                        .searchable(text: $searchText)
                        .onChange(of: searchText) {
                            organizationStore.searchPublisher.send($1)
                        }
                    }
                }
            }
            .navigationTitle("Organizations")
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
                OrganizationCreate(organizationStore: organizationStore) { newOrganization in
                    self.newOrganization = newOrganization
                    overviewIsPresented = true
                }
            }
            .navigationDestination(isPresented: $overviewIsPresented) {
                if let newOrganization {
                    OrganizationOverview(newOrganization, organizationStore: organizationStore)
                }
            }
        }
        .onAppear {
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
        .onChange(of: organizationStore.query) {
            organizationStore.clear()
            organizationStore.fetchNextPage()
        }
    }

    // MARK: - LoadStateProvider

    public var isLoading: Bool {
        organizationStore.entitiesIsLoadingFirstTime || accountStore.identityUserIsLoading
            || invitationStore.incomingCountIsLoading
    }

    public var error: String? {
        organizationStore.entitiesError ?? accountStore.identityUserError ?? invitationStore.incomingCountError
    }

    // MARK: - ViewDataProvider

    public func onAppearOrChange() {
        fetchData()
    }

    public func fetchData() {
        organizationStore.fetchNextPage(replace: true)
        accountStore.fetchIdentityUser()
        invitationStore.fetchIncomingCount()
    }

    // MARK: - TimerLifecycle

    public func startTimers() {
        organizationStore.startTimer()
        accountStore.startTimer()
        invitationStore.startTimer()
    }

    public func stopTimers() {
        organizationStore.stopTimer()
        accountStore.stopTimer()
        invitationStore.stopTimer()
    }

    // MARK: - SessionDistributing

    public func assignSessionToStores(_ session: VOSession.Value) {
        organizationStore.session = session
        accountStore.session = session
        invitationStore.session = session
    }

    // MARK: - ListItemScrollable

    public func onListItemAppear(_ id: String) {
        if organizationStore.isEntityThreshold(id) {
            organizationStore.fetchNextPage()
        }
    }
}
