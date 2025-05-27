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

@MainActor
public class OrganizationStore: ObservableObject {
    @Published public var entities: [VOOrganization.Entity]?
    @Published public var entitiesIsLoading = false
    public var entitiesIsLoadingFirstTime: Bool { entitiesIsLoading && entities == nil }
    @Published public var entitiesError: String?
    @Published public var current: VOOrganization.Entity?
    @Published public var currentIsLoading = false
    @Published public var currentError: String?
    @Published public var query: String?
    private var list: VOOrganization.List?
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var organizationClient: VOOrganization?
    public let searchPublisher = PassthroughSubject<String, Never>()

    public var session: VOSession.Value? {
        didSet {
            if let session {
                organizationClient = .init(
                    baseURL: Config.shared.apiURL,
                    accessKey: session.accessKey
                )
            }
        }
    }

    public init() {
        searchPublisher
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink {
                self.query = $0
            }
            .store(in: &cancellables)
    }

    // MARK: - Fetch

    public func fetchCurrent(_ id: String) {
        var organization: VOOrganization.Entity?
        withErrorHandling {
            organization = try await self.organizationClient?.fetch(id)
            return true
        } before: {
            self.currentIsLoading = true
        } success: {
            self.current = organization
            self.currentError = nil
        } failure: { message in
            self.currentError = message
        } anyways: {
            self.currentIsLoading = false
        }
    }

    public func fetchNextPage(replace: Bool = false) {
        guard !entitiesIsLoading else { return }
        var nextPage = -1
        var list: VOOrganization.List?

        withErrorHandling {
            if let list = self.list {
                let probe = try await self.organizationClient?.fetchProbe(
                    .init(
                        query: self.query,
                        size: Constants.pageSize
                    )
                )
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
            list = try await self.organizationClient?.fetchList(
                .init(
                    query: self.query,
                    page: nextPage,
                    size: Constants.pageSize,
                    sortBy: .dateCreated,
                    sortOrder: .desc
                )
            )
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

    public func create(_ options: VOOrganization.CreateOptions) async throws -> VOOrganization.Entity? {
        try await organizationClient?.create(options)
    }

    public func patchName(
        _ id: String,
        options: VOOrganization.PatchNameOptions
    ) async throws -> VOOrganization.Entity? {
        try await organizationClient?.patchName(id, options: options)
    }

    public func leave(_ id: String) async throws {
        try await organizationClient?.leave(id)
    }

    public func delete(_ id: String) async throws {
        try await organizationClient?.delete(id)
    }

    public func removeMember(
        _ id: String,
        options: VOOrganization.RemoveMemberOptions
    ) async throws {
        try await organizationClient?.removeMember(id, options: options)
    }

    // MARK: - Sync

    public func syncEntities() async throws {
        if let entities = await self.entities {
            let list = try await self.organizationClient?.fetchList(
                .init(
                    query: self.query,
                    page: 1,
                    size: entities.count > Constants.pageSize ? entities.count : Constants.pageSize,
                    sortBy: .dateCreated,
                    sortOrder: .desc
                )
            )
            if let list {
                await MainActor.run {
                    self.entities = list.data
                    self.entitiesError = nil
                }
            }
        }
    }

    public func syncCurrent() async throws {
        if let current = self.current {
            let organization = try await self.organizationClient?.fetch(current.id)
            if let organization {
                try await syncCurrent(organization: organization)
            }
        }
    }

    public func syncCurrent(organization: VOOrganization.Entity) async throws {
        if let current = self.current {
            await MainActor.run {
                let index = entities?.firstIndex(where: { $0.id == organization.id })
                if let index {
                    self.current = organization
                    entities?[index] = organization
                }
            }
        }
    }

    // MARK: - Entities

    public func append(_ newEntities: [VOOrganization.Entity]) {
        if entities == nil {
            entities = []
        }
        for newEntity in newEntities where !entities!.contains(where: { $0.id == newEntity.id }) {
            entities!.append(newEntity)
        }
    }

    public func clear() {
        entities = nil
        list = nil
    }

    // MARK: - Pagination

    public func nextPage() -> Int {
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

    public func hasNextPage() -> Bool {
        nextPage() != -1
    }

    public func isEntityThreshold(_ id: String) -> Bool {
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

    public func isLastPage() -> Bool {
        if let list {
            return list.page == list.totalPages
        }
        return false
    }

    // MARK: - Timer

    public func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task.detached {
                try await self.syncEntities()
                try await self.syncCurrent()
            }
        }
    }

    public func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Constants

    private enum Constants {
        static let pageSize = 50
    }
}
