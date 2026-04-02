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

enum CredentialValidationResult: Equatable {
    case success(String)
    case failure(String)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

struct CredentialValidator {
    static func canValidate(_ definition: CredentialDefinition) -> Bool {
        if definition.id == "gutsense.backend_url" || definition.id == "openai.api_key" {
            return true
        }
        return definition.validationHint != nil
    }

    static func formatValidationResult(
        for definition: CredentialDefinition,
        value: String
    ) -> CredentialValidationResult? {
        guard let hint = definition.validationHint else { return nil }
        let marker = "Starts with "
        guard hint.hasPrefix(marker) else { return nil }
        let prefix = String(hint.dropFirst(marker.count))
        guard !prefix.isEmpty else { return nil }
        return value.hasPrefix(prefix)
            ? .success("Format valid")
            : .failure("Should start with \(prefix)")
    }
}

enum ServiceIdentifier: String, CaseIterable, Identifiable {
    case anthropic    = "Anthropic"
    case openai       = "OpenAI"
    case gemini       = "Google Gemini"
    case gutsenseAPI  = "GutSense Backend"
    case monash       = "Monash FODMAP"
    case custom       = "Custom"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .anthropic:   return "sparkles"
        case .openai:      return "o.circle.fill"
        case .gemini:      return "brain.head.profile"
        case .gutsenseAPI: return "server.rack"
        case .monash:      return "cross.case.fill"
        case .custom:      return "key.fill"
        }
    }

    var tintColor: String {  // Hex strings for cross-view use
        switch self {
        case .anthropic:   return "#C97B47"
        case .openai:      return "#10A37F"
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
        case .openai:
            return [
                CredentialDefinition(
                    id: "openai.api_key",
                    service: .openai,
                    label: "API Key",
                    placeholder: "sk-...",
                    isPassword: true,
                    helpText: "Found at platform.openai.com → API keys",
                    required: true,
                    validationHint: "Starts with sk-"
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

// MARK: - Primary Provider Enum

enum PrimaryProvider: String, CaseIterable, Identifiable, Codable {
    case anthropic
    case openai

    var id: String { rawValue }
    var label: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        }
    }
}

// MARK: - Keychain Service

final class KeychainService {
    static let shared = KeychainService()
    private let keychainServiceName = "com.gutsense.credentials"
    // Access group disabled - will be enabled after adding Keychain Sharing capability via Xcode UI
    private let keychainAccessGroup: String? = nil

    private init() {}

    // MARK: Save

    func save(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        var query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     keychainServiceName,
            kSecAttrAccount:     key,
            kSecValueData:       data,
            // Use AfterFirstUnlock (not ThisDeviceOnly) to persist across app reinstalls during development
            kSecAttrAccessible:  kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Add access group for sharing between main app and App Clip (if configured)
        #if !targetEnvironment(simulator)
        if let accessGroup = keychainAccessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }
        #endif

        // Try to delete existing first (upsert pattern)
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: Read

    func read(for key: String) throws -> String {
        var query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      keychainServiceName,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        
        // Add access group for sharing between main app and App Clip (if configured)
        #if !targetEnvironment(simulator)
        if let accessGroup = keychainAccessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }
        #endif

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
        var query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrService:  keychainServiceName,
            kSecAttrAccount:  key
        ]
        
        // Add access group for sharing between main app and App Clip (if configured)
        #if !targetEnvironment(simulator)
        if let accessGroup = keychainAccessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }
        #endif

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

    // OpenAI key validation state
    @Published var openAIKeyValid: Bool = false {
        didSet {
            UserDefaults.standard.set(openAIKeyValid, forKey: "openai.key.valid")
        }
    }

    @Published var primaryProvider: PrimaryProvider = .anthropic {
        didSet {
            UserDefaults.standard.set(primaryProvider.rawValue, forKey: "gutsense.primary_provider")
        }
    }

    private init() {
        refreshSavedKeys()
        loadCustomServices()
        openAIKeyValid = UserDefaults.standard.bool(forKey: "openai.key.valid")
        if let raw = UserDefaults.standard.string(forKey: "gutsense.primary_provider"),
           let provider = PrimaryProvider(rawValue: raw) {
            primaryProvider = provider
        }
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
            if definition.id == "openai.api_key" {
                // Require re-validation after key change
                openAIKeyValid = false
            }
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
        if definition.id == "openai.api_key" {
            openAIKeyValid = false
        }
    }

    func masked(for definition: CredentialDefinition) -> String {
        keychain.maskedValue(for: definition.id)
    }

    func isSaved(_ definition: CredentialDefinition) -> Bool {
        savedKeys.contains(definition.id)
    }

    // MARK: Quick accessors for backend

    var anthropicAPIKey: String? { 
        try? keychain.read(for: "anthropic.api_key") 
    }
    var openAIApiKey: String? {
        try? keychain.read(for: "openai.api_key")
    }
    var geminiAPIKey: String? { 
        try? keychain.read(for: "gemini.api_key") 
    }
    var backendURL: String? {
        get { try? keychain.read(for: "gutsense.backend_url") }
        set { 
            if let value = newValue {
                try? keychain.save(value, for: "gutsense.backend_url")
                savedKeys.insert("gutsense.backend_url")
            }
        }
    }
    var backendSecret: String? { 
        try? keychain.read(for: "gutsense.api_secret") 
    }

    var selectedPrimaryAPIKey: String? {
        primaryProvider == .anthropic ? anthropicAPIKey : openAIApiKey
    }

    var isReadyForAnalysis: Bool {
        switch primaryProvider {
        case .anthropic:
            return anthropicAPIKey != nil && geminiAPIKey != nil && backendURL != nil
        case .openai:
            return openAIApiKey != nil && openAIKeyValid && geminiAPIKey != nil && backendURL != nil
        }
    }
    
    // MARK: OpenAI Key Validation
    func validateOpenAIKey() async -> Bool {
        guard let key = openAIApiKey, let url = URL(string: "https://api.openai.com/v1/models") else {
            await MainActor.run { self.openAIKeyValid = false }
            return false
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 20
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let ok = (200...299).contains(code)
            await MainActor.run { self.openAIKeyValid = ok }
            return ok
        } catch {
            await MainActor.run { self.openAIKeyValid = false }
            return false
        }
    }
    
    // MARK: Development Helper - Save credentials directly
    
    func saveCredential(_ value: String, for key: String) throws {
        try keychain.save(value, for: key)
        savedKeys.insert(key)
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
