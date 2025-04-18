// Copyright (c) 2024 Anass Bouassaba.
//
// Use of this software is governed by the Business Source License
// included in the file LICENSE in the root of this repository.
//
// As of the Change Date specified in that file, in accordance with
// the Business Source License, use of this software will be governed
// by the GNU Affero General Public License v3.0 only, included in the file
// AGPL-3.0-only in the root of this repository.

import VoltaserveCore

class SessionFactory {
    private let config = Config()
    private(set) var value: VOSession.Value

    var accessKey: String {
        value.accessKey
    }

    init(_ credentials: Config.Credentials) async throws {
        value = try await VOSession(baseURL: config.idpURL).exchange(
            .init(
                grantType: .password,
                username: credentials.username,
                password: credentials.password,
                refreshKey: nil,
                locale: nil
            ))
    }
}
