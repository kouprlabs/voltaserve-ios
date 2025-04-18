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

public struct VOSnapshot {
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

    public func fetchLanguages() async throws -> [Language] {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForLanguages())
            request.httpMethod = "GET"
            request.appendAuthorizationHeader(accessKey)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                handleJSONResponse(
                    continuation: continuation,
                    response: response,
                    data: data,
                    error: error,
                    type: [Language].self
                )
            }
            task.resume()
        }
    }

    public func activate(_ id: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForActivate(id))
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

    public func detach(_ id: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForDetach(id))
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

    // MARK: - URLs

    public func url() -> URL {
        URL(string: "\(baseURL)/snapshots")!
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

    public func urlForActivate(_ id: String) -> URL {
        URL(string: "\(urlForID(id))/activate")!
    }

    public func urlForDetach(_ id: String) -> URL {
        URL(string: "\(urlForID(id))/detach")!
    }

    public func urlForLanguages() -> URL {
        URL(string: "\(url())/languages")!
    }

    // MARK: - Payloads

    public struct ListOptions {
        public let fileID: String
        public let organizationID: String?
        public let page: Int?
        public let size: Int?
        public let sortBy: SortBy?
        public let sortOrder: SortOrder?

        public init(
            fileID: String,
            organizationID: String? = nil,
            page: Int? = nil,
            size: Int? = nil,
            sortBy: SortBy? = nil,
            sortOrder: SortOrder? = nil
        ) {
            self.fileID = fileID
            self.organizationID = organizationID
            self.size = size
            self.page = page
            self.sortBy = sortBy
            self.sortOrder = sortOrder
        }

        public var urlQuery: String? {
            var items: [URLQueryItem] = [.init(name: "file_id", value: fileID)]
            if let organizationID {
                items.append(.init(name: "organization_id", value: organizationID))
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

        enum CodingKeys: String, CodingKey {
            case fileID = "fileId"
            case query
            case organizationID = "organizationId"
            case size
            case page
            case sortBy
            case sortOrder
        }
    }

    public struct ActivateOptions: Codable {
        public let fileID: String

        public init(fileID: String) {
            self.fileID = fileID
        }

        enum CodingKeys: String, CodingKey {
            case fileID = "fileId"
        }
    }

    public struct DetachOptions: Codable {
        public let fileID: String

        public init(fileID: String) {
            self.fileID = fileID
        }

        enum CodingKeys: String, CodingKey {
            case fileID = "fileId"
        }
    }

    public enum SortBy: String, Codable, CustomStringConvertible {
        case version
        case dateCreated
        case dateModified

        public var description: String {
            switch self {
            case .version:
                "version"
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
        public let version: Int
        public let original: Downloadable
        public let preview: Downloadable?
        public let ocr: Downloadable?
        public let text: Downloadable?
        public let thumbnail: Downloadable?
        public let language: String?
        public let summary: String?
        public let intent: Intent?
        public let capabilities: Capabilities
        public let isActive: Bool
        public let task: VOTask.Entity?
        public let createTime: String
        public let updateTime: String?

        var displayID: String {
            "\(id)-\(self.objectCode)"
        }

        var objectCode: Int {
            var builder = Hasher()
            builder.combine(id)
            builder.combine(version)
            builder.combine(language)
            builder.combine(summary)
            builder.combine(intent)
            builder.combine(capabilities.original)
            builder.combine(capabilities.preview)
            builder.combine(capabilities.ocr)
            builder.combine(capabilities.text)
            builder.combine(capabilities.summary)
            builder.combine(capabilities.entities)
            builder.combine(capabilities.mosaic)
            builder.combine(capabilities.thumbnail)
            builder.combine(isActive)
            builder.combine(task?.status)
            builder.combine(updateTime)
            return builder.finalize()
        }

        public init(
            id: String,
            version: Int,
            original: Downloadable,
            preview: Downloadable? = nil,
            ocr: Downloadable? = nil,
            text: Downloadable? = nil,
            thumbnail: Downloadable? = nil,
            language: String? = nil,
            summary: String? = nil,
            intent: Intent? = nil,
            capabilities: Capabilities,
            isActive: Bool,
            task: VOTask.Entity? = nil,
            createTime: String,
            updateTime: String? = nil
        ) {
            self.id = id
            self.version = version
            self.original = original
            self.preview = preview
            self.ocr = ocr
            self.text = text
            self.thumbnail = thumbnail
            self.language = language
            self.summary = summary
            self.intent = intent
            self.capabilities = capabilities
            self.isActive = isActive
            self.task = task
            self.createTime = createTime
            self.updateTime = updateTime
        }
    }

    public enum Intent: String, Codable {
        case document
        case image
        case video
        case audio
        case _3d = "3d"
    }

    public struct List: Codable, Equatable {
        public let data: [Entity]
        public let totalPages: Int
        public let totalElements: Int
        public let page: Int
        public let size: Int

        public init(data: [Entity], totalPages: Int, totalElements: Int, page: Int, size: Int) {
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

    public struct Capabilities: Codable, Equatable, Hashable {
        public let original: Bool
        public let preview: Bool
        public let ocr: Bool
        public let text: Bool
        public let summary: Bool
        public let entities: Bool
        public let mosaic: Bool
        public let thumbnail: Bool

        public init(
            original: Bool,
            preview: Bool,
            ocr: Bool,
            text: Bool,
            summary: Bool,
            entities: Bool,
            mosaic: Bool,
            thumbnail: Bool
        ) {
            self.original = original
            self.preview = preview
            self.ocr = ocr
            self.text = text
            self.summary = summary
            self.entities = entities
            self.mosaic = mosaic
            self.thumbnail = thumbnail
        }
    }

    public struct Downloadable: Codable, Equatable, Hashable {
        public let fileExtension: String?
        public let size: Int
        public let image: ImageProps?
        public let document: DocumentProps?

        public init(
            fileExtension: String? = nil,
            size: Int,
            image: ImageProps? = nil,
            document: DocumentProps? = nil
        ) {
            self.fileExtension = fileExtension
            self.size = size
            self.image = image
            self.document = document
        }

        enum CodingKeys: String, CodingKey {
            case fileExtension = "extension"
            case size
            case image
            case document
        }
    }

    public struct ImageProps: Codable, Equatable, Hashable {
        public let width: Int
        public let height: Int

        public init(width: Int, height: Int) {
            self.width = width
            self.height = height
        }
    }

    public struct DocumentProps: Codable, Equatable, Hashable {
        public let page: PageProps?
        public let thumbnail: ThumbnailProps?

        public init(page: PageProps? = nil, thumbnail: ThumbnailProps? = nil) {
            self.page = page
            self.thumbnail = thumbnail
        }
    }

    public struct PageProps: Codable, Equatable, Hashable {
        public let count: Int
        public let fileExtension: String

        public init(count: Int, fileExtension: String) {
            self.count = count
            self.fileExtension = fileExtension
        }

        enum CodingKeys: String, CodingKey {
            case count
            case fileExtension = "extension"
        }
    }

    public struct ThumbnailProps: Codable, Equatable, Hashable {
        public let fileExtension: String

        public init(fileExtension: String) {
            self.fileExtension = fileExtension
        }

        enum CodingKeys: String, CodingKey {
            case fileExtension = "extension"
        }
    }

    public struct Language: Codable, Equatable, Hashable {
        public let id: String
        public let iso6393: String
        public let name: String

        public init(id: String, iso6393: String, name: String) {
            self.id = id
            self.iso6393 = iso6393
            self.name = name
        }
    }
}
