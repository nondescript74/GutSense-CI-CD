//
//  IBSProfileView.swift
//  GutSense
//
//  IBS Profile & Sensitivity Onboarding
//  Quick-select FODMAP, Wheat, Gluten, Nuts sensitivities
//  + on-device AI agent for deeper profiling via Apple Foundation Models
//

import SwiftUI
import SwiftData
import FoundationModels
import Combine

// MARK: - Sensitivity Category

/// Broad dietary sensitivity categories the user can toggle quickly.
enum SensitivityCategory: String, CaseIterable, Identifiable, Codable {
    case fodmap  = "FODMAP"
    case wheat   = "Wheat"
    case gluten  = "Gluten"
    case nuts    = "Nuts"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .fodmap: return "leaf.fill"
        case .wheat:  return "leaf.arrow.circlepath"
        case .gluten: return "xmark.seal.fill"
        case .nuts:   return "allergens.fill"
        }
    }

    var color: Color {
        switch self {
        case .fodmap: return .orange
        case .wheat:  return .brown
        case .gluten: return .purple
        case .nuts:   return .red
        }
    }

    var subtitle: String {
        switch self {
        case .fodmap: return "Fermentable carbohydrates"
        case .wheat:  return "Wheat-based products"
        case .gluten: return "Gluten-containing grains"
        case .nuts:   return "Tree nuts & peanuts"
        }
    }
}

// MARK: - Chat Message

