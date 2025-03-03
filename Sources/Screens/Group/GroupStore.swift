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
import Foundation
import VoltaserveCore

@MainActor
class GroupStore: ObservableObject {
    @Published var entities: [VOGroup.Entity]?
    @Published var entitiesIsLoading: Bool = false
    var entitiesIsLoadingFirstTime: Bool { entitiesIsLoading && entities == nil }
    @Published var entitiesError: String?
    @Published var current: VOGroup.Entity?
    @Published var query: String?
    private var list: VOGroup.List?
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var groupClient: VOGroup?
    let searchPublisher = PassthroughSubject<String, Never>()
    var organizationID: String?

    var token: VOToken.Value? {
        didSet {
            if let token {
                groupClient = .init(
                    baseURL: Config.production.apiURL,
                    accessToken: token.accessToken
                )
            }
        }
    }

    init(organizationID: String? = nil) {
        self.organizationID = organizationID
        searchPublisher
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink {
                self.query = $0
            }
            .store(in: &cancellables)
    }

    // MARK: - Fetch

    private func fetchProbe(size: Int = Constants.pageSize) async throws -> VOGroup.Probe? {
        if let organizationID {
            try await groupClient?.fetchProbe(
                .init(
                    query: query,
                    organizationID: organizationID,
                    size: size
                ))
        } else {
            try await groupClient?.fetchProbe(
                .init(
                    query: query,
                    size: size
                ))
        }
    }

    private func fetchList(page: Int = 1, size: Int = Constants.pageSize) async throws -> VOGroup.List? {
        if let organizationID {
            try await groupClient?.fetchList(
                .init(
                    query: query,
                    organizationID: organizationID,
                    page: page,
                    size: size,
                    sortBy: .dateCreated,
                    sortOrder: .desc
                ))
        } else {
            try await groupClient?.fetchList(
                .init(
                    query: query,
                    page: page,
                    size: size,
                    sortBy: .dateCreated,
                    sortOrder: .desc
                ))
        }
    }

    func fetchNextPage(replace: Bool = false) {
        guard !entitiesIsLoading else { return }

        var nextPage = -1
        var list: VOGroup.List?

        withErrorHandling {
            if let list = self.list {
                let probe = try await self.fetchProbe(size: Constants.pageSize)
                if let probe {
                    self.list = .init(
                        data: list.data,
                        totalPages: probe.totalPages,
                        totalElements: probe.totalElements,
                        page: list.page,
                        size: list.size
                    )
                }
            }
            if !self.hasNextPage() { return false }
            nextPage = self.nextPage()
            list = try await self.fetchList(page: nextPage)
            return true
        } before: {
            self.entitiesIsLoading = true
        } success: {
            self.list = list
            if let list {
                if replace, nextPage == 1 {
                    self.entities = list.data
                } else {
                    self.append(list.data)
                }
            }
            self.entitiesError = nil
        } failure: { message in
            self.entitiesError = message
        } anyways: {
            self.entitiesIsLoading = false
        }
    }

    // MARK: - Update

    func create(name: String, organization: VOOrganization.Entity) async throws -> VOGroup.Entity? {
        try await groupClient?.create(.init(name: name, organizationID: organization.id))
    }

    func patchName(_ id: String, name: String) async throws -> VOGroup.Entity? {
        try await groupClient?.patchName(id, options: .init(name: name))
    }

    func delete() async throws {
        guard let current else { return }
        try await groupClient?.delete(current.id)
    }

    func addMember(userID: String) async throws {
        guard let current else { return }
        try await groupClient?.addMember(current.id, options: .init(userID: userID))
    }

    // MARK: - Entities

    func append(_ newEntities: [VOGroup.Entity]) {
        if entities == nil {
            entities = []
        }
        for newEntity in newEntities where !entities!.contains(where: { $0.id == newEntity.id }) {
            entities!.append(newEntity)
        }
    }

    func clear() {
        entities = nil
        list = nil
    }

    // MARK: - Pagination

    func nextPage() -> Int {
        var page = 1
        if let list {
            if list.page < list.totalPages {
                page = list.page + 1
            } else if list.page == list.totalPages {
                return -1
            }
        }
        return page
    }

    func hasNextPage() -> Bool {
        nextPage() != -1
    }

    func isEntityThreshold(_ id: String) -> Bool {
        if let entities {
            let threashold = Constants.pageSize / 2
            if entities.count >= threashold,
                entities.firstIndex(where: { $0.id == id }) == entities.count - threashold
            {
                return true
            } else {
                return id == entities.last?.id
            }
        }
        return false
    }

    // MARK: - Timer

    func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            if self.entities != nil {
                Task {
                    var size = Constants.pageSize
                    if let list = self.list {
                        size = Constants.pageSize * list.page
                    }
                    let list = try await self.fetchList(page: 1, size: size)
                    if let list {
                        DispatchQueue.main.async {
                            self.entities = list.data
                            self.entitiesError = nil
                        }
                    }
                }
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Constants

    private enum Constants {
        static let pageSize = 50
    }
}
