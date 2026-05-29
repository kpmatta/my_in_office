import Foundation

enum SensitiveDataMigration {
    static func runIfNeeded(
        userDefaults: UserDefaults = .standard,
        keychain: KeychainStore = KeychainStore()
    ) {
        let items: [UserDefaultsToKeychainMigrator.Item] = [
            // Add only legacy sensitive values that shipped in UserDefaults.
            // .init(userDefaultsKey: "accessToken", keychainAccount: "auth.accessToken"),
            // .init(userDefaultsKey: "refreshToken", keychainAccount: "auth.refreshToken", accessibility: .afterFirstUnlockThisDeviceOnly),
        ]

        guard !items.isEmpty else {
            return
        }

        let results = UserDefaultsToKeychainMigrator.migrate(
            items: items,
            userDefaults: userDefaults,
            keychain: keychain
        )

#if DEBUG
        for result in results where result.status.shouldLog {
            AppDiagnostics.error("[SensitiveDataMigration] \(result.item.userDefaultsKey): \(result.status)")
        }
#endif
    }
}

enum UserDefaultsToKeychainMigrator {
    struct Item {
        enum ValueType {
            case string
            case data
        }

        let userDefaultsKey: String
        let keychainAccount: String
        let valueType: ValueType
        let accessibility: KeychainAccessibility

        init(
            userDefaultsKey: String,
            keychainAccount: String? = nil,
            valueType: ValueType = .string,
            accessibility: KeychainAccessibility = .whenUnlockedThisDeviceOnly
        ) {
            self.userDefaultsKey = userDefaultsKey
            self.keychainAccount = keychainAccount ?? userDefaultsKey
            self.valueType = valueType
            self.accessibility = accessibility
        }
    }

    struct Result {
        let item: Item
        let status: Status
    }

    enum Status: CustomStringConvertible {
        case migrated
        case alreadyMigrated
        case noLegacyValue
        case skippedDueToKeychainMismatch
        case failedToEncodeLegacyValue
        case failedToWriteKeychain(OSStatus)
        case failedToVerifyKeychainCopy

        var shouldLog: Bool {
            switch self {
            case .noLegacyValue:
                return false
            default:
                return true
            }
        }

        var description: String {
            switch self {
            case .migrated:
                return "migrated"
            case .alreadyMigrated:
                return "already migrated"
            case .noLegacyValue:
                return "no legacy value"
            case .skippedDueToKeychainMismatch:
                return "skipped because a different value already exists in the Keychain"
            case .failedToEncodeLegacyValue:
                return "failed to encode the legacy UserDefaults value"
            case .failedToWriteKeychain(let status):
                return "failed to write to the Keychain (\(status))"
            case .failedToVerifyKeychainCopy:
                return "failed to verify the Keychain copy"
            }
        }
    }

    static func migrate(
        items: [Item],
        userDefaults: UserDefaults = .standard,
        keychain: KeychainStore = KeychainStore()
    ) -> [Result] {
        items.map { item in
            migrate(item: item, userDefaults: userDefaults, keychain: keychain)
        }
    }

    private static func migrate(
        item: Item,
        userDefaults: UserDefaults,
        keychain: KeychainStore
    ) -> Result {
        guard userDefaults.object(forKey: item.userDefaultsKey) != nil else {
            return Result(item: item, status: .noLegacyValue)
        }

        guard let legacyData = legacyData(for: item, userDefaults: userDefaults) else {
            return Result(item: item, status: .failedToEncodeLegacyValue)
        }

        if let keychainData = keychain.data(for: item.keychainAccount) {
            guard keychainData == legacyData else {
                return Result(item: item, status: .skippedDueToKeychainMismatch)
            }

            userDefaults.removeObject(forKey: item.userDefaultsKey)
            return Result(item: item, status: .alreadyMigrated)
        }

        let writeStatus = keychain.set(
            legacyData,
            for: item.keychainAccount,
            accessibility: item.accessibility
        )
        guard writeStatus == errSecSuccess else {
            return Result(item: item, status: .failedToWriteKeychain(writeStatus))
        }

        guard keychain.data(for: item.keychainAccount) == legacyData else {
            return Result(item: item, status: .failedToVerifyKeychainCopy)
        }

        userDefaults.removeObject(forKey: item.userDefaultsKey)
        return Result(item: item, status: .migrated)
    }

    private static func legacyData(for item: Item, userDefaults: UserDefaults) -> Data? {
        switch item.valueType {
        case .string:
            guard let value = userDefaults.string(forKey: item.userDefaultsKey) else {
                return nil
            }
            return value.data(using: .utf8)

        case .data:
            return userDefaults.data(forKey: item.userDefaultsKey)
        }
    }
}
