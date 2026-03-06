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
    @Published var productName: String? = nil
    @Published var productImageURL: String? = nil
    @Published var productImage: UIImage? = nil

    // MARK: Agent results — update independently as each arrives
    @Published var claudeResult: AgentResult = .loading(for: .claude)
    @Published var geminiResult: AgentResult = .loading(for: .gemini)
    @Published var appleResult: SynthesisResult = .loading

    // MARK: Phase tracking
    @Published var phase: QueryPhase = .idle
    @Published var claudeComplete = false
    @Published var geminiComplete = false
    @Published var appleComplete = false

    // MARK: Error tracking per agent
    @Published var claudeError: String? = nil
    @Published var geminiError: String? = nil
    @Published var appleError: String? = nil

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
            if let name = productName {
                return "\(name) (Barcode: \(barcodeValue ?? "unknown")). Analyze this food product for FODMAP content and IBS risk."
            } else {
                return "Barcode: \(barcodeValue ?? "unknown"). Identify this food product and analyze for FODMAP content and IBS risk."
            }
        }
    }

    // MARK: - Main Analysis Pipeline

    func analyze() async {
        guard canSubmit else { return }

        // Reset state
        phase = .running
        claudeComplete = false
        geminiComplete = false
        appleComplete = false
        claudeError = nil
        geminiError = nil
        appleError = nil

        claudeResult = .loading(for: .claude)
        geminiResult = .loading(for: .gemini)
        appleResult = .loading

        showResults = true

        // Stage 1: Claude + Gemini fire in parallel (primary agents)
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.runClaudeAgent() }
            group.addTask { await self.runGeminiAgent() }
        }

        // Stage 2: Apple synthesis — needs both Claude and Gemini results
        await runAppleSynthesis()

        phase = .complete
        
        // Stage 3: Save to history
        saveToHistory()
    }

    // MARK: - Claude Agent (Primary Analysis)

    private func runClaudeAgent() async {
        do {
            let result = try await backendService.analyzeClaude(
                query: resolvedQuery,
                profile: userProfile,
                sources: userSources,
                serving: servingViewModel,
                image: capturedImage
            )
            claudeResult = result
            claudeComplete = true
        } catch {
            claudeError = error.localizedDescription
            claudeResult = AgentResult.error(for: .claude, message: error.localizedDescription)
            claudeComplete = true
        }
    }

    // MARK: - Gemini Agent (Primary Analysis)

    private func runGeminiAgent() async {
        do {
            let result = try await backendService.analyzeGemini(
                query: resolvedQuery,
                profile: userProfile,
                sources: userSources,
                serving: servingViewModel,
                image: capturedImage
            )
            geminiResult = result
            geminiComplete = true
        } catch {
            geminiError = error.localizedDescription
            geminiResult = AgentResult.error(for: .gemini, message: error.localizedDescription)
            geminiComplete = true
        }
    }

    // MARK: - Apple Synthesis (Reconciles Claude + Gemini)

    private func runAppleSynthesis() async {
        // Check if Apple Intelligence is available
        guard appleService.isAvailable else {
            appleError = "Apple Intelligence not available"
            appleResult = SynthesisResult.error(message: "Apple Intelligence not available for synthesis. Using Claude result as fallback.")
            appleComplete = true
            return
        }

        // Encode Claude and Gemini results for synthesis
        guard let claudeJSON = encodeAgentResult(claudeResult),
              let geminiJSON = encodeAgentResult(geminiResult) else {
            appleError = "Could not encode agent results for synthesis."
            appleResult = SynthesisResult.error(message: "Agent result encoding failed.")
            appleComplete = true
            return
        }

        do {
            let result = try await appleService.synthesizeResults(
                query: resolvedQuery,
                profile: userProfile,
                sources: userSources,
                claudeJSON: claudeJSON,
                geminiJSON: geminiJSON
            )
            appleResult = result
            appleComplete = true
        } catch {
            appleError = error.localizedDescription
            appleResult = SynthesisResult.error(message: error.localizedDescription)
            appleComplete = true
        }
    }

    // MARK: - Helpers

    private func encodeAgentResult(_ result: AgentResult) -> String? {
        // Encode agent result to JSON string for synthesis
        struct AgentExport: Encodable {
            let agent_type: String
            let fodmap_tiers: [[String: String]]
            let ibs_trigger_probability: Double
            let confidence_tier: String
            let total_fructan_g: Double
            let total_gos_g: Double
        }

        let export = AgentExport(
            agent_type: result.agentType.rawValue,
            fodmap_tiers: result.fodmapTiers.map { item in
                var d: [String: String] = [
                    "ingredient": item.ingredient,
                    "tier": item.tier.rawValue.lowercased(),
                    "source": item.source
                ]
                if let f = item.fructanG { d["fructan_g"] = String(f) }
                if let g = item.gosG     { d["gos_g"] = String(g) }
                return d
            },
            ibs_trigger_probability: result.ibsTriggerProbability,
            confidence_tier: result.confidenceTier.rawValue,
            total_fructan_g: result.totalFructanG,
            total_gos_g: result.totalGOSG
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
        
        record.saveResults(claude: claudeResult, gemini: geminiResult, apple: appleResult)
        
        context.insert(record)
        
        do {
            try context.save()
        } catch {
            print("Failed to save query to history: \(error)")
        }
    }
    
    // MARK: - Product Lookup
    
    func lookupProduct(barcode: String) async {
        productName = nil
        productImageURL = nil
        productImage = nil
        
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json") else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
            
            if response.status == 1, let product = response.product {
                productName = product.product_name ?? product.product_name_en
                productImageURL = product.image_url
                
                // Load product image if available
                if let imageURLString = product.image_url,
                   let imageURL = URL(string: imageURLString) {
                    let (imageData, _) = try await URLSession.shared.data(from: imageURL)
                    productImage = UIImage(data: imageData)
                }
            }
        } catch {
            print("Failed to lookup product: \(error)")
        }
    }
    
    // MARK: - Reset

    func reset() {
        textQuery = ""
        capturedImage = nil
        barcodeValue = nil
        barcodeDetected = false
        selectedPhoto = nil
        productName = nil
        productImageURL = nil
        productImage = nil
        phase = .idle
        showResults = false
        claudeResult = .loading(for: .claude)
        geminiResult = .loading(for: .gemini)
        appleResult = .loading
    }
}

// MARK: - Open Food Facts API Models

struct OpenFoodFactsResponse: Codable {
    let status: Int
    let product: OpenFoodFactsProduct?
}

struct OpenFoodFactsProduct: Codable {
    let product_name: String?
    let product_name_en: String?
    let image_url: String?
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