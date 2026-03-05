// GutSense — KeychainService.swift
// Secure Keychain wrapper for API keys, passwords, and service credentials
// Uses kSecClassGenericPassword with service-scoped keys

import Foundation
import Security
import Combine

// MARK: - Keychain Error

enum KeychainError: LocalizedError {
    case itemNotFound
    case duplicateItem
    case invalidData
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .itemNotFound:           return "Credential not found in Keychain"
        case .duplicateItem:          return "Credential already exists"
        case .invalidData:            return "Could not encode/decode credential data"
        case .unexpectedStatus(let s): return "Keychain error (OSStatus \(s))"
        }
    }
}

// MARK: - Credential Definition

struct CredentialDefinition: Identifiable, Hashable {
    let id: String                  // Stable keychain key
    let service: ServiceIdentifier
    let label: String               // Display label
    let placeholder: String
    let isPassword: Bool            // true → SecureField
    let helpText: String
    let required: Bool
    let validationHint: String?     // e.g. "Starts with sk-ant-"
}

enum ServiceIdentifier: String, CaseIterable, Identifiable {
    case anthropic    = "Anthropic"
    case gemini       = "Google Gemini"
    case gutsenseAPI  = "GutSense Backend"
    case monash       = "Monash FODMAP"
    case custom       = "Custom"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .anthropic:   return "sparkles"
        case .gemini:      return "brain.head.profile"
        case .gutsenseAPI: return "server.rack"
        case .monash:      return "cross.case.fill"
        case .custom:      return "key.fill"
        }
    }

    var tintColor: String {  // Hex strings for cross-view use
        switch self {
        case .anthropic:   return "#C97B47"
        case .gemini:      return "#4285F4"
        case .gutsenseAPI: return "#34C759"
        case .monash:      return "#AF52DE"
        case .custom:      return "#8E8E93"
        }
    }

    var credentials: [CredentialDefinition] {
        switch self {
        case .anthropic:
            return [
                CredentialDefinition(
                    id: "anthropic.api_key",
                    service: .anthropic,
                    label: "API Key",
                    placeholder: "sk-ant-api03-…",
                    isPassword: true,
                    helpText: "Found at console.anthropic.com → API Keys",
                    required: true,
                    validationHint: "Starts with sk-ant-"
                )
            ]
        case .gemini:
            return [
                CredentialDefinition(
                    id: "gemini.api_key",
                    service: .gemini,
                    label: "API Key",
                    placeholder: "AIza…",
                    isPassword: true,
                    helpText: "Found at aistudio.google.com → Get API Key",
                    required: true,
                    validationHint: "Starts with AIza"
                )
            ]
        case .gutsenseAPI:
            return [
                CredentialDefinition(
                    id: "gutsense.backend_url",
                    service: .gutsenseAPI,
                    label: "Backend URL",
                    placeholder: "https://your-app.railway.app",
                    isPassword: false,
                    helpText: "Your Railway or custom FastAPI deployment URL",
                    required: true,
                    validationHint: nil
                ),
                CredentialDefinition(
                    id: "gutsense.api_secret",
                    service: .gutsenseAPI,
                    label: "API Secret (optional)",
                    placeholder: "Bearer token if configured",
                    isPassword: true,
                    helpText: "Optional shared secret to authenticate iOS → backend",
                    required: false,
                    validationHint: nil
                )
            ]
        case .monash:
            return [
                CredentialDefinition(
                    id: "monash.email",
                    service: .monash,
                    label: "Email",
                    placeholder: "you@example.com",
                    isPassword: false,
                    helpText: "Your Monash FODMAP app account email",
                    required: false,
                    validationHint: nil
                ),
                CredentialDefinition(
                    id: "monash.password",
                    service: .monash,
                    label: "Password",
                    placeholder: "••••••••",
                    isPassword: true,
                    helpText: "Your Monash FODMAP account password",
                    required: false,
                    validationHint: nil
                )
            ]
        case .custom:
            return []  // Dynamically added by user
        }
    }
}

// MARK: - Keychain Service

final class KeychainService {
    static let shared = KeychainService()
    private let keychainServiceName = "com.gutsense.credentials"

    private init() {}

    // MARK: Save

