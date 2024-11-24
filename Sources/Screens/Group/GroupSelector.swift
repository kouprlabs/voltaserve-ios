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
import VoltaserveCore

struct GroupSelector: View, ViewDataProvider, LoadStateProvider, TimerLifecycle, TokenDistributing, ListItemScrollable {
    @EnvironmentObject private var tokenStore: TokenStore
    @StateObject private var groupStore = GroupStore()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    private let onCompletion: ((VOGroup.Entity) -> Void)?
    private let organizationID: String?

    init(organizationID: String?, onCompletion: ((VOGroup.Entity) -> Void)? = nil) {
        self.organizationID = organizationID
        self.onCompletion = onCompletion
    }

    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
            } else if let error {
                VOErrorMessage(error)
            } else {
                if let entities = groupStore.entities {
                    Group {
                        if entities.count == 0 {
                            Text("There are no groups.")
                        } else {
                            List {
                                ForEach(entities, id: \.id) { group in
                                    Button {
                                        dismiss()
                                        onCompletion?(group)
                                    } label: {
                                        GroupRow(group)
                                            .onAppear {
                                                onListItemAppear(group.id)
                                            }
                                    }
                                }
                            }
                            .searchable(text: $groupStore.searchText)
                            .onChange(of: groupStore.searchText) {
                                groupStore.searchPublisher.send($1)
                            }
                        }
                    }
                    .refreshable {
                        groupStore.fetchNextPage(replace: true)
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
        .onChange(of: groupStore.query) {
            groupStore.clear()
            groupStore.fetchNextPage()
        }
    }

    // MARK: - LoadStateProvider

    var isLoading: Bool {
        groupStore.entities == nil
    }

    var error: String? {
        groupStore.entitiesError
    }

    // MARK: - ViewDataProvider

    func onAppearOrChange() {
        fetchData()
    }

    func fetchData() {
        groupStore.fetchNextPage(replace: true)
    }

    // MARK: - TimerLifecycle

    func startTimers() {
        groupStore.startTimer()
    }

    func stopTimers() {
        groupStore.stopTimer()
    }

    // MARK: - TokenDistributing

    func assignTokenToStores(_ token: VOToken.Value) {
        groupStore.token = token
    }

    // MARK: - ListItemScrollable

    func onListItemAppear(_ id: String) {
        if groupStore.isEntityThreshold(id) {
            groupStore.fetchNextPage()
        }
    }
}
