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
// swiftlint:disable:next type_body_length
public class WorkspaceStore: ObservableObject {
    @Published public var entities: [VOWorkspace.Entity]?
    @Published public var entitiesIsLoading = false
    public var entitiesIsLoadingFirstTime: Bool { entitiesIsLoading && entities == nil }
    @Published public var entitiesError: String?
    @Published public var root: VOFile.Entity?
    @Published public var rootIsLoading = false
    @Published public var rootError: String?
    @Published public var storageUsage: VOStorage.Usage?
    @Published public var storageUsageIsLoading = false
    @Published public var storageUsageError: String?
    @Published public var current: VOWorkspace.Entity?
    @Published public var query: String?
    private var list: VOWorkspace.List?
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var workspaceClient: VOWorkspace?
    private var fileClient: VOFile?
    private var storageClient: VOStorage?
    let searchPublisher = PassthroughSubject<String, Never>()

    public var session: VOSession.Value? {
        didSet {
            if let session {
                workspaceClient = .init(
                    baseURL: Config.shared.apiURL,
                    accessKey: session.accessKey
                )
                fileClient = .init(
                    baseURL: Config.shared.apiURL,
                    accessKey: session.accessKey
                )
                storageClient = .init(
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

    private func fetch() async throws -> VOWorkspace.Entity? {
        guard let current else { return nil }
        return try await workspaceClient?.fetch(current.id)
    }

    private func fetchProbe(size: Int = Constants.pageSize) async throws -> VOWorkspace.Probe? {
        try await workspaceClient?.fetchProbe(.init(query: query, size: size))
    }

    private func fetchList(page: Int = 1, size: Int = Constants.pageSize) async throws -> VOWorkspace.List? {
        try await workspaceClient?.fetchList(
            .init(
                query: query,
                page: page,
                size: size,
                sortBy: .dateCreated,
                sortOrder: .desc
            ))
    }

    public func fetchNextPage(replace: Bool = false) {
        guard !entitiesIsLoading else { return }

        var nextPage = -1
        var list: VOWorkspace.List?

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

    private func fetchRoot() async throws -> VOFile.Entity? {
        guard let current else { return nil }
        return try await fileClient?.fetch(current.rootID)
    }

    public func fetchRoot() {
        var root: VOFile.Entity?
        withErrorHandling {
            root = try await self.fetchRoot()
            self.rootError = nil
            return true
        } before: {
            self.rootIsLoading = true
        } success: {
            self.root = root
        } failure: { message in
            self.rootError = message
        } anyways: {
            self.rootIsLoading = false
        }
    }

    private func fetchStorageUsage() async throws -> VOStorage.Usage? {
        guard let current else { return nil }
        return try await storageClient?.fetchWorkspaceUsage(current.id)
    }

    public func fetchStorageUsage() {
        var storageUsage: VOStorage.Usage?
        withErrorHandling {
            storageUsage = try await self.fetchStorageUsage()
            self.storageUsageError = nil
            return true
        } before: {
            self.storageUsageIsLoading = true
        } success: {
            self.storageUsage = storageUsage
        } failure: { message in
            self.storageUsageError = message
        } anyways: {
            self.storageUsageIsLoading = false
        }
    }

    // MARK: - Update

    public func create(
        name: String,
        organization: VOOrganization.Entity,
        storageCapacity: Int
    ) async throws -> VOWorkspace.Entity? {
        try await workspaceClient?.create(
            .init(
                name: name,
                organizationID: organization.id,
                storageCapacity: storageCapacity
            ))
    }

    public func patchName(_ id: String, name: String) async throws -> VOWorkspace.Entity? {
        try await workspaceClient?.patchName(id, options: .init(name: name))
    }

    public func patchStorageCapacity(storageCapacity: Int) async throws -> VOWorkspace.Entity? {
        guard let current else { return nil }
        return try await workspaceClient?.patchStorageCapacity(
            current.id,
            options: .init(storageCapacity: storageCapacity)
        )
    }

    public func delete() async throws {
        guard let current else { return }
        try await workspaceClient?.delete(current.id)
    }

    // MARK: - Entities

    public func append(_ newEntities: [VOWorkspace.Entity]) {
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
                if let entities = await self.entities {
                    let list = try await self.fetchList(
                        page: 1,
                        size: entities.count > Constants.pageSize ? entities.count : Constants.pageSize
                    )
                    if let list {
                        await MainActor.run {
                            self.entities = list.data
                            self.entitiesError = nil
                        }
                    }
                }
                if await self.current != nil {
                    if await self.root != nil {
                        let root = try await self.fetchRoot()
                        if let root {
                            await MainActor.run {
                                self.root = root
                                self.rootError = nil
                            }
                        }
                    }
                    if await self.storageUsage != nil {
                        let storageUsage = try await self.fetchStorageUsage()
                        if let storageUsage {
                            await MainActor.run {
                                self.storageUsage = storageUsage
                                self.storageUsageError = nil
                            }
                        }
                    }
                }
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
