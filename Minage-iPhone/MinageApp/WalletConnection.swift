import Foundation
import Combine
import Security

/// These are the public DUCO username and optional MINING key.
/// Never store the wallet password or recovery phrase here.
struct WalletCredentials: Codable, Equatable {
    let username: String
    let miningKey: String
}

final class WalletConnection: ObservableObject {
    @Published private(set) var account: WalletCredentials? = WalletKeychain.load()

    func connect(username: String, miningKey: String) -> Bool {
        let clean = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.range(of: "^[A-Za-z0-9_-]{2,40}$", options: .regularExpression) != nil,
              !miningKey.contains(","), !miningKey.contains("\n"), !miningKey.contains("\r"),
              miningKey.count <= 128 else {
            return false
        }
        let value = WalletCredentials(username: clean, miningKey: miningKey)
        guard WalletKeychain.save(value) else { return false }
        account = value
        return true
    }

    func disconnect() {
        WalletKeychain.delete()
        account = nil
    }
}

private enum WalletKeychain {
    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "fr.minageiphone.lab.duco",
        kSecAttrAccount as String: "mining-profile"
    ]

    static func save(_ account: WalletCredentials) -> Bool {
        guard let data = try? JSONEncoder().encode(account) else { return false }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        if status == errSecDuplicateItem {
            return SecItemUpdate(query as CFDictionary,
                                 [kSecValueData as String: data] as CFDictionary) == errSecSuccess
        }
        return status == errSecSuccess
    }

    static func load() -> WalletCredentials? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(WalletCredentials.self, from: data)
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}