/// A single message in the AI profiling conversation.
struct ProfileChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date

    enum Role: String, Codable {
        case user
        case assistant
    }

    init(role: Role, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

// MARK: - Profile Agent (On-Device)

/// Uses Apple Foundation Models to run a conversational IBS profiling agent entirely on-device.
/// All intelligence stays private — nothing leaves the device.
@MainActor
final class ProfileAgent: ObservableObject {

    @Published var messages: [ProfileChatMessage] = []
    @Published var isResponding: Bool = false
    @Published var isAvailable: Bool = false
    @Published var unavailableReason: String = ""

    /// Extracted insights from the conversation, persisted to SwiftData.
    @Published var extractedTriggerFoods: [String] = []
    @Published var extractedSafeFoods: [String] = []
    @Published var extractedMedications: [String] = []
    @Published var extractedConditions: [String] = []
    @Published var extractedNotes: String = ""

    private let model = SystemLanguageModel.default
    private var session: LanguageModelSession?

    init() {
        Task { await checkAvailability() }
    }

    func checkAvailability() async {
        switch model.availability {
        case .available:
            isAvailable = true
            session = LanguageModelSession(
                model: model,
                instructions: Self.systemInstructions
            )
        case .unavailable(.appleIntelligenceNotEnabled):
            isAvailable = false
            unavailableReason = "Enable Apple Intelligence in Settings → Apple Intelligence & Siri."
        case .unavailable(.deviceNotEligible):
            isAvailable = false
            unavailableReason = "Requires iPhone 15 Pro, iPhone 16, or M-series iPad."
        default:
            isAvailable = false
            unavailableReason = "Apple Intelligence is not ready. It may still be downloading."
        }
    }

    /// Send a user message and get an AI response.
    func send(_ text: String) async {
        let userMessage = ProfileChatMessage(role: .user, content: text)
        messages.append(userMessage)
        isResponding = true

        defer { isResponding = false }

        guard isAvailable, let session else {
            messages.append(ProfileChatMessage(
                role: .assistant,
                content: "I'm sorry — Apple Intelligence isn't available on this device right now. You can still use the quick selectors above to configure your profile."
            ))
            return
        }

        do {
            let response = try await session.respond(to: text)
            let reply = response.content

            messages.append(ProfileChatMessage(role: .assistant, content: reply))

            // Parse structured insights from the response if present
            await extractInsights(from: reply)
        } catch {
            messages.append(ProfileChatMessage(
                role: .assistant,
                content: "I had trouble processing that. Could you rephrase? (\(error.localizedDescription))"
            ))
        }
    }

    /// Start the conversation with a contextual greeting.
    func startConversation(profile: UserProfileRecord) async {
        guard messages.isEmpty else { return }

        let context = buildContextSummary(profile: profile)
        let greeting = """
        Based on your current profile, I can see you have \(context). \
        I'd like to learn more about your IBS experience so I can better tailor food analyses for you. \
        \n\nHere are some things I can help with:\n\
        • Identifying specific trigger foods beyond FODMAP categories\n\
        • Understanding your symptom patterns (timing, severity)\n\
        • Reviewing medications that might affect digestion\n\
        • Noting safe foods you've confirmed work for you\n\n\
        What would you like to start with?
        """

        messages.append(ProfileChatMessage(role: .assistant, content: greeting))
    }

    // MARK: - Private Helpers

    private func buildContextSummary(profile: UserProfileRecord) -> String {
        var parts: [String] = []
        parts.append(profile.ibsSubtype)
        parts.append("in the \(profile.fodmapPhase) phase")
        if !profile.sensitivities.isEmpty {
            let sens = profile.sensitivities.joined(separator: ", ")
            parts.append("sensitivities to \(sens)")
        }
        if !profile.knownTriggers.isEmpty {
            let triggers = profile.knownTriggers.joined(separator: ", ")
            parts.append("known FODMAP triggers: \(triggers)")
        }
        return parts.joined(separator: ", ")
    }

    /// Attempt to extract structured data from assistant messages.
    private func extractInsights(from text: String) async {
        let lower = text.lowercased()

        // Simple heuristic extraction — the AI is instructed to use markers
        if lower.contains("[trigger:") {
            let extracted = parseMarkers(in: text, marker: "trigger")
            for item in extracted where !extractedTriggerFoods.contains(item) {
                extractedTriggerFoods.append(item)
            }
        }
        if lower.contains("[safe:") {
            let extracted = parseMarkers(in: text, marker: "safe")
            for item in extracted where !extractedSafeFoods.contains(item) {
                extractedSafeFoods.append(item)
            }
        }
        if lower.contains("[medication:") {
            let extracted = parseMarkers(in: text, marker: "medication")
            for item in extracted where !extractedMedications.contains(item) {
                extractedMedications.append(item)
            }
        }
        if lower.contains("[condition:") {
            let extracted = parseMarkers(in: text, marker: "condition")
            for item in extracted where !extractedConditions.contains(item) {
                extractedConditions.append(item)
            }
        }
        if lower.contains("[note:") {
            let notes = parseMarkers(in: text, marker: "note")
            if let note = notes.first {
                if !extractedNotes.isEmpty { extractedNotes += "\n" }
                extractedNotes += note
            }
        }
    }

    private func parseMarkers(in text: String, marker: String) -> [String] {
        // Pattern: [marker: value]
        var results: [String] = []
        let pattern = "[\(marker):"
        var searchRange = text.startIndex..<text.endIndex

        while let start = text.range(of: pattern, options: .caseInsensitive, range: searchRange) {
            let valueStart = start.upperBound
            if let end = text.range(of: "]", range: valueStart..<text.endIndex) {
                let value = text[valueStart..<end.lowerBound]
                    .trimmingCharacters(in: .whitespaces)
                if !value.isEmpty {
                    results.append(value)
                }
                searchRange = end.upperBound..<text.endIndex
            } else {
                break
            }
        }
        return results
    }

    // MARK: - System Instructions

    private static let systemInstructions = """
    You are a compassionate IBS dietary profiling assistant inside the GutSense app. \
    Your goal is to learn about the user's IBS experience through friendly conversation \
    and extract structured insights that will improve their food analysis results.

    RULES:
    1. You are NOT a doctor. Never diagnose conditions or recommend stopping medications.
    2. Always remind the user this is not medical advice if they ask clinical questions.
    3. Be warm, concise, and encouraging.
    4. Focus on: trigger foods, safe foods, symptom timing, medication effects, IBS subtype details.
    5. When you identify a specific insight, include a structured marker in your response:
       - [trigger: food name] for trigger foods
       - [safe: food name] for confirmed safe foods
       - [medication: medication name] for relevant medications
       - [condition: condition name] for diagnosed conditions
       - [note: brief insight] for general observations
    6. Keep responses under 150 words.
    7. Ask one focused question at a time.
    8. After 3-4 exchanges, offer to summarize what you've learned.

    CONTEXT: The user has IBS and is using this app to analyze foods for FODMAP content \
    and IBS trigger risk using multiple AI agents. Your insights will personalize their analyses.
    """
}

// MARK: - IBS Profile View

struct IBSProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfileRecord]
    @StateObject private var agent = ProfileAgent()

    @State private var chatText: String = ""
    @State private var showChat: Bool = false
    @State private var showSaveConfirmation: Bool = false

    private var profile: UserProfileRecord {
        if let existing = profiles.first {
            return existing
        }
        let newProfile = UserProfileRecord()
        modelContext.insert(newProfile)
        try? modelContext.save()
        return newProfile
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            List {
                // MARK: - IBS Subtype
                Section {
                    Picker("IBS Subtype", selection: Binding(
                        get: { profile.ibsSubtype },
                        set: { newValue in
                            profile.ibsSubtype = newValue
                            saveProfile()
                        }
                    )) {
                        ForEach(IBSSubtype.allCases) { subtype in
                            Text(subtype.rawValue).tag(subtype.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Label("IBS Subtype", systemImage: "heart.text.clipboard")
                } footer: {
                    Text("Your IBS subtype affects how agents assess trigger risk.")
                }

                // MARK: - FODMAP Phase
                Section {
                    Picker("Phase", selection: Binding(
                        get: { profile.fodmapPhase },
                        set: { newValue in
                            profile.fodmapPhase = newValue
                            saveProfile()
                        }
                    )) {
                        ForEach(FODMAPPhase.allCases) { phase in
                            Text(phase.rawValue).tag(phase.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Label("FODMAP Phase", systemImage: "chart.line.uptrend.xyaxis")
                } footer: {
                    Text("Elimination is strict avoidance. Reintroduction tests one group at a time. Maintenance is your long-term baseline.")
                }

                // MARK: - Quick Sensitivity Selectors
                Section {
                    ForEach(SensitivityCategory.allCases) { category in
                        SensitivityToggleRow(
                            category: category,
                            isOn: Binding(
                                get: { profile.sensitivities.contains(category.rawValue) },
                                set: { enabled in
                                    if enabled {
                                        if !profile.sensitivities.contains(category.rawValue) {
                                            profile.sensitivities.append(category.rawValue)
                                        }
                                    } else {
                                        profile.sensitivities.removeAll { $0 == category.rawValue }
                                    }
                                    saveProfile()
                                }
                            )
                        )
                    }
                } header: {
                    Label("Sensitivities", systemImage: "exclamationmark.triangle.fill")
                } footer: {
                    Text("Toggle categories that affect you. These are sent to all agents to personalize risk assessment.")
                }

                // MARK: - FODMAP Triggers
                Section {
                    ForEach(FODMAPCategory.allCases) { category in
                        FODMAPTriggerRow(
                            category: category,
                            isOn: Binding(
                                get: { profile.knownTriggers.contains(category.rawValue) },
                                set: { enabled in
                                    if enabled {
                                        if !profile.knownTriggers.contains(category.rawValue) {
                                            profile.knownTriggers.append(category.rawValue)
                                        }
                                    } else {
                                        profile.knownTriggers.removeAll { $0 == category.rawValue }
                                    }
                                    saveProfile()
                                }
                            )
                        )
                    }
                } header: {
                    Label("Known FODMAP Triggers", systemImage: "flame.fill")
                } footer: {
                    Text("Select FODMAP subgroups you know trigger symptoms.")
                }

                // MARK: - AI-Extracted Insights
                if !agent.extractedTriggerFoods.isEmpty || !agent.extractedSafeFoods.isEmpty ||
                   !agent.extractedMedications.isEmpty || !agent.extractedNotes.isEmpty {
                    Section {
                        if !agent.extractedTriggerFoods.isEmpty {
                            InsightRow(
                                icon: "flame.fill",
                                color: .red,
                                label: "Trigger Foods",
                                items: agent.extractedTriggerFoods
                            )
                        }
                        if !agent.extractedSafeFoods.isEmpty {
                            InsightRow(
                                icon: "checkmark.circle.fill",
                                color: .green,
                                label: "Safe Foods",
                                items: agent.extractedSafeFoods
                            )
                        }
                        if !agent.extractedMedications.isEmpty {
                            InsightRow(
                                icon: "pills.fill",
                                color: .blue,
                                label: "Medications",
                                items: agent.extractedMedications
                            )
                        }
                        if !agent.extractedConditions.isEmpty {
                            InsightRow(
                                icon: "stethoscope",
                                color: .purple,
                                label: "Conditions",
                                items: agent.extractedConditions
                            )
                        }
                        if !agent.extractedNotes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Notes", systemImage: "note.text")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                                Text(agent.extractedNotes)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }

                        Button {
                            applyExtractedInsights()
                        } label: {
                            Label("Save AI Insights to Profile", systemImage: "square.and.arrow.down.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                    } header: {
                        Label("AI-Discovered Insights", systemImage: "brain")
                    } footer: {
                        Text("These insights were extracted from your conversation. Save them to personalize all future analyses.")
                    }
                }

                // MARK: - Saved Profile Data
                if !profile.knownSafeFoods.isEmpty || !profile.medications.isEmpty || !profile.diagnosedConditions.isEmpty {
                    Section {
                        if !profile.knownSafeFoods.isEmpty {
                            InsightRow(icon: "checkmark.circle.fill", color: .green,
                                       label: "Safe Foods", items: profile.knownSafeFoods)
                        }
                        if !profile.medications.isEmpty {
                            InsightRow(icon: "pills.fill", color: .blue,
                                       label: "Medications", items: profile.medications)
                        }
                        if !profile.diagnosedConditions.isEmpty {
                            InsightRow(icon: "stethoscope", color: .purple,
                                       label: "Conditions", items: profile.diagnosedConditions)
                        }
                    } header: {
                        Label("Saved Profile Data", systemImage: "person.text.rectangle")
                    }
                }

                // MARK: - AI Chat Section
                Section {
                    if !showChat {
                        Button {
                            withAnimation(.spring(response: 0.4)) {
                                showChat = true
                            }
                            Task { await agent.startConversation(profile: profile) }
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(agent.isAvailable ? Color.accentColor.opacity(0.12) : Color.orange.opacity(0.12))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: agent.isAvailable ? "brain" : "brain")
                                        .font(.title3)
                                        .foregroundColor(agent.isAvailable ? .accentColor : .orange)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Tell me more about your IBS")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.primary)
                                    Text(agent.isAvailable
                                         ? "On-device AI · Private · No data leaves your device"
                                         : agent.unavailableReason)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption.weight(.semibold))
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Chat messages
                        ForEach(agent.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }

                        if agent.isResponding {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Thinking on-device…")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }

                        // Input bar
                        HStack(spacing: 8) {
                            TextField("Ask about your IBS…", text: $chatText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(1...4)
                                .padding(10)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            Button {
                                let text = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !text.isEmpty else { return }
                                chatText = ""
                                Task {
                                    await agent.send(text)
                                    // Scroll to latest
                                    if let last = agent.messages.last {
                                        withAnimation {
                                            scrollProxy.scrollTo(last.id, anchor: .bottom)
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(
                                        chatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? .gray : .accentColor
                                    )
                            }
                            .disabled(chatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || agent.isResponding)
                        }
                        .id("chatInput")
                    }
                } header: {
                    Label("AI Profiling Agent", systemImage: "apple.intelligence")
                } footer: {
                    if showChat {
                        Text("Powered by Apple Intelligence · Runs entirely on-device · Your conversation is never uploaded")
                    } else {
                        Text("Chat with an on-device AI to discover deeper insights about your IBS triggers and safe foods.")
                    }
                }

                // MARK: - Medical Disclaimer
                Section {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "cross.case.fill")
                            .foregroundColor(.blue)
                            .font(.subheadline)
                        Text("This app is not a substitute for medical advice. Always consult your gastroenterologist before making dietary changes.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("IBS Profile")
            .navigationBarTitleDisplayMode(.large)
            .alert("Insights Saved", isPresented: $showSaveConfirmation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your AI-discovered insights have been saved to your profile and will personalize all future food analyses.")
            }
            .onChange(of: agent.messages.count) { _, _ in
                if let last = agent.messages.last {
                    withAnimation {
                        scrollProxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func saveProfile() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save profile: \(error)")
        }
    }

    private func applyExtractedInsights() {
        // Merge trigger foods into known safe foods / triggers
        for food in agent.extractedSafeFoods where !profile.knownSafeFoods.contains(food) {
            profile.knownSafeFoods.append(food)
        }
        for med in agent.extractedMedications where !profile.medications.contains(med) {
            profile.medications.append(med)
        }
        for condition in agent.extractedConditions where !profile.diagnosedConditions.contains(condition) {
            profile.diagnosedConditions.append(condition)
        }
        if !agent.extractedNotes.isEmpty {
            profile.aiNotes = (profile.aiNotes.isEmpty ? "" : profile.aiNotes + "\n") + agent.extractedNotes
        }

        // Save the conversation transcript
        if let data = try? JSONEncoder().encode(agent.messages) {
            profile.chatTranscriptJSON = String(data: data, encoding: .utf8) ?? ""
        }

        saveProfile()
        showSaveConfirmation = true
    }
}

// MARK: - Sensitivity Toggle Row

private struct SensitivityToggleRow: View {
    let category: SensitivityCategory
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(category.color.opacity(isOn ? 0.15 : 0.06))
                        .frame(width: 36, height: 36)
                    Image(systemName: category.icon)
                        .font(.subheadline)
                        .foregroundColor(isOn ? category.color : .gray)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.rawValue)
                        .font(.subheadline.weight(.semibold))
                    Text(category.subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .tint(category.color)
    }
}

// MARK: - FODMAP Trigger Row

private struct FODMAPTriggerRow: View {
    let category: FODMAPCategory
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(category.rawValue)
                .font(.subheadline)
        }
        .tint(.orange)
    }
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: ProfileChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.subheadline)
                    .padding(12)
                    .background(
                        message.role == .user
                        ? Color.accentColor.opacity(0.12)
                        : Color(.secondarySystemBackground)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.role == .assistant { Spacer(minLength: 40) }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Insight Row

private struct InsightRow: View {
    let icon: String
    let color: Color
    let label: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(color)

            FlowLayout(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(color.opacity(0.10))
                        .foregroundColor(color)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Flow Layout

/// A simple horizontal wrapping layout for tag chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        IBSProfileView()
    }
    .modelContainer(for: [UserProfileRecord.self], inMemory: true)
}
