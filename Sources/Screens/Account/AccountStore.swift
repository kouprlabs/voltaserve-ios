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

@MainActor
public class AccountStore: ObservableObject {
    @Published public var identityUser: VOIdentityUser.Entity?
    @Published public var identityUserError: String?
    @Published public var identityUserIsLoading = false
    @Published public var storageUsage: VOStorage.Usage?
    @Published public var storageUsageError: String?
    @Published public var storageUsageIsLoading = false
    private var timer: Timer?
    private var accountClient: VOAccount = .init(baseURL: Config.shared.idpURL)
    private var identityUserClient: VOIdentityUser?
    private var storageClient: VOStorage?
    public var sessionStore: SessionStore?

    public var session: VOSession.Value? {
        didSet {
            if let session {
                identityUserClient = .init(
                    baseURL: Config.shared.idpURL,
                    accessKey: session.accessKey
                )
                storageClient = .init(
                    baseURL: Config.shared.apiURL,
                    accessKey: session.accessKey
                )
            }
        }
    }

    public init(_ identityUser: VOIdentityUser.Entity? = nil) {
        self.identityUser = identityUser
    }

    // MARK: - URLs

    public func urlForUserPicture(_ id: String, fileExtension: String? = nil) -> URL? {
        if let fileExtension {
            return identityUserClient?.urlForPicture(id, fileExtension: fileExtension)
        }
        return nil
    }

    private func fetchIdentityUser() async throws -> VOIdentityUser.Entity? {
        try await identityUserClient?.fetch()
    }

    // MARK: - Fetch

    public func fetchIdentityUser() {
        var identityUser: VOIdentityUser.Entity?
        withErrorHandling {
            identityUser = try await self.fetchIdentityUser()
            return true
        } before: {
            self.identityUserIsLoading = true
        } success: {
            self.identityUser = identityUser
            self.identityUserError = nil
        } failure: { message in
            self.identityUserError = message
        } invalidCredentials: {
            self.sessionStore?.session = nil
            self.sessionStore?.deleteFromKeychain()
        } anyways: {
            self.identityUserIsLoading = false
        }
    }

    private func fetchAccountStorageUsage() async throws -> VOStorage.Usage? {
        try await storageClient?.fetchAccountUsage()
    }

    public func fetchAccountStorageUsage() {
        var storageUsage: VOStorage.Usage?
        withErrorHandling {
            storageUsage = try await self.fetchAccountStorageUsage()
            return true
        } before: {
            self.storageUsageIsLoading = true
        } success: {
            self.storageUsage = storageUsage
            self.storageUsageError = nil
        } failure: { message in
            self.storageUsageError = message
        } anyways: {
            self.storageUsageIsLoading = false
        }
    }

    // MARK: - Update

    public func updateEmail(_ email: String) async throws -> VOIdentityUser.Entity? {
        try await identityUserClient?.updateEmailRequest(.init(email: email))
    }

    public func updateFullName(_ fullName: String) async throws -> VOIdentityUser.Entity? {
        try await identityUserClient?.updateFullName(.init(fullName: fullName))
    }

    public func updatePassword(current: String, new: String) async throws -> VOIdentityUser.Entity? {
        try await identityUserClient?.updatePassword(.init(currentPassword: current, newPassword: new))
    }

    public func updatePicture(data: Data, filename: String, mimeType: String) async throws -> VOIdentityUser.Entity? {
        return try await identityUserClient?.updatePicture(data: data, filename: filename, mimeType: mimeType)
    }

    public func deletePicture() async throws -> VOIdentityUser.Entity? {
        return try await identityUserClient?.deletePicture()
    }

    public func deleteAccount() async throws {
        try await identityUserClient?.delete()
    }

    // MARK: - Timer

    public func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task.detached {
                if await self.identityUser != nil, await self.sessionStore?.session != nil {
                    let user = try await self.fetchIdentityUser()
                    if let user {
                        await MainActor.run {
                            self.identityUser = user
                            self.identityUserError = nil
                        }
                    }
                }
                if await self.storageUsage != nil {
                    let storageUsage = try await self.fetchAccountStorageUsage()
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

    public func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
