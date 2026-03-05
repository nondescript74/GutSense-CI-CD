// GutSense — APIKeysView.swift
// Secure credential vault UI — API keys, logins, custom services
// Reads/writes exclusively to iOS Keychain via KeychainService

import SwiftUI
import UIKit

// MARK: - Colour palette helpers

extension Color {
    static let gutGreen  = Color(red: 0.20, green: 0.78, blue: 0.45)
    static let gutAmber  = Color(red: 0.95, green: 0.65, blue: 0.10)
    static let gutRed    = Color(red: 0.88, green: 0.25, blue: 0.25)

    static func hex(_ hex: String) -> Color {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        return Color(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}

// MARK: - Readiness Banner

struct ReadinessBanner: View {
    @ObservedObject var store: CredentialsStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: store.isReadyForAnalysis ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.title2)
                .foregroundColor(store.isReadyForAnalysis ? .gutGreen : .gutAmber)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.isReadyForAnalysis ? "Ready for Analysis" : "Setup Incomplete")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(store.isReadyForAnalysis ? .gutGreen : .gutAmber)

                Text(store.isReadyForAnalysis
                     ? "Claude, Gemini, and Backend are configured."
                     : "Anthropic key, Gemini key, and Backend URL required.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(store.isReadyForAnalysis
                      ? Color.gutGreen.opacity(0.10)
                      : Color.gutAmber.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(store.isReadyForAnalysis
                                ? Color.gutGreen.opacity(0.35)
                                : Color.gutAmber.opacity(0.35))
                )
        )
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Credential Field Row

struct CredentialFieldRow: View {
    let definition: CredentialDefinition
    @ObservedObject var store: CredentialsStore

    @State private var fieldValue: String = ""
    @State private var isEditing: Bool = false
    @State private var isRevealed: Bool = true  // Default to revealed for easier pasting
    @State private var saveSuccess: Bool = false
    @State private var isValidating: Bool = false
    @State private var validationResult: ValidationResult? = nil
    @State private var justPasted: Bool = false
    @FocusState private var fieldFocused: Bool
    
    enum ValidationResult {
        case success(String)
        case failure(String)
        
        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }

    private var serviceColor: Color {
        Color.hex(definition.service.tintColor)
    }
    
    private func canValidate(_ def: CredentialDefinition) -> Bool {
        // Only validate backend URL for now
        def.id == "gutsense.backend_url"
    }
    
    private func validateCredential(_ def: CredentialDefinition) {
        guard let value = try? KeychainService.shared.read(for: def.id) else {
            validationResult = .failure("Could not read credential")
            return
        }
        
        isValidating = true
        validationResult = nil
        
        Task {
            if def.id == "gutsense.backend_url" {
                // Test backend health endpoint
                let success = await BackendAPIService.shared.healthCheck()
                await MainActor.run {
                    isValidating = false
                    if success {
                        validationResult = .success("Backend reachable ✓")
                    } else {
                        validationResult = .failure("Backend unreachable - check URL")
                    }
                }
            } else {
                // Basic format validation for API keys
                await MainActor.run {
                    isValidating = false
                    if def.id == "anthropic.api_key" {
                        validationResult = value.hasPrefix("sk-ant-") ? 
                            .success("Format valid ✓") : 
                            .failure("Should start with sk-ant-")
                    } else if def.id == "gemini.api_key" {
                        validationResult = value.hasPrefix("AIza") ? 
                            .success("Format valid ✓") : 
                            .failure("Should start with AIza")
                    }
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            // Label row
            HStack {
                Label(definition.label, systemImage: definition.isPassword ? "lock.fill" : "link")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(serviceColor)

                if definition.required {
                    Text("Required")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gutRed.opacity(0.12))
                        .foregroundColor(.gutRed)
                        .clipShape(Capsule())
                }

                Spacer()

                // Status pill
                if store.isSaved(definition) && !isEditing {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.gutGreen)
                            .font(.caption)
                        Text("Saved")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.gutGreen)
                    }
                }
            }

            // Input or masked display
            if isEditing {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Group {
                            if definition.isPassword && !isRevealed {
                                SecureField(definition.placeholder, text: $fieldValue)
                                    .focused($fieldFocused)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            } else {
                                TextField(definition.placeholder, text: $fieldValue)
                                    .focused($fieldFocused)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(definition.isPassword ? .asciiCapable : .URL)
                            }
                        }
                        .font(.subheadline.monospaced())
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(store.validationErrors[definition.id] != nil
                                        ? Color.gutRed : serviceColor.opacity(0.4))
                        )

