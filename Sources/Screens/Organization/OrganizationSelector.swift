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

public struct OrganizationSelector: View, ViewDataProvider, LoadStateProvider, TimerLifecycle, TokenDistributing,
    ListItemScrollable
{
    @EnvironmentObject private var tokenStore: TokenStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var organizationStore = OrganizationStore()
    @State private var selection: String?
    @State private var searchText = ""
    private let onCompletion: ((VOOrganization.Entity) -> Void)?

    public init(onCompletion: ((VOOrganization.Entity) -> Void)? = nil) {
        self.onCompletion = onCompletion
    }

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
                                List(selection: $selection) {
                                    ForEach(entities, id: \.displayID) { organization in
                                        Button {
                                            dismiss()
                                            onCompletion?(organization)
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
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Select Organization")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if organizationStore.entitiesIsLoading {
                        ProgressView()
                    }
                }
            }
        }
        .onAppear {
            organizationStore.clear()
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
        .onChange(of: organizationStore.query) {
            organizationStore.clear()
            organizationStore.fetchNextPage()
        }
    }

    // MARK: - LoadStateProvider

    public var isLoading: Bool {
        organizationStore.entitiesIsLoadingFirstTime
    }

    public var error: String? {
        organizationStore.entitiesError
    }

    // MARK: - ViewDataProvider

    public func onAppearOrChange() {
        fetchData()
    }

    public func fetchData() {
        organizationStore.fetchNextPage(replace: true)
    }

    // MARK: - TimerLifecycle

    public func startTimers() {
        organizationStore.startTimer()
    }

    public func stopTimers() {
        organizationStore.stopTimer()
    }

    // MARK: - TokenDistributing

    public func assignTokenToStores(_ token: VOToken.Value) {
        organizationStore.token = token
    }

    // MARK: - ListItemScrollable

    public func onListItemAppear(_ id: String) {
        if organizationStore.isEntityThreshold(id) {
            organizationStore.fetchNextPage()
        }
    }
}
