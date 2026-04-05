//
//  SimulationViewModel.swift
//  GutSense
//
//  Ingredient simulation state management.
//  Kept separate from QueryViewModel so simulation never pollutes baseline.
//

import SwiftUI
import Combine

// MARK: - Ingredient Provenance

/// Which agent(s) originally detected this ingredient.
enum IngredientProvenance: String, CaseIterable, Identifiable, Codable {
    case claude  = "claude"
    case openai  = "openai"
    case gemini  = "gemini"
    case apple   = "apple"
    case both    = "both"
    case user    = "user"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .claude:  return "Claude"
        case .openai:  return "OpenAI"
        case .gemini:  return "Gemini"
        case .apple:   return "Apple"
        case .both:    return "Both"
        case .user:    return "User"
        }
    }

    var icon: String {
        switch self {
        case .claude:  return "brain"
        case .openai:  return "bolt.fill"
        case .gemini:  return "diamond.fill"
        case .apple:   return "apple.logo"
        case .both:    return "person.2.fill"
        case .user:    return "person.fill"
        }
    }

    var color: Color {
        switch self {
        case .claude:  return .purple
        case .openai:  return .green
        case .gemini:  return .blue
        case .apple:   return .gray
        case .both:    return .indigo
        case .user:    return .orange
        }
    }
}

// MARK: - Risk Tier

enum SimulationRiskTier: String {
    case low
    case moderate
    case high

    var color: Color {
        switch self {
        case .low:      return .green
        case .moderate: return .orange
        case .high:     return .red
        }
    }

    var label: String {
        switch self {
        case .low:      return "Low Risk"
        case .moderate: return "Moderate Risk"
        case .high:     return "High Risk"
        }
    }
}

// MARK: - Simulation Ingredient

/// A single ingredient in the simulation model, with provenance and toggle state.
struct SimulationIngredient: Identifiable {
    let id: String
    var ingredient: String
    var tier: FODMAPTier
    var fructanG: Double
    var gosG: Double
    var lactoseG: Double
    var fructoseG: Double
    var polyolG: Double
    var servingSizeG: Double
    var source: String
    var provenance: IngredientProvenance
    var included: Bool

    var totalFODMAP: Double {
        fructanG + gosG + lactoseG + fructoseG + polyolG
    }
}

// MARK: - Simulation Risk Result

/// Deterministic risk calculation result from current simulation ingredient set.
struct SimulationRiskResult {
    let totalFructan: Double
    let totalGOS: Double
    let totalLactose: Double
    let totalFructose: Double
    let totalPolyol: Double
    let totalFODMAPLoad: Double
    let estimatedProbability: Double
    let riskTier: SimulationRiskTier
    let delta: Double
    let includedCount: Int
    let excludedCount: Int
}

// MARK: - Re-synthesis Result (domain)

struct SimulationResynthesisResult {
    let reconciledTiers: [IngredientFODMAP]
    let finalIBSProbability: Double
    let confidenceBand: Double
    let synthesisRationale: String
    let keyDisagreements: [String]
    let safetyFlags: [SafetyFlag]
    let enzymeRecommendation: EnzymeRecommendation?
}

// MARK: - Simulation View Model

@MainActor
final class SimulationViewModel: ObservableObject {

    // MARK: State

    @Published var ingredients: [SimulationIngredient] = []
    @Published var baselineProbability: Double = 0
    @Published var risk: SimulationRiskResult?
    @Published var isOpen: Bool = false
    @Published var isDirty: Bool = false

    @Published var resynthLoading: Bool = false
    @Published var resynthResult: SimulationResynthesisResult?
    @Published var resynthError: String?

    // MARK: Context for re-synthesis (stored so panel doesn't need to pass them)

    private var originalQuery: String = ""
    private var storedPrimaryResult: AgentResult?
    private var storedGeminiResult: AgentResult?
    private var storedUserProfile: UserProfile = .default
    private var storedUserSources: [UserSource] = []

    // MARK: Initialize from agent results

    /// Merge primary + gemini + apple synthesis ingredient lists with provenance attribution.
    /// Also stores context needed for Apple Intelligence on-device re-synthesis.
    func initialize(
        primaryResult: AgentResult?,
        geminiResult: AgentResult?,
        synthesisResult: SynthesisResult? = nil,
        baselineProb: Double,
        query: String = "",
        userProfile: UserProfile? = nil,
        userSources: [UserSource] = []
    ) {
        // Store context for re-synthesis
        originalQuery = query
        storedPrimaryResult = primaryResult
        storedGeminiResult = geminiResult
        storedUserProfile = userProfile ?? .default
        storedUserSources = userSources

        // Delegate to provenance engine (includes Apple synthesis cross-reference)
        let merged = IngredientProvenanceEngine.deriveSimulationIngredients(
            primaryResult: primaryResult,
            geminiResult: geminiResult,
            synthesisResult: synthesisResult
        )
        ingredients = merged
        baselineProbability = baselineProb
        risk = calculateRisk()
        isDirty = false
        resynthResult = nil
        resynthError = nil
    }

