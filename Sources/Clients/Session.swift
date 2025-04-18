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

public struct VOSession {
    let baseURL: String

    public init(baseURL: String) {
        self.baseURL = URL(string: baseURL)!.appendingPathComponent("v3").absoluteString
    }

    // MARK: - Requests

    public func exchange(_ options: ExchangeOptions) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: url())
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(options.urlEncodedString.utf8)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                handleJSONResponse(
                    continuation: continuation,
                    response: response,
                    data: data,
                    error: error,
                    type: Value.self
                )
            }
            task.resume()
        }
    }

    // MARK: - URLs

    public func url() -> URL {
        URL(string: "\(baseURL)/session")!
    }

    // MARK: - Payloads

    public struct ExchangeOptions: Codable {
        public let grantType: GrantType
        public let username: String?
        public let password: String?
        public let refreshKey: String?
        public let appleKey: String?
        public let appleFullName: String?
        public let locale: String?

        public init(
            grantType: GrantType,
            username: String? = nil,
            password: String? = nil,
            refreshKey: String? = nil,
            appleKey: String? = nil,
            appleFullName: String? = nil,
            locale: String? = nil
        ) {
            self.grantType = grantType
            self.username = username
            self.password = password
            self.refreshKey = refreshKey
            self.appleKey = appleKey
            self.appleFullName = appleFullName
            self.locale = locale
        }

        var urlParameters: [String: String] {
            var params: [String: String] = ["grant_type": grantType.rawValue]
            if let username {
                params["username"] = username
            }
            if let password {
                params["password"] = password
            }
            if let refreshKey {
                params["refresh_key"] = refreshKey
            }
            if let appleKey {
                params["apple_key"] = appleKey
            }
            if let appleFullName {
                params["apple_full_name"] = appleFullName
            }
            if let locale {
                params["locale"] = locale
            }
            return params
        }

        var urlEncodedString: String {
            var components = URLComponents()
            components.queryItems = urlParameters.map { key, value in
                URLQueryItem(name: key, value: value)
            }

            // Explicitly replace spaces with + and encode & characters
            var percentEncodedQuery = components.percentEncodedQuery ?? ""
            percentEncodedQuery =
                percentEncodedQuery
                .replacingOccurrences(of: "+", with: "%2B")
                .replacingOccurrences(of: "%20", with: "+")
            return percentEncodedQuery
        }
    }

    public enum GrantType: String, Codable {
        case password
        case refreshKey = "refresh_key"
        case apple
    }

    // MARK: - Types

    public struct Value: Codable, Equatable, Hashable {
        public var accessKey: String
        public var expiresIn: Int
        public var keyType: String
        public var refreshKey: String

        public init(accessKey: String, expiresIn: Int, keyType: String, refreshKey: String) {
            self.accessKey = accessKey
            self.expiresIn = expiresIn
            self.keyType = keyType
            self.refreshKey = refreshKey
        }

        enum CodingKeys: String, CodingKey {
            case accessKey = "access_key"
            case expiresIn = "expires_in"
            case keyType = "key_type"
            case refreshKey = "refresh_key"
        }
    }
}
