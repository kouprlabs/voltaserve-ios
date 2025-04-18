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
public class BrowserStore: ObservableObject {
    @Published public var entities: [VOFile.Entity]?
    @Published public var entitiesIsLoading = false
    public var entitiesIsLoadingFirstTime: Bool { entitiesIsLoading && entities == nil }
    @Published public var entitiesError: String?
    @Published public var folder: VOFile.Entity?
    @Published public var folderIsLoading = false
    @Published public var folderError: String?
    @Published public var query: VOFile.Query = .init(type: .folder)
    private var list: VOFile.List?
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var fileClient: VOFile?
    public var folderID: String?
    public let searchPublisher = PassthroughSubject<String, Never>()

    public var session: VOSession.Value? {
        didSet {
            if let session {
                fileClient = .init(
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
                if $0.isEmpty {
                    self.query = .init(type: .folder)
                } else {
                    self.query = .init(text: $0, type: .folder)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Fetch

    private func fetchFolder() async throws -> VOFile.Entity? {
        guard let folderID else { return nil }
        return try await fileClient?.fetch(folderID)
    }

    public func fetchFolder() {
        var folder: VOFile.Entity?
        withErrorHandling {
            folder = try await self.fetchFolder()
            return true
        } before: {
            self.folderIsLoading = true
        } success: {
            self.folder = folder
            self.folderError = nil
        } failure: { message in
            self.folderError = message
        } anyways: {
            self.folderIsLoading = false
        }
    }

    private func fetchProbe(_ id: String, size: Int = Constants.pageSize) async throws -> VOFile.Probe? {
        try await fileClient?.fetchProbe(id, options: .init(query: query, size: size))
    }

    private func fetchList(_ id: String, page: Int = 1, size: Int = Constants.pageSize) async throws -> VOFile.List? {
        try await fileClient?.fetchList(
            id,
            options: .init(
                query: query,
                page: page,
                size: size,
                sortBy: .dateCreated,
                sortOrder: .desc
            ))
    }

    public func fetchNextPage(replace: Bool = false) {
        guard let folderID else { return }
        guard !entitiesIsLoading else { return }

        var nextPage = -1
        var list: VOFile.List?

        withErrorHandling {
            if let list = self.list {
                let probe = try await self.fetchProbe(folderID, size: Constants.pageSize)
                if let probe {
                    self.list = .init(
                        data: list.data,
                        totalPages: probe.totalPages,
                        totalElements: probe.totalElements,
                        page: list.page,
                        size: list.size,
                        query: list.query
                    )
                }
            }
            if !self.hasNextPage() { return false }
            nextPage = self.nextPage()
            list = try await self.fetchList(folderID, page: nextPage)
            self.entitiesError = nil
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
        } failure: { message in
            self.entitiesError = message
        } anyways: {
            self.entitiesIsLoading = false
        }
    }

    // MARK: - Entities

    public func append(_ newEntities: [VOFile.Entity]) {
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

    // MARK: - Timer

    public func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task.detached {
                if let current = await self.folder, let entities = await self.entities {
                    let list = try await self.fetchList(
                        current.id,
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
                if await self.folder != nil {
                    let folder = try await self.fetchFolder()
                    if let folder {
                        await MainActor.run {
                            self.folder = folder
                            self.folderError = nil
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
