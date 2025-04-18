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

public struct VOMosaic {
    let baseURL: String
    let accessKey: String

    public init(baseURL: String, accessKey: String) {
        self.baseURL = URL(string: baseURL)!.appendingPathComponent("v3").absoluteString
        self.accessKey = accessKey
    }

    // MARK: - Requests

    public func fetchMetadata(_ id: String) async throws -> Metadata {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForMetadata(id))
            request.httpMethod = "GET"
            request.appendAuthorizationHeader(accessKey)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                handleJSONResponse(
                    continuation: continuation,
                    response: response,
                    data: data,
                    error: error,
                    type: Metadata.self
                )
            }
            task.resume()
        }
    }

    public func fetchData(
        _ id: String,
        zoomLevel: ZoomLevel,
        forCellAtRow row: Int, column: Int,
        fileExtension: String
    ) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(
                url: urlForTile(
                    id,
                    zoomLevel: zoomLevel,
                    row: row,
                    column: column,
                    fileExtension: fileExtension
                ))
            request.httpMethod = "GET"
            request.appendAuthorizationHeader(accessKey)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                handleDataResponse(
                    continuation: continuation,
                    response: response,
                    data: data,
                    error: error
                )
            }
            task.resume()
        }
    }

    public func create(_ id: String) async throws -> VOTask.Entity {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForFile(id))
            request.httpMethod = "POST"
            request.appendAuthorizationHeader(accessKey)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                handleJSONResponse(
                    continuation: continuation,
                    response: response,
                    data: data,
                    error: error,
                    type: VOTask.Entity.self
                )
            }
            task.resume()
        }
    }

    public func delete(_ id: String) async throws -> VOTask.Entity {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForFile(id))
            request.httpMethod = "DELETE"
            request.appendAuthorizationHeader(accessKey)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                handleJSONResponse(
                    continuation: continuation,
                    response: response,
                    data: data,
                    error: error,
                    type: VOTask.Entity.self
                )
            }
            task.resume()
        }
    }

    // MARK: - URLs

    public func url() -> URL {
        URL(string: "\(baseURL)/mosaics")!
    }

    public func urlForFile(_ id: String) -> URL {
        URL(string: "\(url())/\(id)")!
    }

    public func urlForMetadata(_ id: String) -> URL {
        URL(string: "\(urlForFile(id))/metadata")!
    }

    public func urlForTile(
        _ id: String,
        zoomLevel: ZoomLevel,
        row: Int,
        column: Int,
        fileExtension: String
    ) -> URL {
        // swift-format-ignore
        // swiftlint:disable:next line_length
        URL(string: "\(urlForFile(id))/zoom_level/\(zoomLevel.index)/row/\(row)/column/\(column)/extension/\(fileExtension)?access_key=\(accessKey)")!
    }

    // MARK: - Types

    public struct Metadata: Codable, Equatable, Hashable {
        public let width: Int
        public let height: Int
        public let fileExtension: String
        public let zoomLevels: [ZoomLevel]

        public init(width: Int, height: Int, fileExtension: String, zoomLevels: [ZoomLevel]) {
            self.width = width
            self.height = height
            self.fileExtension = fileExtension
            self.zoomLevels = zoomLevels
        }

        enum CodingKeys: String, CodingKey {
            case width
            case height
            case fileExtension = "extension"
            case zoomLevels
        }
    }

    public struct ZoomLevel: Codable, Equatable, Hashable {
        public let index: Int
        public let width: Int
        public let height: Int
        public let rows: Int
        public let cols: Int
        public let scaleDownPercentage: Float
        public let tile: Tile

        public init(
            index: Int,
            width: Int,
            height: Int,
            rows: Int,
            cols: Int,
            scaleDownPercentage: Float,
            tile: Tile
        ) {
            self.index = index
            self.width = width
            self.height = height
            self.rows = rows
            self.cols = cols
            self.scaleDownPercentage = scaleDownPercentage
            self.tile = tile
        }
    }

    public struct Tile: Codable, Equatable, Hashable {
        public let width: Int
        public let height: Int
        public let lastColWidth: Int
        public let lastRowHeight: Int

        public init(width: Int, height: Int, lastColWidth: Int, lastRowHeight: Int) {
            self.width = width
            self.height = height
            self.lastColWidth = lastColWidth
            self.lastRowHeight = lastRowHeight
        }
    }
}
