// Copyright (c) 2024 Anass Bouassaba.
//
// Use of this software is governed by the Business Source License
// included in the file LICENSE in the root of this repository.
//
// As of the Change Date specified in that file, in accordance with
// the Business Source License, use of this software will be governed
// by the GNU Affero General Public License v3.0 only, included in the file
// AGPL-3.0-only in the root of this repository.

import Charts
import SwiftUI

public struct InsightsChart: View, ViewDataProvider, LoadStateProvider, TimerLifecycle, SessionDistributing {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var insightsStore = InsightsStore(pageSize: Constants.pageSize)
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
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
                    VStack(spacing: VOMetrics.spacing2Xl) {
                        if let summary = file.snapshot?.summary {
                            Text(summary)
                                .padding(.horizontal)
                        }
                        Spacer()
                        if let entities = insightsStore.entities {
                            if entities.count < 5 {
                                Text("Not enough data to render the chart.")
                            } else {
                                Chart(entities) { entity in
                                    SectorMark(
                                        angle: .value(
                                            Text(verbatim: entity.text),
                                            entity.frequency
                                        ),
                                        innerRadius: .ratio(0.67),
                                        angularInset: 4
                                    )
                                    .cornerRadius(5)
                                    .foregroundStyle(sectorMarkColor)
                                    .annotation(position: .overlay) {
                                        Text("\(entity.text) (\(entity.frequency))")
                                            .font(.footnote)
                                            .padding(.horizontal)
                                            .frame(height: 20)
                                            .background(Color(UIColor.systemBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .strokeBorder(sectorMarkColor, lineWidth: 1)
                                            }
                                    }
                                }
                                .chartLegend(.hidden)
                                .frame(maxWidth: 300, maxHeight: 300)
                            }
                        }
                        Spacer()
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
            insightsStore.clear()
            stopTimers()
        }
    }

    private var sectorMarkColor: Color {
        colorScheme == .dark ? .gray500 : .gray200
    }

    private enum Constants {
        static let pageSize: Int = 5
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
        if let snapshot = file.snapshot, snapshot.capabilities.entities {
            insightsStore.fetchEntityNextPage(replace: true)
        }
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
}
