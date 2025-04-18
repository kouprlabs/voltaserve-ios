// Copyright (c) 2024 Anass Bouassaba.
//
// Use of this software is governed by the Business Source License
// included in the file LICENSE in the root of this repository.
//
// As of the Change Date specified in that file, in accordance with
// the Business Source License, use of this software will be governed
// by the GNU Affero General Public License v3.0 only, included in the file
// AGPL-3.0-only in the root of this repository.

import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public struct VOTask {
    let baseURL: String
    let accessKey: String

    public init(baseURL: String, accessKey: String) {
        self.baseURL = URL(string: baseURL)!.appendingPathComponent("v3").absoluteString
        self.accessKey = accessKey
    }

    // MARK: - Requests

    public func fetch(_ id: String) async throws -> Entity {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForID(id))
            request.httpMethod = "GET"
            request.appendAuthorizationHeader(accessKey)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                handleJSONResponse(
                    continuation: continuation,
                    response: response,
                    data: data,
                    error: error,
                    type: Entity.self
                )
            }
            task.resume()
        }
    }

    public func fetchList(_ options: ListOptions) async throws -> List {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForList(options))
            request.httpMethod = "GET"
            request.appendAuthorizationHeader(accessKey)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                handleJSONResponse(
                    continuation: continuation,
                    response: response,
                    data: data,
                    error: error,
                    type: List.self
                )
            }
            task.resume()
        }
    }

    public func fetchProbe(_ options: ListOptions) async throws -> Probe {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForProbe(options))
            request.httpMethod = "GET"
            request.appendAuthorizationHeader(accessKey)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                handleJSONResponse(
                    continuation: continuation,
                    response: response,
                    data: data,
                    error: error,
                    type: Probe.self
                )
            }
            task.resume()
        }
    }

    public func fetchCount() async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForCount())
            request.httpMethod = "GET"
            request.appendAuthorizationHeader(accessKey)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                handleJSONResponse(
                    continuation: continuation,
                    response: response,
                    data: data,
                    error: error,
                    type: Int.self
                )
            }
            task.resume()
        }
    }

    public func dismiss(_ id: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForDimiss(id))
            request.httpMethod = "POST"
            request.appendAuthorizationHeader(accessKey)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                handleEmptyResponse(
                    continuation: continuation,
                    response: response,
                    data: data,
                    error: error
                )
            }
            task.resume()
        }
    }

    public func dismiss() async throws -> DismissAllResult {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForDismiss())
            request.httpMethod = "POST"
            request.appendAuthorizationHeader(accessKey)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                handleJSONResponse(
                    continuation: continuation,
                    response: response,
                    data: data,
                    error: error,
                    type: DismissAllResult.self
                )
            }
            task.resume()
        }
    }

    // MARK: - URLs

    public func url() -> URL {
        URL(string: "\(baseURL)/tasks")!
    }

    public func urlForID(_ id: String) -> URL {
        URL(string: "\(url())/\(id)")!
    }

    public func urlForList(_ options: ListOptions) -> URL {
        if let query = options.urlQuery {
            URL(string: "\(url())?\(query)")!
        } else {
            url()
        }
    }

    public func urlForProbe(_ options: ListOptions) -> URL {
        if let query = options.urlQuery {
            URL(string: "\(url())/probe?\(query)")!
        } else {
            URL(string: "\(url())/probe")!
        }
    }

    public func urlForCount() -> URL {
        URL(string: "\(url())/count")!
    }

    public func urlForDimiss(_ id: String) -> URL {
        URL(string: "\(urlForID(id))/dismiss")!
    }

    public func urlForDismiss() -> URL {
        URL(string: "\(url())/dismiss")!
    }

    // MARK: - Payloads

    public struct ListOptions {
        public let query: String?
        public let page: Int?
        public let size: Int?
        public let sortBy: SortBy?
        public let sortOrder: SortOrder?

        public init(
            query: String? = nil,
            page: Int? = nil,
            size: Int? = nil,
            sortBy: SortBy? = nil,
            sortOrder: SortOrder? = nil
        ) {
            self.query = query
            self.size = size
            self.page = page
            self.sortBy = sortBy
            self.sortOrder = sortOrder
        }

        var urlQuery: String? {
            var items: [URLQueryItem] = []
            if let query, let base64Query = try? JSONEncoder().encode(query).base64EncodedString() {
                items.append(.init(name: "query", value: base64Query))
            }
            if let size {
                items.append(.init(name: "size", value: String(size)))
            }
            if let page {
                items.append(.init(name: "page", value: String(page)))
            }
            if let sortBy {
                items.append(.init(name: "sort_by", value: sortBy.description))
            }
            if let sortOrder {
                items.append(.init(name: "sort_order", value: sortOrder.rawValue))
            }
            var components = URLComponents()
            components.queryItems = items
            return components.url?.query
        }
    }

    public enum SortBy: String, Codable, CustomStringConvertible {
        case name
        case status
        case dateCreated
        case dateModified

        public var description: String {
            switch self {
            case .name:
                "name"
            case .status:
                "status"
            case .dateCreated:
                "date_created"
            case .dateModified:
                "date_modified"
            }
        }
    }

    public enum SortOrder: String, Codable {
        case asc
        case desc
    }

    // MARK: - Types

    public struct Entity: Codable, Equatable, Hashable {
        public let id: String
        public let name: String
        public let error: String?
        public let percentage: Int?
        public let isIndeterminate: Bool
        public let userID: String
        public let status: Status
        public let isDismissible: Bool
        public let payload: Payload?
        public let createTime: String
        public let updateTime: String?

        var displayID: String {
            "\(id)-\(self.objectCode)"
        }

        var objectCode: Int {
            var builder = Hasher()
            builder.combine(id)
            builder.combine(name)
            builder.combine(error)
            builder.combine(percentage)
            builder.combine(status.rawValue)
            if let payload {
                builder.combine(payload.object)
            }
            builder.combine(updateTime)
            return builder.finalize()
        }

        public init(
            id: String,
            name: String,
            error: String? = nil,
            percentage: Int? = nil,
            isIndeterminate: Bool,
            userID: String,
            status: Status,
            isDismissible: Bool,
            payload: Payload? = nil,
            createTime: String,
            updateTime: String? = nil
        ) {
            self.id = id
            self.name = name
            self.error = error
            self.percentage = percentage
            self.isIndeterminate = isIndeterminate
            self.userID = userID
            self.status = status
            self.isDismissible = isDismissible
            self.payload = payload
            self.createTime = createTime
            self.updateTime = updateTime
        }

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case error
            case percentage
            case isIndeterminate
            case userID = "userId"
            case status
            case isDismissible
            case payload
            case createTime
            case updateTime
        }
    }

    public enum Status: String, Codable {
        case waiting
        case running
        case success
        case error
    }

    public struct Payload: Codable, Equatable, Hashable {
        public let object: String?

        public init(object: String? = nil) {
            self.object = object
        }
    }

    public struct List: Codable, Equatable, Hashable {
        public let data: [Entity]
        public let totalPages: Int
        public let totalElements: Int
        public let page: Int
        public let size: Int

        public init(
            data: [Entity],
            totalPages: Int,
            totalElements: Int,
            page: Int,
            size: Int
        ) {
            self.data = data
            self.totalPages = totalPages
            self.totalElements = totalElements
            self.page = page
            self.size = size
        }
    }

    public struct Probe: Codable, Equatable, Hashable {
        public let totalPages: Int
        public let totalElements: Int

        public init(totalPages: Int, totalElements: Int) {
            self.totalPages = totalPages
            self.totalElements = totalElements
        }
    }

    public struct DismissAllResult: Codable, Equatable, Hashable {
        public let succeeded: [String]
        public let failed: [String]
    }
}
