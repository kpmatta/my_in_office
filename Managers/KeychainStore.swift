import Foundation
import Security

enum KeychainAccessibility {
    case whenUnlockedThisDeviceOnly
    case afterFirstUnlockThisDeviceOnly

    var secAttrValue: CFString {
        switch self {
        case .whenUnlockedThisDeviceOnly:
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .afterFirstUnlockThisDeviceOnly:
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
    }
}

struct KeychainStore {
    let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "InOffice") {
        self.service = service
    }

    func data(for account: String) -> Data? {
        var query = baseQuery(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            return nil
        }

        return result as? Data
    }

    func string(for account: String) -> String? {
        guard let storedData = data(for: account) else {
            return nil
        }

        return String(data: storedData, encoding: .utf8)
    }

    @discardableResult
    func set(
        _ data: Data,
        for account: String,
        accessibility: KeychainAccessibility = .whenUnlockedThisDeviceOnly
    ) -> OSStatus {
        let query = baseQuery(for: account)
        let attributes = [kSecValueData as String: data] as CFDictionary

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes)
        if updateStatus == errSecSuccess {
            return errSecSuccess
        }
        if updateStatus != errSecItemNotFound {
            return updateStatus
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = accessibility.secAttrValue
        return SecItemAdd(addQuery as CFDictionary, nil)
    }

    @discardableResult
    func set(
        _ string: String,
        for account: String,
        accessibility: KeychainAccessibility = .whenUnlockedThisDeviceOnly
    ) -> OSStatus {
        set(Data(string.utf8), for: account, accessibility: accessibility)
    }

    @discardableResult
    func deleteValue(for account: String) -> OSStatus {
        SecItemDelete(baseQuery(for: account) as CFDictionary)
    }

    private func baseQuery(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
