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

public struct VOFile {
    let baseURL: String
    let accessKey: String

    public init(baseURL: String, accessKey: String) {
        self.baseURL = URL(string: baseURL)!.appendingPathComponent("v3").absoluteString
        self.accessKey = accessKey
    }

    enum BaseURLError: Error {
        case invalid
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

    public func fetchPath(_ id: String) async throws -> [Entity] {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForPath(id))
            request.httpMethod = "GET"
            request.appendAuthorizationHeader(accessKey)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                handleJSONResponse(
                    continuation: continuation,
                    response: response,
                    data: data,
                    error: error,
                    type: [Entity].self
                )
            }
            task.resume()
        }
    }

    public func fetchCount(_ id: String) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForCount(id))
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

    public func fetchList(_ id: String, options: ListOptions) async throws -> List {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForList(id, options: options))
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

    public func fetchProbe(_ id: String, options: ListOptions) async throws -> Probe {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForProbe(id, options: options))
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

    public func fetchUserPermissions(_ id: String) async throws -> [UserPermission] {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForUserPermissions(id))
            request.httpMethod = "GET"
            request.appendAuthorizationHeader(accessKey)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                handleJSONResponse(
                    continuation: continuation,
                    response: response,
                    data: data,
                    error: error,
                    type: [UserPermission].self
                )
            }
            task.resume()
        }
    }

    public func fetchGroupPermissions(_ id: String) async throws -> [GroupPermission] {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForGroupPermissions(id))
            request.httpMethod = "GET"
            request.appendAuthorizationHeader(accessKey)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                handleJSONResponse(
                    continuation: continuation,
                    response: response,
                    data: data,
                    error: error,
                    type: [GroupPermission].self
                )
            }
            task.resume()
        }
    }

    public func create(_ options: CreateFileOptions) async throws -> Entity {
        try await upload(urlForCreate(options), method: "POST", data: options.data, filename: options.name)
    }

    public func create(_ options: CreateFolderOptions) async throws -> Entity {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForCreate(options))
            request.httpMethod = "POST"
            request.appendAuthorizationHeader(accessKey)
            request.setJSONBody(options, continuation: continuation)
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

    public func patch(_ id: String, options: PatchOptions) async throws -> Entity {
        try await upload(urlForID(id), method: "PATCH", data: options.data, filename: options.name)
    }

    func upload(
        _ url: URL,
        method: String,
        data: Data,
        filename: String,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> Entity {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.appendAuthorizationHeader(accessKey)

            let boundary = UUID().uuidString
            request.setValue(
                "multipart/form-data; boundary=\(boundary)",
                forHTTPHeaderField: "Content-Type"
            )

            var httpBody = Data()
            httpBody.append(Data("--\(boundary)\r\n".utf8))
            httpBody.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".utf8))
            httpBody.append(Data("Content-Type: application/octet-stream\r\n\r\n".utf8))

            httpBody.append(data)
            httpBody.append(Data("\r\n--\(boundary)--\r\n".utf8))

            let task = URLSession.shared.uploadTask(with: request, from: httpBody) { responseData, response, error in
                handleJSONResponse(
                    continuation: continuation,
                    response: response,
                    data: responseData,
                    error: error,
                    type: Entity.self
                )
            }
            task.resume()

            if let onProgress {
                let progressHandler = {
                    onProgress(task.progress.fractionCompleted * 100)
                }
                let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                    progressHandler()
                    if task.progress.isFinished {
                        timer.invalidate()
                    }
                }
                RunLoop.main.add(timer, forMode: .default)
            }
        }
    }

    public func patchName(_ id: String, options: PatchNameOptions) async throws -> Entity {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForName(id))
            request.httpMethod = "PATCH"
            request.appendAuthorizationHeader(accessKey)
            request.setJSONBody(options, continuation: continuation)
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

    public func delete(_ id: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForID(id))
            request.httpMethod = "DELETE"
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

    public func delete(_ options: DeleteOptions) async throws -> DeleteResult {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: url())
            request.httpMethod = "DELETE"
            request.appendAuthorizationHeader(accessKey)
            request.setJSONBody(options, continuation: continuation)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                handleJSONResponse(
                    continuation: continuation,
                    response: response,
                    data: data,
                    error: error,
                    type: DeleteResult.self
                )
            }
            task.resume()
        }
    }

    public func move(_ id: String, to targetID: String) async throws -> Entity {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForMove(id, to: targetID))
            request.httpMethod = "POST"
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

    public func move(_ options: MoveOptions) async throws -> MoveResult {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForMove())
            request.httpMethod = "POST"
            request.appendAuthorizationHeader(accessKey)
            request.setJSONBody(options, continuation: continuation)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                handleJSONResponse(
                    continuation: continuation,
                    response: response,
                    data: data,
                    error: error,
                    type: MoveResult.self
                )
            }
            task.resume()
        }
    }

    public func copy(_ id: String, to targetID: String) async throws -> Entity {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForCopy(id, to: targetID))
            request.httpMethod = "POST"
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

    public func copy(_ options: CopyOptions) async throws -> CopyResult {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForCopy())
            request.httpMethod = "POST"
            request.appendAuthorizationHeader(accessKey)
            request.setJSONBody(options, continuation: continuation)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                handleJSONResponse(
                    continuation: continuation,
                    response: response,
                    data: data,
                    error: error,
                    type: CopyResult.self
                )
            }
            task.resume()
        }
    }

    public func grantUserPermission(_ options: GrantUserPermissionOptions) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            var request = URLRequest(url: urlForGrantUserPermission())
            request.httpMethod = "POST"
            request.appendAuthorizationHeader(accessKey)
            request.setJSONBody(options, continuation: continuation)
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

    public func revokeUserPermission(_ options: RevokeUserPermissionOptions) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            var request = URLRequest(url: urlForRevokeUserPermission())
            request.httpMethod = "POST"
            request.appendAuthorizationHeader(accessKey)
            request.setJSONBody(options, continuation: continuation)
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

    public func grantGroupPermission(_ options: GrantGroupPermissionOptions) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            var request = URLRequest(url: urlForGrantGroupPermission())
            request.httpMethod = "POST"
            request.appendAuthorizationHeader(accessKey)
            request.setJSONBody(options, continuation: continuation)
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

    public func revokeGroupPermission(_ options: RevokeGroupPermissionOptions) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            var request = URLRequest(url: urlForRevokeGroupPermission())
            request.httpMethod = "POST"
            request.appendAuthorizationHeader(accessKey)
            request.setJSONBody(options, continuation: continuation)
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
        URL(string: "\(baseURL)/files")!
    }

    public func urlForID(_ id: String) -> URL {
        URL(string: "\(url())/\(id)")!
    }

    public func urlForPath(_ id: String) -> URL {
        URL(string: "\(urlForID(id))/path")!
    }

    public func urlForCount(_ id: String) -> URL {
        URL(string: "\(urlForID(id))/count")!
    }

    public func urlForName(_ id: String) -> URL {
        URL(string: "\(urlForID(id))/name")!
    }

    public func urlForMove(_ id: String, to targetID: String) -> URL {
        URL(string: "\(urlForID(id))/move/\(targetID)")!
    }

    public func urlForMove() -> URL {
        URL(string: "\(url())/move")!
    }

    public func urlForCopy(_ id: String, to targetID: String) -> URL {
        URL(string: "\(urlForID(id))/copy/\(targetID)")!
    }

    public func urlForCopy() -> URL {
        URL(string: "\(url())/copy")!
    }

    public func urlForList(_ id: String, options: ListOptions) -> URL {
        if let query = options.urlQuery {
            URL(string: "\(urlForID(id))/list?\(query)")!
        } else {
            urlForID(id)
        }
    }

    public func urlForProbe(_ id: String, options: ListOptions) -> URL {
        if let query = options.urlQuery {
            URL(string: "\(urlForID(id))/probe?\(query)")!
        } else {
            URL(string: "\(urlForID(id))/probe")!
        }
    }

    public func urlForCreate(_ options: CreateFileOptions) -> URL {
        var urlComponents = URLComponents()
        urlComponents.queryItems = [
            .init(name: "type", value: FileType.file.rawValue),
            .init(name: "workspace_id", value: options.workspaceID),
            .init(name: "name", value: options.name),
        ]
        if let parentID = options.parentID {
            urlComponents.queryItems?.append(.init(name: "parent_id", value: parentID))
        }
        let query = urlComponents.url?.query
        return URL(string: "\(url())?" + query!)!
    }

    public func urlForCreate(_ options: CreateFolderOptions) -> URL {
        var urlComponents = URLComponents()
        urlComponents.queryItems = [
            .init(name: "type", value: FileType.folder.rawValue),
            .init(name: "workspace_id", value: options.workspaceID),
            .init(name: "name", value: options.name),
        ]
        if let parentID = options.parentID {
            urlComponents.queryItems?.append(URLQueryItem(name: "parent_id", value: parentID))
        }
        let query = urlComponents.url?.query
        return URL(string: "\(url())?" + query!)!
    }

    public func urlForOriginal(_ id: String, fileExtension: String) -> URL {
        URL(string: "\(urlForID(id))/original.\(fileExtension)?access_key=\(accessKey)")!
    }

    public func urlForPreview(_ id: String, fileExtension: String) -> URL {
        URL(string: "\(urlForID(id))/preview.\(fileExtension)?access_key=\(accessKey)")!
    }

    public func urlForText(_ id: String, fileExtension: String) -> URL {
        URL(string: "\(urlForID(id))/text.\(fileExtension)?access_key=\(accessKey)")!
    }

    public func urlForOCR(_ id: String, fileExtension: String) -> URL {
        URL(string: "\(urlForID(id))/ocr.\(fileExtension)?access_key=\(accessKey)")!
    }

    public func urlForThumbnail(_ id: String, fileExtension: String) -> URL {
        URL(string: "\(urlForID(id))/thumbnail.\(fileExtension)?access_key=\(accessKey)")!
    }

    public func urlForUserPermissions(_ id: String) -> URL {
        URL(string: "\(urlForID(id))/user_permissions")!
    }

    public func urlForGroupPermissions(_ id: String) -> URL {
        URL(string: "\(urlForID(id))/group_permissions")!
    }

    public func urlForGrantUserPermission() -> URL {
        URL(string: "\(url())/grant_user_permission")!
    }

    public func urlForRevokeUserPermission() -> URL {
        URL(string: "\(url())/revoke_user_permission")!
    }

    public func urlForGrantGroupPermission() -> URL {
        URL(string: "\(url())/grant_group_permission")!
    }

    public func urlForRevokeGroupPermission() -> URL {
        URL(string: "\(url())/revoke_group_permission")!
    }

    // MARK: - Payloads

    public struct PatchOptions {
        public let name: String
        public let data: Data
        public let onProgress: ((Double) -> Void)?

        public init(name: String, data: Data, onProgress: ((Double) -> Void)? = nil) {
            self.name = name
            self.data = data
            self.onProgress = onProgress
        }
    }

    public struct ListOptions {
        public let query: Query?
        public let page: Int?
        public let size: Int?
        public let sortBy: SortBy?
        public let sortOrder: SortOrder?

        public init(
            query: Query? = nil,
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
            if let page {
                items.append(.init(name: "page", value: String(page)))
            }
            if let size {
                items.append(.init(name: "size", value: String(size)))
            }
            if let sortBy {
                items.append(.init(name: "sort_by", value: sortBy.description))
            }
            if let sortOrder {
                items.append(.init(name: "sort_order", value: sortOrder.rawValue))
            }
            if let query, let base64Query = try? JSONEncoder().encode(query).base64EncodedString() {
                items.append(.init(name: "query", value: base64Query))
            }
            var components = URLComponents()
            components.queryItems = items
            return components.url?.query
        }
    }

    public enum SortBy: String, Codable, CustomStringConvertible, CaseIterable {
        case name
        case kind
        case size
        case dateCreated
        case dateModified

        public var description: String {
            switch self {
            case .name:
                "name"
            case .kind:
                "kind"
            case .size:
                "size"
            case .dateCreated:
                "date_created"
            case .dateModified:
                "date_modified"
            }
        }

        public var label: String {
            switch self {
            case .name:
                return "Sort By Name"
            case .kind:
                return "Sort By Kind"
            case .size:
                return "Sort By Size"
            case .dateCreated:
                return "Sort By Date Created"
            case .dateModified:
                return "Sort By Date Modified"
            }
        }
    }

    public enum SortOrder: String, Codable, CaseIterable {
        case asc
        case desc

        public var label: String {
            switch self {
            case .asc:
                return "Sort Ascending"
            case .desc:
                return "Sort Descending"
            }
        }
    }

    public struct CreateFileOptions {
        public let workspaceID: String
        public let parentID: String?
        public let name: String
        public let data: Data
        public let onProgress: ((Double) -> Void)?

        public init(
            workspaceID: String,
            parentID: String? = nil,
            name: String,
            data: Data,
            onProgress: ((Double) -> Void)? = nil
        ) {
            self.workspaceID = workspaceID
            self.parentID = parentID
            self.name = name
            self.data = data
            self.onProgress = onProgress
        }

        enum CodingKeys: String, CodingKey {
            case workspaceID = "workspaceId"
            case parentID = "parentId"
            case name
            case data
        }
    }

    public struct CreateFolderOptions: Codable {
        public let workspaceID: String
        public let parentID: String?
        public let name: String

        public init(
            workspaceID: String,
            parentID: String? = nil,
            name: String
        ) {
            self.workspaceID = workspaceID
            self.parentID = parentID
            self.name = name
        }

        enum CodingKeys: String, CodingKey {
            case workspaceID = "workspaceId"
            case parentID = "parentId"
            case name
        }
    }

    public struct PatchNameOptions: Codable {
        public let name: String

        public init(name: String) {
            self.name = name
        }
    }

    public struct DeleteOptions: Codable {
        public let ids: [String]

        public init(ids: [String]) {
            self.ids = ids
        }
    }

    public struct MoveOptions: Codable {
        public let sourceIDs: [String]
        public let targetID: String

        public init(sourceIDs: [String], targetID: String) {
            self.sourceIDs = sourceIDs
            self.targetID = targetID
        }

        enum CodingKeys: String, CodingKey {
            case sourceIDs = "sourceIds"
            case targetID = "targetId"
        }
    }

    public struct CopyOptions: Codable {
        public let sourceIDs: [String]
        public let targetID: String

        public init(sourceIDs: [String], targetID: String) {
            self.sourceIDs = sourceIDs
            self.targetID = targetID
        }

        enum CodingKeys: String, CodingKey {
            case sourceIDs = "sourceIds"
            case targetID = "targetId"
        }
    }

    public struct GrantUserPermissionOptions: Codable {
        public let ids: [String]
        public let userID: String
        public let permission: VOPermission.Value

        public init(ids: [String], userID: String, permission: VOPermission.Value) {
            self.ids = ids
            self.userID = userID
            self.permission = permission
        }

        enum CodingKeys: String, CodingKey {
            case ids
            case userID = "userId"
            case permission
        }
    }

    public struct RevokeUserPermissionOptions: Codable {
        public let ids: [String]
        public let userID: String

        public init(ids: [String], userID: String) {
            self.ids = ids
            self.userID = userID
        }

        enum CodingKeys: String, CodingKey {
            case ids
            case userID = "userId"
        }
    }

    public struct GrantGroupPermissionOptions: Codable {
        public let ids: [String]
        public let groupID: String
        public let permission: VOPermission.Value

        public init(ids: [String], groupID: String, permission: VOPermission.Value) {
            self.ids = ids
            self.groupID = groupID
            self.permission = permission
        }

        enum CodingKeys: String, CodingKey {
            case ids
            case groupID = "groupId"
            case permission
        }
    }

    public struct RevokeGroupPermissionOptions: Codable {
        public let ids: [String]
        public let groupID: String

        public init(ids: [String], groupID: String) {
            self.ids = ids
            self.groupID = groupID
        }

        enum CodingKeys: String, CodingKey {
            case ids
            case groupID = "groupId"
        }
    }

    // MARK: - Types

    public struct Entity: Codable, Equatable, Hashable {
        public let id: String
        public let name: String
        public let type: FileType
        public let parentID: String?
        public let permission: VOPermission.Value
        public let isShared: Bool?
        public let snapshot: VOSnapshot.Entity?
        public let workspace: VOWorkspace.Entity
        public let createTime: String
        public let updateTime: String?

        var displayID: String {
            "\(id)-\(self.objectCode)"
        }

        var objectCode: Int {
            var builder = Hasher()
            builder.combine(id)
            builder.combine(name)
            builder.combine(snapshot?.id)
            builder.combine(snapshot?.task?.status)
            builder.combine(isShared)
            builder.combine(permission.rawValue)
            builder.combine(updateTime)
            return builder.finalize()
        }

        public init(
            id: String,
            name: String,
            type: FileType,
            parentID: String?,
            permission: VOPermission.Value,
            isShared: Bool? = nil,
            snapshot: VOSnapshot.Entity? = nil,
            workspace: VOWorkspace.Entity,
            createTime: String,
            updateTime: String? = nil
        ) {
            self.id = id
            self.name = name
            self.type = type
            self.parentID = parentID
            self.permission = permission
            self.isShared = isShared
            self.snapshot = snapshot
            self.workspace = workspace
            self.createTime = createTime
            self.updateTime = updateTime
        }

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case type
            case parentID = "parentId"
            case permission
            case isShared
            case snapshot
            case workspace
            case createTime
            case updateTime
        }
    }

    public enum FileType: String, Codable {
        case file
        case folder
    }

    public struct List: Codable, Equatable, Hashable {
        public let data: [Entity]
        public let totalPages: Int
        public let totalElements: Int
        public let page: Int
        public let size: Int
        public let query: Query?

        public init(
            data: [Entity],
            totalPages: Int,
            totalElements: Int,
            page: Int,
            size: Int,
            query: Query? = nil
        ) {
            self.data = data
            self.totalPages = totalPages
            self.totalElements = totalElements
            self.page = page
            self.size = size
            self.query = query
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

    public struct UserPermission: Codable, Equatable, Hashable {
        public let id: String
        public let user: VOUser.Entity
        public let permission: VOPermission.Value

        public init(id: String, user: VOUser.Entity, permission: VOPermission.Value) {
            self.id = id
            self.user = user
            self.permission = permission
        }
    }

    public struct GroupPermission: Codable, Equatable, Hashable {
        public let id: String
        public let group: VOGroup.Entity
        public let permission: VOPermission.Value

        public init(id: String, group: VOGroup.Entity, permission: VOPermission.Value) {
            self.id = id
            self.group = group
            self.permission = permission
        }
    }

    public struct Query: Codable, Equatable, Hashable {
        public let text: String?
        public let type: FileType?
        public let createTimeAfter: Int?
        public let createTimeBefore: Int?
        public let updateTimeAfter: Int?
        public let updateTimeBefore: Int?

        public init(
            text: String? = nil,
            type: FileType? = nil,
            createTimeAfter: Int? = nil,
            createTimeBefore: Int? = nil,
            updateTimeAfter: Int? = nil,
            updateTimeBefore: Int? = nil
        ) {
            self.text = text
            self.type = type
            self.createTimeAfter = createTimeAfter
            self.createTimeBefore = createTimeBefore
            self.updateTimeAfter = updateTimeAfter
            self.updateTimeBefore = updateTimeBefore
        }

        static func encodeToBase64(_ value: String) -> String {
            guard let data = value.data(using: .utf8) else {
                return ""
            }
            return data.base64EncodedString()
        }

        static func decodeFromBase64(_ value: String) -> String? {
            guard !value.isEmpty, let data = Data(base64Encoded: value) else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        }
    }

    public struct CopyResult: Codable, Equatable, Hashable {
        public let new: [String]
        public let succeeded: [String]
        public let failed: [String]

        public init(new: [String], succeeded: [String], failed: [String]) {
            self.new = new
            self.succeeded = succeeded
            self.failed = failed
        }
    }

    public struct MoveResult: Codable, Equatable, Hashable {
        public let succeeded: [String]
        public let failed: [String]

        public init(succeeded: [String], failed: [String]) {
            self.succeeded = succeeded
            self.failed = failed
        }
    }

    public struct DeleteResult: Codable, Equatable, Hashable {
        public let succeeded: [String]
        public let failed: [String]

        public init(succeeded: [String], failed: [String]) {
            self.succeeded = succeeded
            self.failed = failed
        }
    }
}
