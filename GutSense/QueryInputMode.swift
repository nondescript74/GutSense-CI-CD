//
//  QueryInputMode.swift
//  GutSense
//
//  Created by Zahirudeen Premji on 3/5/26.
//


// GutSense — QueryViewModel.swift
// Orchestrates the 3-agent pipeline:
//   1. Apple Foundation Model (on-device) — fires immediately
//   2. Claude (backend) — fires in parallel with Apple
//   3. Gemini (backend) — fires after Apple + Claude both complete
// Each pane updates independently as results arrive.

import SwiftUI
import Combine
import PhotosUI
#if !os(visionOS)
import AVFoundation
#endif
import SwiftData

// MARK: - Query Input Mode

enum QueryInputMode: String, CaseIterable {
    case text    = "Text"
    case photo   = "Photo"
    case barcode = "Barcode"

    var icon: String {
        switch self {
        case .text:    return "text.bubble.fill"
        case .photo:   return "camera.fill"
        case .barcode: return "barcode.viewfinder"
        }
    }
}

// MARK: - Query State

enum QueryPhase {
    case idle
    case running
    case complete
    case failed(String)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}

// MARK: - Query View Model

@MainActor
final class QueryViewModel: ObservableObject {

    // MARK: Input state
    @Published var inputMode: QueryInputMode = .text
    @Published var textQuery: String = ""
    @Published var selectedPhoto: PhotosPickerItem? = nil
    @Published var capturedImage: UIImage? = nil
    @Published var barcodeValue: String? = nil
    @Published var barcodeDetected: Bool = false

    // MARK: Agent results — update independently as each arrives
    @Published var appleResult: AgentResult = .loading(for: .apple)
    @Published var claudeResult: AgentResult = .loading(for: .claude)
    @Published var geminiResult: SynthesisResult = .loading

    // MARK: Phase tracking
    @Published var phase: QueryPhase = .idle
    @Published var appleComplete = false
    @Published var claudeComplete = false
    @Published var geminiComplete = false

    // MARK: Error tracking per agent
    @Published var appleError: String? = nil
    @Published var claudeError: String? = nil
    @Published var geminiError: String? = nil

    // MARK: Navigation
    @Published var showResults = false

    // MARK: Dependencies
    private let appleService = AppleFoundationModelService.shared
    private let backendService = BackendAPIService.shared
    private let credentialsStore = CredentialsStore.shared

    // MARK: Current profile + sources (injected by parent)
    var userProfile: UserProfile = .default
    var userSources: [UserSource] = []
    
    // MARK: Serving size
    @Published var servingViewModel = ServingViewModel()
    
    // MARK: SwiftData context (injected by parent)
    var modelContext: ModelContext?

    // MARK: - Validation

    var canSubmit: Bool {
        guard !phase.isRunning else { return false }
        guard credentialsStore.isReadyForAnalysis else { return false }

        switch inputMode {
        case .text:    return !textQuery.trimmingCharacters(in: .whitespaces).isEmpty
        case .photo:   return capturedImage != nil
        case .barcode: return barcodeValue != nil
        }
    }

    var submitBlockReason: String? {
        if !credentialsStore.isReadyForAnalysis {
            return "Configure API keys in Settings first."
        }
        if phase.isRunning { return nil }
        switch inputMode {
        case .text:
            return textQuery.trimmingCharacters(in: .whitespaces).isEmpty
                ? "Enter a food or meal to analyze." : nil
        case .photo:
            return capturedImage == nil ? "Take or select a photo." : nil
        case .barcode:
            return barcodeValue == nil ? "Scan a barcode." : nil
        }
    }

    var resolvedQuery: String {
        switch inputMode {
        case .text:
            return textQuery
        case .photo:
            return "Analyze the food shown in this image for FODMAP content and IBS risk."
        case .barcode:
            return "Barcode: \(barcodeValue ?? "unknown"). Identify this food product and analyze for FODMAP content and IBS risk."
        }
    }

    // MARK: - Main Analysis Pipeline

    func analyze() async {
        guard canSubmit else { return }

        // Reset state
        phase = .running
        appleComplete = false
        claudeComplete = false
        geminiComplete = false
        appleError = nil
        claudeError = nil
        geminiError = nil

        appleResult = .loading(for: .apple)
        claudeResult = .loading(for: .claude)
        geminiResult = .loading

        showResults = true

        // Stage 1: Apple + Claude fire in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.runAppleAgent() }
            group.addTask { await self.runClaudeAgent() }
        }

        // Stage 2: Gemini synthesis — needs both results
        await runGeminiSynthesis()

        phase = .complete
        