                        // Paste button
                        Button {
                            let clipboardString = UIPasteboard.general.string ?? ""
                            print("📋 Clipboard content: '\(clipboardString)'")
                            if !clipboardString.isEmpty {
                                fieldValue = clipboardString
                                print("✅ Set fieldValue to: '\(fieldValue)'")
                                justPasted = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    justPasted = false
                                }
                            } else {
                                print("❌ Clipboard is empty")
                            }
                        } label: {
                            Image(systemName: justPasted ? "checkmark.circle.fill" : "doc.on.clipboard.fill")
                                .foregroundColor(justPasted ? .gutGreen : .blue)
                                .frame(width: 32, height: 32)
                        }
                        
                        // Reveal toggle for passwords
                        if definition.isPassword {
                            Button {
                                isRevealed.toggle()
                            } label: {
                                Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.secondary)
                                    .frame(width: 32, height: 32)
                            }
                        }

                        // Save button
                        Button {
                            let ok = store.save(fieldValue, for: definition)
                            if ok {
                                withAnimation { saveSuccess = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    withAnimation {
                                        saveSuccess = false
                                        isEditing = false
                                        fieldValue = ""
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: saveSuccess ? "checkmark.circle.fill" : "square.and.arrow.down.fill")
                                .foregroundColor(saveSuccess ? .gutGreen : serviceColor)
                                .font(.title3)
                                .frame(width: 36, height: 36)
                        }

                        // Cancel
                        Button {
                            withAnimation {
                                isEditing = false
                                fieldValue = ""
                                store.validationErrors.removeValue(forKey: definition.id)
                                validationResult = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.title3)
                                .frame(width: 36, height: 36)
                        }
                    }
                    
                    // Paste hint
                    if fieldValue.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.caption2)
                            Text("Simulator: Enable Edit → Automatically Sync Pasteboard")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.gutGreen)
                            Text("\(fieldValue.count) characters")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Validation error
                if let err = store.validationErrors[definition.id] {
                    Label(err, systemImage: "exclamationmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.gutRed)
                }

            } else {
                // Masked display + edit/delete/validate controls
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text(store.isSaved(definition)
                             ? store.masked(for: definition)
                             : "Not configured")
                            .font(.subheadline.monospaced())
                            .foregroundColor(store.isSaved(definition) ? .primary : .secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            // Pre-fill with empty (never expose real value)
                            fieldValue = ""
                            isEditing = true
                            // Delay focus to allow keyboard animation to complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                fieldFocused = true
                            }
                        } label: {
                            Image(systemName: store.isSaved(definition) ? "pencil.circle.fill" : "plus.circle.fill")
                                .foregroundColor(serviceColor)
                                .font(.title3)
                                .frame(width: 36, height: 36)
                        }
                        
                        if store.isSaved(definition) && canValidate(definition) {
                            Button {
                                validateCredential(definition)
                            } label: {
                                if isValidating {
                                    ProgressView()
                                        .frame(width: 36, height: 36)
                                } else {
                                    Image(systemName: "checkmark.shield.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                        .frame(width: 36, height: 36)
                                }
                            }
                            .disabled(isValidating)
                        }

                        if store.isSaved(definition) {
                            Button(role: .destructive) {
                                withAnimation { 
                                    store.delete(for: definition)
                                    validationResult = nil
                                }
                            } label: {
                                Image(systemName: "trash.circle.fill")
                                    .foregroundColor(.gutRed.opacity(0.8))
                                    .font(.title3)
                                    .frame(width: 36, height: 36)
                            }
                        }
                    }
                    
                    // Validation result
                    if let result = validationResult {
                        HStack(spacing: 6) {
                            switch result {
                            case .success(let message):
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.gutGreen)
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.gutGreen)
                            case .failure(let message):
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.gutAmber)
                                Text(message)
                                    .font(.caption)
                                    .foregroundColor(.gutAmber)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(result.isSuccess ? Color.gutGreen.opacity(0.1) : Color.gutAmber.opacity(0.1))
                        )
                    }
                }
            }

            // Help text
            Text(definition.helpText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Service Section

struct ServiceSection: View {
    let service: ServiceIdentifier
    let credentials: [CredentialDefinition]
    @ObservedObject var store: CredentialsStore
    @State private var isExpanded: Bool = true

    private var serviceColor: Color { Color.hex(service.tintColor) }

    private var savedCount: Int {
        credentials.filter { store.isSaved($0) }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            Button {
                withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(serviceColor.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: service.iconName)
                            .foregroundColor(serviceColor)
                            .font(.subheadline.weight(.semibold))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(service.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Text("\(savedCount)/\(credentials.count) configured")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Completion dots
                    HStack(spacing: 4) {
                        ForEach(credentials) { cred in
                            Circle()
                                .fill(store.isSaved(cred) ? serviceColor : Color.gray.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal, 14)

                VStack(spacing: 12) {
                    ForEach(credentials) { cred in
                        CredentialFieldRow(definition: cred, store: store)
                    }
                }
                .padding(14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    savedCount == credentials.count
                        ? serviceColor.opacity(0.3)
                        : Color.gray.opacity(0.15),
                    lineWidth: savedCount == credentials.count ? 1.5 : 1
                )
        )
    }
}

// MARK: - Add Custom Service Sheet

struct AddCustomServiceSheet: View {
    @ObservedObject var store: CredentialsStore
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var url: String = ""
    @State private var hasAPIKey: Bool = true
    @State private var hasLogin: Bool = false
    @State private var nameError: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Service Info") {
                    TextField("Service name (e.g. OpenFoodFacts)", text: $name)
                        .autocorrectionDisabled()
                    if let err = nameError {
                        Label(err, systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundColor(.gutRed)
                    }
                    TextField("Base URL (optional)", text: $url)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }

                Section("Credential Types") {
                    Toggle("Has API Key", isOn: $hasAPIKey)
                    Toggle("Has Login / Password", isOn: $hasLogin)
                }

                Section {
                    Text("Credentials will be stored securely in iOS Keychain — never in plain text or iCloud.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Custom Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
                            nameError = "Service name is required"
                            return
                        }
                        let def = CustomServiceDefinition(
                            id: UUID().uuidString,
                            name: name.trimmingCharacters(in: .whitespaces),
                            urlString: url,
                            hasAPIKey: hasAPIKey,
                            hasLogin: hasLogin
                        )
                        store.addCustomService(def)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Custom Service Section

struct CustomServiceSection: View {
    let service: CustomServiceDefinition
    @ObservedObject var store: CredentialsStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "key.fill")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                }

                Text(service.name)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button(role: .destructive) {
                    withAnimation { store.removeCustomService(id: service.id) }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.gutRed.opacity(0.7))
                }
            }
            .padding(14)

            if !service.credentials.isEmpty {
                Divider().padding(.horizontal, 14)
                VStack(spacing: 12) {
                    ForEach(service.credentials) { cred in
                        CredentialFieldRow(definition: cred, store: store)
                    }
                }
                .padding(14)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.15))
        )
    }
}

