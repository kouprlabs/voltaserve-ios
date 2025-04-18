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
public class UserStore: ObservableObject {
    @Published public var entities: [VOUser.Entity]?
    @Published public var entitiesIsLoading = false
    public var entitiesIsLoadingFirstTime: Bool { entitiesIsLoading && entities == nil }
    @Published public var entitiesError: String?
    @Published public var query: String?
    private var list: VOUser.List?
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var userClient: VOUser?
    public let searchPublisher = PassthroughSubject<String, Never>()
    public var organizationID: String?
    public var groupID: String?
    public var excludeGroupMembers: Bool?
    public var excludeMe: Bool?
    public var invitationID: String?

    public var session: VOSession.Value? {
        didSet {
            if let session {
                userClient = .init(
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

    // MARK: - URLs

    public func urlForPicture(_ id: String, fileExtension: String? = nil) -> URL? {
        if let fileExtension {
            return userClient?.urlForPicture(
                id,
                fileExtension: fileExtension,
                organizationID: organizationID,
                groupID: groupID,
                invitationID: invitationID
            )
        }
        return nil
    }

    // MARK: - Fetch

    private func fetchProbe(size: Int = Constants.pageSize) async throws -> VOUser.Probe? {
        if let organizationID {
            return try await userClient?.fetchProbe(
                .init(
                    query: query,
                    organizationID: organizationID,
                    size: size
                ))
        } else if let groupID {
            return try await userClient?.fetchProbe(
                .init(
                    query: query,
                    groupID: groupID,
                    size: size
                ))
        }
        return nil
    }

    private func fetchList(page: Int = 1, size: Int = Constants.pageSize) async throws -> VOUser.List? {
        try await userClient?.fetchList(
            .init(
                query: query,
                organizationID: organizationID,
                groupID: groupID,
                excludeGroupMembers: excludeGroupMembers,
                excludeMe: excludeMe,
                page: page,
                size: size
            ))
    }

    public func fetchNextPage(replace: Bool = false) {
        guard !entitiesIsLoading else { return }

        var nextPage = -1
        var list: VOUser.List?

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

    // MARK: - Entities

    public func append(_ newEntities: [VOUser.Entity]) {
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