    func save(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     keychainServiceName,
            kSecAttrAccount:     key,
            kSecValueData:       data,
            kSecAttrAccessible:  kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Try to delete existing first (upsert pattern)
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: Read

    func read(for key: String) throws -> String {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      keychainServiceName,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound { throw KeychainError.itemNotFound }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        return string
    }

    // MARK: Delete

    func delete(for key: String) throws {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrService:  keychainServiceName,
            kSecAttrAccount:  key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: Check Existence

    func exists(for key: String) -> Bool {
        (try? read(for: key)) != nil
    }

    // MARK: Masked Preview

    func maskedValue(for key: String) -> String {
        guard let value = try? read(for: key), !value.isEmpty else {
            return "Not set"
        }
        let prefix = String(value.prefix(6))
        return prefix + String(repeating: "•", count: min(value.count - 6, 20))
    }
}

// MARK: - Credentials Store (ObservableObject)

final class CredentialsStore: ObservableObject {

    static let shared = CredentialsStore()
    private let keychain = KeychainService.shared

    // Tracks which keys are saved (no values in memory)
    @Published var savedKeys: Set<String> = []
    @Published var customServices: [CustomServiceDefinition] = []

    // Validation state
    @Published var validationErrors: [String: String] = [:]

    private init() {
        refreshSavedKeys()
        loadCustomServices()
    }

    func refreshSavedKeys() {
        var found = Set<String>()
        for service in ServiceIdentifier.allCases {
            for cred in service.credentials {
                if keychain.exists(for: cred.id) {
                    found.insert(cred.id)
                }
            }
        }
        for custom in customServices {
            for cred in custom.credentials {
                if keychain.exists(for: cred.id) {
                    found.insert(cred.id)
                }
            }
        }
        savedKeys = found
    }

    func save(_ value: String, for definition: CredentialDefinition) -> Bool {
        // Validate
        if definition.required && value.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors[definition.id] = "This field is required"
            return false
        }
        if let hint = definition.validationHint {
            // Extract prefix check from hint
            let parts = hint.components(separatedBy: "\"")
            if parts.count >= 2 {
                let prefix = parts[1]
                if !value.hasPrefix(prefix) {
                    validationErrors[definition.id] = hint
                    return false
                }
            }
        }
        validationErrors.removeValue(forKey: definition.id)

        do {
            try keychain.save(value.trimmingCharacters(in: .whitespaces), for: definition.id)
            savedKeys.insert(definition.id)
            return true
        } catch {
            validationErrors[definition.id] = error.localizedDescription
            return false
        }
    }

    func delete(for definition: CredentialDefinition) {
        try? keychain.delete(for: definition.id)
        savedKeys.remove(definition.id)
    }

    func masked(for definition: CredentialDefinition) -> String {
        keychain.maskedValue(for: definition.id)
    }

    func isSaved(_ definition: CredentialDefinition) -> Bool {
        savedKeys.contains(definition.id)
    }

    // MARK: Quick accessors for backend

    var anthropicAPIKey: String? { try? keychain.read(for: "anthropic.api_key") }
    var geminiAPIKey: String?    { try? keychain.read(for: "gemini.api_key") }
    var backendURL: String?      { try? keychain.read(for: "gutsense.backend_url") }
    var backendSecret: String?   { try? keychain.read(for: "gutsense.api_secret") }

    var isReadyForAnalysis: Bool {
        anthropicAPIKey != nil && geminiAPIKey != nil && backendURL != nil
    }

    // MARK: Custom Services

    func addCustomService(_ service: CustomServiceDefinition) {
        customServices.append(service)
        saveCustomServices()
    }

    func removeCustomService(id: String) {
        if let service = customServices.first(where: { $0.id == id }) {
            for cred in service.credentials {
                try? keychain.delete(for: cred.id)
                savedKeys.remove(cred.id)
            }
        }
        customServices.removeAll { $0.id == id }
        saveCustomServices()
    }

    private func saveCustomServices() {
        let data = try? JSONEncoder().encode(customServices)
        UserDefaults.standard.set(data, forKey: "gutsense.custom_services")
    }

    private func loadCustomServices() {
        guard let data = UserDefaults.standard.data(forKey: "gutsense.custom_services"),
              let services = try? JSONDecoder().decode([CustomServiceDefinition].self, from: data) else {
            return
        }
        customServices = services
    }
}

// MARK: - Custom Service Definition

struct CustomServiceDefinition: Identifiable, Codable {
    let id: String
    var name: String
    var urlString: String
    var hasAPIKey: Bool
    var hasLogin: Bool

    var credentials: [CredentialDefinition] {
        var defs: [CredentialDefinition] = []
        if !urlString.isEmpty {
            defs.append(CredentialDefinition(
                id: "\(id).url", service: .custom,
                label: "URL", placeholder: "https://…",
                isPassword: false,
                helpText: "Service endpoint URL",
                required: false, validationHint: nil
            ))
        }
        if hasAPIKey {
            defs.append(CredentialDefinition(
                id: "\(id).api_key", service: .custom,
                label: "API Key", placeholder: "Your API key",
                isPassword: true,
                helpText: "API key for \(name)",
                required: false, validationHint: nil
            ))
        }
        if hasLogin {
            defs.append(CredentialDefinition(
                id: "\(id).email", service: .custom,
                label: "Email / Username", placeholder: "you@example.com",
                isPassword: false,
                helpText: "Login email for \(name)",
                required: false, validationHint: nil
            ))
            defs.append(CredentialDefinition(
                id: "\(id).password", service: .custom,
                label: "Password", placeholder: "••••••••",
                isPassword: true,
                helpText: "Password for \(name)",
                required: false, validationHint: nil
            ))
        }
        return defs
    }
}