    // MARK: Actions

    func toggleIngredient(_ id: String) {
        guard let idx = ingredients.firstIndex(where: { $0.id == id }) else { return }
        ingredients[idx].included.toggle()
        recalculate()
    }

    func removeIngredient(_ id: String) {
        ingredients.removeAll { $0.id == id }
        recalculate()
    }

    func addIngredient(name: String) {
        let ing = SimulationIngredient(
            id: "user_\(UUID().uuidString.prefix(8))",
            ingredient: name,
            tier: .low,
            fructanG: 0, gosG: 0, lactoseG: 0, fructoseG: 0, polyolG: 0,
            servingSizeG: 0,
            source: "User-added",
            provenance: .user,
            included: true
        )
        ingredients.append(ing)
        recalculate()
    }

    func reset() {
        ingredients = []
        baselineProbability = 0
        risk = nil
        isOpen = false
        isDirty = false
        resynthLoading = false
        resynthResult = nil
        resynthError = nil
    }

    // MARK: Re-synthesize (Apple Intelligence primary → backend fallback)

    /// Re-synthesize with edited ingredients.
    /// Uses stored context from `initialize()`, so callers don't need to pass everything again.
    /// Falls back to `resynthesize(originalQuery:primaryResult:geminiResult:userProfile:)` signature
    /// for backward compatibility with IngredientSimulationPanel.
    func resynthesize(
        originalQuery: String,
        primaryResult: AgentResult,
        geminiResult: AgentResult,
        userProfile: UserProfile
    ) async {
        resynthLoading = true
        resynthError = nil

        let included = ingredients.filter(\.included)

        // Primary path: Apple Intelligence on-device re-synthesis
        let appleService = AppleFoundationModelService.shared
        if appleService.isAvailable {
            do {
                // Build a JSON representation of the edited ingredients for Apple synthesis
                let editedJSON = buildEditedIngredientsJSON(included)
                let claudeJSON = encodeAgentResultForSynthesis(primaryResult)
                let geminiJSON = encodeAgentResultForSynthesis(geminiResult)

                if let cJSON = claudeJSON, let gJSON = geminiJSON {
                    // Inject edited ingredient context into the synthesis prompt
                    let augmentedClaudeJSON = """
                    {"original_analysis": \(cJSON), "simulation_edits": \(editedJSON), "note": "User modified ingredients — re-synthesize with edited set"}
                    """

                    let result = try await appleService.synthesizeResults(
                        query: originalQuery,
                        profile: userProfile,
                        sources: storedUserSources,
                        claudeJSON: augmentedClaudeJSON,
                        geminiJSON: gJSON
                    )

                    resynthResult = SimulationResynthesisResult(
                        reconciledTiers: result.reconciledTiers,
                        finalIBSProbability: result.finalIBSProbability,
                        confidenceBand: result.confidenceBand,
                        synthesisRationale: "🍎 On-device: " + result.synthesisRationale,
                        keyDisagreements: result.keyDisagreements,
                        safetyFlags: result.safetyFlags,
                        enzymeRecommendation: result.enzymeRecommendation
                    )
                    resynthLoading = false
                    return
                }
            } catch {
                // Apple failed — fall through to backend
                print("⚠️ Apple re-synthesis failed, falling back to backend: \(error.localizedDescription)")
            }
        }

        // Fallback: Backend /simulate/resynthesize
        do {
            let result = try await BackendAPIService.shared.resynthesizeSimulation(
                originalQuery: originalQuery,
                editedIngredients: included,
                primaryResult: primaryResult,
                geminiResult: geminiResult,
                userProfile: userProfile
            )
            resynthResult = result
        } catch {
            resynthError = error.localizedDescription
        }

        resynthLoading = false
    }

    // MARK: - JSON Helpers for Apple Re-synthesis

    private func buildEditedIngredientsJSON(_ ingredients: [SimulationIngredient]) -> String {
        let items = ingredients.map { ing in
            """
            {"ingredient":"\(ing.ingredient)","tier":"\(ing.tier.rawValue.lowercased())","fructan_g":\(ing.fructanG),"gos_g":\(ing.gosG),"lactose_g":\(ing.lactoseG),"fructose_g":\(ing.fructoseG),"polyol_g":\(ing.polyolG)}
            """
        }
        return "[\(items.joined(separator: ","))]"
    }

    private func encodeAgentResultForSynthesis(_ result: AgentResult) -> String? {
        let dto = AgentResultDTO.from(result)
        guard let data = try? JSONEncoder().encode(dto) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Private

    private func recalculate() {
        isDirty = true
        risk = calculateRisk()
    }

    private func calculateRisk() -> SimulationRiskResult {
        FODMAPRiskCalculator.calculate(
            ingredients: ingredients,
            baselineProbability: baselineProbability
        )
    }

}
