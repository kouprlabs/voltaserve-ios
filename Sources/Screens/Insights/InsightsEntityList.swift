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

public struct InsightsEntityList: View, ViewDataProvider, LoadStateProvider, TimerLifecycle, SessionDistributing,
    ListItemScrollable
{
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var insightsStore = InsightsStore()
    @Environment(\.dismiss) private var dismiss
    @State private var showError = false
    @State private var searchText = ""
    private let file: VOFile.Entity

    public init(_ file: VOFile.Entity) {
        self.file = file
    }

    public var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView()
                } else if let error {
                    VOErrorMessage(error)
                } else {
                    if let entities = insightsStore.entities {
                        Group {
                            if entities.count == 0 {
                                Text("There are no items.")
                            } else {
                                List(entities, id: \.text) { entity in
                                    InsightsEntityRow(entity)
                                        .onAppear {
                                            onListItemAppear(entity.text)
                                        }
                                }
                            }
                        }
                        .refreshable {
                            insightsStore.fetchEntityNextPage(replace: true)
                        }
                        .searchable(text: $searchText)
                        .onChange(of: searchText) {
                            insightsStore.searchPublisher.send($1)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Insights")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            insightsStore.file = file
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
        .onChange(of: insightsStore.query) {
            insightsStore.clear()
            insightsStore.fetchEntityNextPage()
        }
    }

    // MARK: - LoadStateProvider

    public var isLoading: Bool {
        insightsStore.entitiesIsLoadingFirstTime
    }

    public var error: String? {
        insightsStore.entitiesError
    }

    // MARK: - ViewDataProvider

    public func onAppearOrChange() {
        fetchData()
    }

    public func fetchData() {
        insightsStore.fetchEntityNextPage(replace: true)
    }

    // MARK: - TimerLifecycle

    public func startTimers() {
        insightsStore.startTimer()
    }

    public func stopTimers() {
        insightsStore.stopTimer()
    }

    // MARK: - SessionDistributing

    public func assignSessionToStores(_ session: VOSession.Value) {
        insightsStore.session = session
    }

    // MARK: - ListItemScrollable

    public func onListItemAppear(_ id: String) {
        if insightsStore.isEntityThreshold(id) {
            insightsStore.fetchEntityNextPage()
        }
    }
}
