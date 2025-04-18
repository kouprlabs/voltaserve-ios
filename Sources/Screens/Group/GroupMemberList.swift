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

public struct GroupMemberList: View, ViewDataProvider, LoadStateProvider, TimerLifecycle, SessionDistributing,
    ListItemScrollable
{
    @EnvironmentObject private var sessionStore: SessionStore
    @ObservedObject private var groupStore: GroupStore
    @StateObject private var userStore = UserStore()
    @State private var addMemberIsPresentable = false
    @State private var searchText = ""

    public init(groupStore: GroupStore) {
        self.groupStore = groupStore
    }

    public var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else if let error {
                VOErrorMessage(error)
            } else {
                if let entities = userStore.entities {
                    Group {
                        if entities.count == 0 {
                            Text("There are no items.")
                                .foregroundStyle(.secondary)
                        } else {
                            List(entities, id: \.displayID) { member in
                                UserRow(
                                    member,
                                    pictureURL: userStore.urlForPicture(
                                        member.id,
                                        fileExtension: member.picture?.fileExtension
                                    )
                                )
                                .onAppear {
                                    onListItemAppear(member.id)
                                }
                                .tag(member.id)
                            }
                        }
                    }
                    .refreshable {
                        userStore.fetchNextPage(replace: true)
                    }
                    .searchable(text: $searchText)
                    .onChange(of: searchText) {
                        userStore.searchPublisher.send($1)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Members")
        .toolbar {
            if let group = groupStore.current, group.permission.ge(.owner) {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        addMemberIsPresentable = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $addMemberIsPresentable) {
            GroupMemberAdd(groupStore: groupStore)
        }
        .onAppear {
            if let group = groupStore.current {
                userStore.groupID = group.id
            }
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
        .onChange(of: userStore.query) {
            userStore.clear()
            userStore.fetchNextPage()
        }
    }

    // MARK: - LoadStateProvider

    public var isLoading: Bool {
        userStore.entitiesIsLoadingFirstTime
    }

    public var error: String? {
        userStore.entitiesError
    }

    // MARK: - ViewDataProvider

    public func onAppearOrChange() {
        fetchData()
    }

    public func fetchData() {
        userStore.fetchNextPage(replace: true)
    }

    // MARK: - TimerLifecycle

    public func startTimers() {
        userStore.startTimer()
    }

    public func stopTimers() {
        userStore.stopTimer()
    }

    // MARK: - SessionDistributing

    public func assignSessionToStores(_ session: VOSession.Value) {
        userStore.session = session
    }

    // MARK: - ListItemScrollable

    public func onListItemAppear(_ id: String) {
        if userStore.isEntityThreshold(id) {
            userStore.fetchNextPage()
        }
    }
}
