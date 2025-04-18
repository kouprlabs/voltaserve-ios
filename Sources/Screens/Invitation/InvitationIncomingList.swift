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

public struct InvitationIncomingList: View, ViewDataProvider, LoadStateProvider, TimerLifecycle, SessionDistributing,
    ListItemScrollable
{
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var invitationStore = InvitationStore()
    @State private var showInfo = false
    @State private var invitation: VOInvitation.Entity?

    public var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else if let error {
                VOErrorMessage(error)
            } else {
                if let entities = invitationStore.entities {
                    Group {
                        if entities.isEmpty {
                            Text("There are no items.")
                                .foregroundStyle(.secondary)
                        } else {
                            List(entities, id: \.displayID) { invitation in
                                NavigationLink {
                                    InvitationOverview(
                                        invitation,
                                        invitationStore: invitationStore,
                                        isAcceptableDeclinable: true
                                    )
                                } label: {
                                    InvitationIncomingRow(invitation)
                                        .onAppear {
                                            onListItemAppear(invitation.id)
                                        }
                                }
                                .tag(invitation.id)
                            }
                        }
                    }
                    .refreshable {
                        invitationStore.fetchNextPage(replace: true)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Invitations")
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
    }

    // MARK: - LoadStateProvider

    public var isLoading: Bool {
        invitationStore.entitiesIsLoadingFirstTime
    }

    public var error: String? {
        invitationStore.entitiesError
    }

    // MARK: - ViewDataProvider

    public func onAppearOrChange() {
        fetchData()
    }

    public func fetchData() {
        invitationStore.fetchNextPage(replace: true)
    }

    // MARK: - TimerLifecycle

    public func startTimers() {
        invitationStore.startTimer()
    }

    public func stopTimers() {
        invitationStore.stopTimer()
    }

    // MARK: - SessionDistributing

    public func assignSessionToStores(_ session: VOSession.Value) {
        invitationStore.session = session
    }

    // MARK: - ListItemScrollable

    public func onListItemAppear(_ id: String) {
        if invitationStore.isEntityThreshold(id) {
            invitationStore.fetchNextPage()
        }
    }
}