        // Stage 3: Save to history
        saveToHistory()
    }

    // MARK: - Apple Agent

    private func runAppleAgent() async {
        do {
            let result = try await appleService.analyzeFODMAP(
                query: resolvedQuery,
                profile: userProfile,
                sources: userSources
            )
            appleResult = result
            appleComplete = true
        } catch {
            appleError = error.localizedDescription
            appleResult = AgentResult.error(for: .apple, message: error.localizedDescription)
            appleComplete = true
        }
    }

    // MARK: - Claude Agent

    private func runClaudeAgent() async {
        do {
            let result = try await backendService.analyzeClaude(
                query: resolvedQuery,
                profile: userProfile,
                sources: userSources,
                serving: servingViewModel
            )
            claudeResult = result
            claudeComplete = true
        } catch {
            claudeError = error.localizedDescription
            claudeResult = AgentResult.error(for: .claude, message: error.localizedDescription)
            claudeComplete = true
        }
    }

    // MARK: - Gemini Synthesis

    private func runGeminiSynthesis() async {
        // Encode Apple result as JSON for backend
        guard let appleJSON = encodeAppleResult() else {
            geminiError = "Could not encode Apple result for synthesis."
            geminiResult = SynthesisResult.error(message: "Apple result encoding failed.")
            geminiComplete = true
            return
        }

        do {
            let result = try await backendService.synthesizeGemini(
                query: resolvedQuery,
                profile: userProfile,
                sources: userSources,
                appleResultJSON: appleJSON,
                serving: servingViewModel
            )
            geminiResult = result
            geminiComplete = true
        } catch {
            geminiError = error.localizedDescription
            geminiResult = SynthesisResult.error(message: error.localizedDescription)
            geminiComplete = true
        }
    }

    // MARK: - Helpers

    private func encodeAppleResult() -> String? {
        // Encode current apple result to JSON string for Gemini endpoint
        struct AppleExport: Encodable {
            let agent_type: String
            let fodmap_tiers: [[String: String]]
            let ibs_trigger_probability: Double
            let confidence_tier: String
            let total_fructan_g: Double
            let total_gos_g: Double
        }

        let export = AppleExport(
            agent_type: "apple",
            fodmap_tiers: appleResult.fodmapTiers.map { item in
                var d: [String: String] = [
                    "ingredient": item.ingredient,
                    "tier": item.tier.rawValue.lowercased(),
                    "source": item.source
                ]
                if let f = item.fructanG { d["fructan_g"] = String(f) }
                if let g = item.gosG     { d["gos_g"] = String(g) }
                return d
            },
            ibs_trigger_probability: appleResult.ibsTriggerProbability,
            confidence_tier: appleResult.confidenceTier.rawValue,
            total_fructan_g: appleResult.totalFructanG,
            total_gos_g: appleResult.totalGOSG
        )

        guard let data = try? JSONEncoder().encode(export) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Save to History
    
    private func saveToHistory() {
        guard let context = modelContext else { return }
        
        let record = FoodQueryRecord(
            queryText: resolvedQuery,
            inputMode: inputMode.rawValue,
            servingInfo: servingViewModel.summaryLabel
        )
        
        record.saveResults(apple: appleResult, claude: claudeResult, gemini: geminiResult)
        
        context.insert(record)
        
        do {
            try context.save()
        } catch {
            print("Failed to save query to history: \(error)")
        }
    }
    
    // MARK: - Reset

    func reset() {
        textQuery = ""
        capturedImage = nil
        barcodeValue = nil
        barcodeDetected = false
        selectedPhoto = nil
        phase = .idle
        showResults = false
        appleResult = .loading(for: .apple)
        claudeResult = .loading(for: .claude)
        geminiResult = .loading
    }
}

// MARK: - AgentResult convenience factories

extension AgentResult {
    static func loading(for type: AgentType) -> AgentResult {
        AgentResult(
            agentType: type, fodmapTiers: [],
            ibsTriggerProbability: 0, confidenceTier: .peerReviewed,
            confidenceInterval: 0, bioavailability: [],
            enzymeRecommendations: [], citations: [],
            personalizedRiskDelta: 0, totalFructanG: 0, totalGOSG: 0,
            safetyFlags: [], processingLatencyMs: 0, isLoading: true
        )
    }

    static func error(for type: AgentType, message: String) -> AgentResult {
        AgentResult(
            agentType: type, fodmapTiers: [],
            ibsTriggerProbability: 0, confidenceTier: .peerReviewed,
            confidenceInterval: 0, bioavailability: [],
            enzymeRecommendations: [], citations: [],
            personalizedRiskDelta: 0, totalFructanG: 0, totalGOSG: 0,
            safetyFlags: [SafetyFlag(message: message, severity: .critical)],
            processingLatencyMs: 0, isLoading: false
        )
    }
}

extension SynthesisResult {
    static var loading: SynthesisResult {
        SynthesisResult(
            reconciledTiers: [], finalIBSProbability: 0,
            confidenceBand: 0, enzymeRecommendation: nil,
            keyDisagreements: [],
            synthesisRationale: "",
            safetyFlags: [], isLoading: true
        )
    }

    static func error(message: String) -> SynthesisResult {
        SynthesisResult(
            reconciledTiers: [], finalIBSProbability: 0,
            confidenceBand: 0, enzymeRecommendation: nil,
            keyDisagreements: [],
            synthesisRationale: message,
            safetyFlags: [SafetyFlag(message: message, severity: .critical)],
            isLoading: false
        )
    }
}

// MARK: - UserProfile default

extension UserProfile {
    static var `default`: UserProfile {
        UserProfile()
    }
}