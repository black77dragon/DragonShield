import Foundation
import Security

enum KeychainService {
    static let service = "com.rene.DragonShield.priceproviders"
    private static var memory: [String: String] = [:]

    static func set(_ value: String, account: String) -> Bool {
        // Cache in memory to avoid repeated keychain prompts during this session.
        memory[account] = value
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let update: [String: Any] = [kSecValueData as String: data]
        let status: OSStatus
        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        } else {
            var q = query
            q[kSecValueData as String] = data
            status = SecItemAdd(q as CFDictionary, nil)
        }
        return status == errSecSuccess
    }

    static func get(account: String) -> String? {
        // 1) In-memory cache
        if let v = memory[account] { return v }
        // 2) UserDefaults lightweight storage (optional, less secure)
        let defaultsKey = "api_key.\(account)"
        if let v = UserDefaults.standard.string(forKey: defaultsKey), !v.isEmpty {
            memory[account] = v
            return v
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let str = String(data: data, encoding: .utf8) else { return nil }
        memory[account] = str
        return str
    }

    static func delete(account: String) {
        memory.removeValue(forKey: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
