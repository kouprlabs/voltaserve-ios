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
public class SessionStore: ObservableObject {
    @Published public var session: VOSession.Value?
    private var client = createClient()

    public init() {}

    private static func createClient() -> VOSession {
        VOSession(baseURL: Config.shared.idpURL)
    }

    public func recreateClient() {
        client = SessionStore.createClient()
    }

    public func signInWithLocal(username: String, password: String) async throws -> VOSession.Value {
        try await client.exchange(
            .init(
                grantType: .password,
                username: username,
                password: password
            ))
    }

    public func signInWithApple(appleKey: String, fullName: String?) async throws -> VOSession.Value {
        try await client.exchange(.init(grantType: .apple, appleKey: appleKey))
    }

    public func refreshSessionIfNecessary() async throws -> VOSession.Value? {
        guard session != nil else { return nil }
        if let session, session.isExpired {
            if let newSession = try? await client.exchange(
                .init(
                    grantType: .refreshKey,
                    refreshKey: session.refreshKey
                ))
            {
                return newSession
            }
        }
        return nil
    }

    public func loadFromKeyChain() -> VOSession.Value? {
        KeychainManager.standard.getSession(KeychainManager.Constants.sessionKey)
    }

    public func saveInKeychain(_ session: VOSession.Value) {
        KeychainManager.standard.saveSession(session, forKey: KeychainManager.Constants.sessionKey)
    }

    public func deleteFromKeychain() {
        KeychainManager.standard.delete(KeychainManager.Constants.sessionKey)
    }
}

extension VOSession.Value {
    public var isExpired: Bool {
        Int(Date().timeIntervalSince1970) >= expiresIn
    }
}
