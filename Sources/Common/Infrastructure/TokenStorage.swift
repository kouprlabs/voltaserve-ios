import Foundation
import Voltaserve

extension KeychainManager {
    func saveToken(_ token: VOToken.Value, forKey key: String) {
        if let data = try? JSONEncoder().encode(token),
           let serialized = String(data: data, encoding: .utf8) {
            saveString(serialized, for: key)
        }
    }

    func getToken(_ key: String) -> VOToken.Value? {
        if let value = getString(key), let data = value.data(using: .utf8) {
            return try? JSONDecoder().decode(VOToken.Value.self, from: data)
        }
        return nil
    }

    enum Constants {
        static let tokenKey = "com.voltaserve.token"
    }
}