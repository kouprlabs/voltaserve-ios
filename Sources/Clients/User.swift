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

public struct VOUser {
    let baseURL: String
    let accessKey: String

    public init(baseURL: String, accessKey: String) {
        self.baseURL = URL(string: baseURL)!.appendingPathComponent("v3").absoluteString
        self.accessKey = accessKey
    }

    // MARK: - Requests

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

    // MARK: - URLs

    public func url() -> URL {
        URL(string: "\(baseURL)/users")!
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

    public func urlForPicture(
        _ id: String,
        fileExtension: String,
        organizationID: String? = nil,
        groupID: String? = nil,
        invitationID: String? = nil
    ) -> URL {
        var items: [URLQueryItem] = []
        items.append(.init(name: "access_key", value: accessKey))
        if let organizationID {
            items.append(.init(name: "organization_id", value: organizationID))
        }
        if let groupID {
            items.append(.init(name: "group_id", value: groupID))
        }
        if let invitationID {
            items.append(.init(name: "invitation_id", value: invitationID))
        }
        var components = URLComponents()
        components.queryItems = items
        let query = components.url!.query!
        return URL(string: "\(urlForID(id))/picture\(fileExtension)?\(query)")!
    }

    // MARK: - Payloads

    public struct ListOptions {
        public let query: String?
        public let organizationID: String?
        public let groupID: String?
        public let excludeGroupMembers: Bool?
        public let excludeMe: Bool?
        public let size: Int?
        public let page: Int?
        public let sortBy: SortBy?
        public let sortOrder: SortOrder?

        public init(
            query: String? = nil,
            organizationID: String? = nil,
            groupID: String? = nil,
            excludeGroupMembers: Bool? = nil,
            excludeMe: Bool? = nil,
            page: Int? = nil,
            size: Int? = nil,
            sortBy: SortBy? = nil,
            sortOrder: SortOrder? = nil
        ) {
            self.query = query
            self.organizationID = organizationID
            self.groupID = groupID
            self.excludeGroupMembers = excludeGroupMembers
            self.excludeMe = excludeMe
            self.page = page
            self.size = size
            self.sortBy = sortBy
            self.sortOrder = sortOrder
        }

        public var urlQuery: String? {
            var items: [URLQueryItem] = []
            if let query {
                items.append(.init(name: "query", value: query))
            }
            if let organizationID {
                items.append(.init(name: "organization_id", value: organizationID))
            }
            if let groupID {
                items.append(.init(name: "group_id", value: groupID))
            }
            if let excludeGroupMembers {
                items.append(.init(name: "exclude_group_members", value: String(excludeGroupMembers)))
            }
            if let excludeMe {
                items.append(.init(name: "exclude_me", value: String(excludeMe)))
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
        case email
        case fullName

        public var description: String {
            switch self {
            case .email:
                "email"
            case .fullName:
                "full_name"
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
        public let username: String
        public let email: String
        public let fullName: String
        public let picture: Picture?
        public let createTime: String
        public let updateTime: String?

        var displayID: String {
            "\(id)-\(self.objectCode)"
        }

        var objectCode: Int {
            var builder = Hasher()
            builder.combine(id)
            builder.combine(username)
            builder.combine(email)
            builder.combine(fullName)
            builder.combine(updateTime)
            return builder.finalize()
        }

        public init(
            id: String,
            username: String,
            email: String,
            fullName: String,
            picture: Picture? = nil,
            createTime: String,
            updateTime: String? = nil
        ) {
            self.id = id
            self.username = username
            self.email = email
            self.fullName = fullName
            self.picture = picture
            self.createTime = createTime
            self.updateTime = updateTime
        }
    }

    public struct Picture: Codable, Equatable, Hashable {
        public let fileExtension: String

        public init(fileExtension: String) {
            self.fileExtension = fileExtension
        }

        enum CodingKeys: String, CodingKey {
            case fileExtension = "extension"
        }
    }

    public struct List: Codable {
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

    public struct Probe: Codable {
        public let totalPages: Int
        public let totalElements: Int

        public init(totalPages: Int, totalElements: Int) {
            self.totalPages = totalPages
            self.totalElements = totalElements
        }
    }
}
