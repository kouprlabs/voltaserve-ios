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

extension KeychainManager {
    func saveSession(_ session: VOSession.Value, forKey key: String) {
        if let data = try? JSONEncoder().encode(session),
            let serialized = String(data: data, encoding: .utf8)
        {
            saveString(serialized, for: key)
        }
    }

    func getSession(_ key: String) -> VOSession.Value? {
        if let value = getString(key), let data = value.data(using: .utf8) {
            return try? JSONDecoder().decode(VOSession.Value.self, from: data)
        }
        return nil
    }

    enum Constants {
        static let sessionKey = "com.voltaserve.session"
    }
}
