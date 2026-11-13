import Foundation
import Combine
import Security

/// Mining destination only. No wallet password or recovery phrase is handled.
enum WalletCurrency: String, Codable, CaseIterable, Identifiable {
    case monero
    case duinoCoin

    var id: String { rawValue }

    var label: String {
        switch self {
        case .monero: return "Monero (XMR)"
        case .duinoCoin: return "Duino-Coin (DUCO)"
        }
    }
}

struct WalletCredentials: Codable, Equatable {
    let username: String // DUCO username, or PUBLIC Monero address.
    let miningKey: String // DUCO only.
    let currency: WalletCurrency

    init(username: String, miningKey: String, currency: WalletCurrency) {
        self.username = username
        self.miningKey = miningKey
        self.currency = currency
    }

    private enum CodingKeys: String, CodingKey {
        case username, miningKey, currency
    }

    // Migration of DUCO-only profiles from the previous app version.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        username = try values.decode(String.self, forKey: .username)
        miningKey = try values.decode(String.self, forKey: .miningKey)
        currency = try values.decodeIfPresent(WalletCurrency.self, forKey: .currency) ?? .duinoCoin
    }
}

final class WalletConnection: ObservableObject {
    @Published private(set) var account: WalletCredentials? = WalletKeychain.load()

    func connect(currency: WalletCurrency, username: String, miningKey: String) -> Bool {
        let clean = username.trimmingCharacters(in: .whitespacesAndNewlines)
        switch currency {
        case .monero:
            let base58 = Set("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
            // Basic format gate; not a full Monero checksum validation.
            guard clean.count == 95,
                  (clean.hasPrefix("4") || clean.hasPrefix("8")),
                  clean.allSatisfy({ base58.contains($0) }) else { return false }
        case .duinoCoin:
            guard clean.range(of: "^[A-Za-z0-9_-]{2,40}$", options: .regularExpression) != nil,
                  !miningKey.contains(","), !miningKey.contains("\n"), !miningKey.contains("\r"),
                  miningKey.count <= 128 else { return false }
        }
        let value = WalletCredentials(username: clean,
                                      miningKey: currency == .duinoCoin ? miningKey : "",
                                      currency: currency)
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
