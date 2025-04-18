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

public struct GroupSelector: View, ViewDataProvider, LoadStateProvider, TimerLifecycle, SessionDistributing,
    ListItemScrollable
{
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var groupStore = GroupStore()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    private let onCompletion: ((VOGroup.Entity) -> Void)?
    private let organizationID: String?

    public init(organizationID: String?, onCompletion: ((VOGroup.Entity) -> Void)? = nil) {
        self.organizationID = organizationID
        self.onCompletion = onCompletion
    }

    public var body: some View {
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
                                Button {
                                    dismiss()
                                    onCompletion?(group)
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Select Group")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if groupStore.entitiesIsLoading {
                    ProgressView()
                }
            }
        }
        .onAppear {
            groupStore.organizationID = organizationID
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
        groupStore.entitiesIsLoadingFirstTime
    }

    public var error: String? {
        groupStore.entitiesError
    }

    // MARK: - ViewDataProvider

    public func onAppearOrChange() {
        fetchData()
    }

    public func fetchData() {
        groupStore.fetchNextPage(replace: true)
    }

    // MARK: - TimerLifecycle

    public func startTimers() {
        groupStore.startTimer()
    }

    public func stopTimers() {
        groupStore.stopTimer()
    }

    // MARK: - SessionDistributing

    public func assignSessionToStores(_ session: VOSession.Value) {
        groupStore.session = session
    }

    // MARK: - ListItemScrollable

    public func onListItemAppear(_ id: String) {
        if groupStore.isEntityThreshold(id) {
            groupStore.fetchNextPage()
        }
    }
}