// MARK: - Main API Keys View

struct APIKeysView: View {
    @StateObject private var store = CredentialsStore.shared
    @State private var showAddCustom = false
    @State private var showSecurityInfo = false

    private let coreServices: [ServiceIdentifier] = [.anthropic, .gemini, .gutsenseAPI, .monash]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Readiness banner
                    ReadinessBanner(store: store)

                    // Security note
                    Button {
                        showSecurityInfo.toggle()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.blue)
                            Text("All credentials stored in iOS Keychain — never synced to iCloud or transmitted.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)

                    // Core service sections
                    VStack(spacing: 12) {
                        ForEach(coreServices, id: \.self) { service in
                            ServiceSection(
                                service: service,
                                credentials: service.credentials,
                                store: store
                            )
                        }
                    }
                    .padding(.horizontal)

                    // Custom services
                    if !store.customServices.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Custom Services", systemImage: "plus.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            ForEach(store.customServices) { custom in
                                CustomServiceSection(service: custom, store: store)
                                    .padding(.horizontal)
                            }
                        }
                    }

                    // Add custom service button
                    Button {
                        showAddCustom = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Custom Service")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2))
                        )
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .padding(.top, 8)
            }
            .navigationTitle("API Keys & Credentials")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.refreshSavedKeys()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showAddCustom) {
                AddCustomServiceSheet(store: store)
            }
            .sheet(isPresented: $showSecurityInfo) {
                SecurityInfoSheet()
            }
        }
    }
}

// MARK: - Security Info Sheet

struct SecurityInfoSheet: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("How credentials are stored") {
                    Label("iOS Keychain with kSecAttrAccessibleWhenUnlockedThisDeviceOnly — credentials cannot leave this device.", systemImage: "lock.fill")
                    Label("Keys are never stored in SwiftData, UserDefaults, or iCloud.", systemImage: "icloud.slash.fill")
                    Label("Keys are never logged, printed, or included in crash reports.", systemImage: "eye.slash.fill")
                    Label("Masked previews show only the first 6 characters — the full value is never displayed.", systemImage: "asterisk")
                }

                Section("Network usage") {
                    Label("Anthropic and Gemini API keys are sent only to their respective endpoints over HTTPS.", systemImage: "network.badge.shield.half.filled")
                    Label("Your GutSense backend secret is sent only to your configured backend URL.", systemImage: "server.rack")
                    Label("Apple Foundation Model runs entirely on-device — no keys required.", systemImage: "applelogo")
                }

                Section("Deletion") {
                    Label("Tapping the trash icon permanently removes the credential from Keychain.", systemImage: "trash.fill")
                    Label("Deleting the app removes all Keychain entries associated with GutSense.", systemImage: "xmark.app.fill")
                }
            }
            .navigationTitle("Credential Security")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("API Keys — Setup Incomplete") {
    APIKeysView()
}

#Preview("Credential Field — Saved State") {
    let store = CredentialsStore.shared
    let def = ServiceIdentifier.anthropic.credentials[0]
    return NavigationStack {
        List {
            CredentialFieldRow(definition: def, store: store)
        }
        .navigationTitle("Preview")
    }
}
