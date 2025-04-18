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

public struct VOIdentityUser {
    let baseURL: String
    let accessKey: String

    public init(baseURL: String, accessKey: String) {
        self.baseURL = URL(string: baseURL)!.appendingPathComponent("v3").absoluteString
        self.accessKey = accessKey
    }

    // MARK: - Requests

    public func fetch() async throws -> Entity {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForMe())
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

    public func delete() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            var request = URLRequest(url: urlForMe())
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

    public func updateFullName(_ options: UpdateFullNameOptions) async throws -> Entity {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForPatchFullName())
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

    public func updateEmailRequest(_ options: UpdateEmailRequestOptions) async throws -> Entity {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForUpdateEmailRequest())
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

    public func updateEmailConfirmation(_ options: UpdateEmailConfirmationOptions) async throws -> Entity {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForUpdateEmailConfirmation())
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

    public func updatePassword(_ options: UpdatePasswordOptions) async throws -> Entity {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForUpdatePassword())
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

    public func updatePicture(
        data: Data,
        filename: String,
        mimeType: String,
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> Entity {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForUpdatePicture())
            request.httpMethod = "POST"
            request.appendAuthorizationHeader(accessKey)

            let boundary = UUID().uuidString
            request.setValue(
                "multipart/form-data; boundary=\(boundary)",
                forHTTPHeaderField: "Content-Type"
            )

            var httpBody = Data()
            httpBody.append(Data("--\(boundary)\r\n".utf8))
            httpBody.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".utf8))
            httpBody.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))

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

    public func deletePicture() async throws -> Entity {
        try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: urlForDeletePicture())
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

    // MARK: - URLs

    public func url() -> URL {
        URL(string: "\(baseURL)/users")!
    }

    public func urlForMe() -> URL {
        URL(string: "\(url())/me")!
    }

    public func urlForPatchFullName() -> URL {
        URL(string: "\(urlForMe())/update_full_name")!
    }

    public func urlForUpdateEmailRequest() -> URL {
        URL(string: "\(urlForMe())/update_email_request")!
    }

    public func urlForUpdateEmailConfirmation() -> URL {
        URL(string: "\(urlForMe())/update_email_confirmation")!
    }

    public func urlForUpdatePassword() -> URL {
        URL(string: "\(urlForMe())/update_password")!
    }

    public func urlForUpdatePicture() -> URL {
        URL(string: "\(urlForMe())/update_picture")!
    }

    public func urlForDeletePicture() -> URL {
        URL(string: "\(urlForMe())/delete_picture")!
    }

    public func urlForPicture(_: String, fileExtension: String) -> URL {
        URL(string: "\(urlForMe())/picture\(fileExtension)?access_key=\(accessKey)")!
    }

    // MARK: - Payloads

    public struct UpdateFullNameOptions: Codable {
        public let fullName: String

        public init(fullName: String) {
            self.fullName = fullName
        }
    }

    public struct UpdateEmailRequestOptions: Codable {
        public let email: String

        public init(email: String) {
            self.email = email
        }
    }

    public struct UpdateEmailConfirmationOptions: Codable {
        public let key: String

        public init(key: String) {
            self.key = key
        }
    }

    public struct UpdatePasswordOptions: Codable {
        public let currentPassword: String
        public let newPassword: String

        public init(currentPassword: String, newPassword: String) {
            self.currentPassword = currentPassword
            self.newPassword = newPassword
        }
    }

    // MARK: - Types

    public struct Entity: Codable, Equatable, Hashable {
        public let id: String
        public let username: String
        public let email: String
        public let fullName: String
        public let picture: Picture?
        public let pendingEmail: String?

        public init(
            id: String,
            username: String,
            email: String,
            fullName: String,
            picture: Picture? = nil,
            pendingEmail: String? = nil
        ) {
            self.id = id
            self.username = username
            self.email = email
            self.fullName = fullName
            self.picture = picture
            self.pendingEmail = pendingEmail
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
}
