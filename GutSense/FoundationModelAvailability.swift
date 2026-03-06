//
//  FoundationModelAvailability.swift
//  GutSense
//
//  Created by Zahirudeen Premji on 3/5/26.
//


// GutSense — AppleFoundationModelService.swift
// iOS 18 Apple Foundation Models (Apple Intelligence) — on-device FODMAP analysis
// Requires: iOS 18+, Apple Intelligence enabled, iPhone 15 Pro or M-series iPad
// Framework: FoundationModels (WWDC 2025)

import Foundation
import Combine
import FoundationModels  // iOS 18 — Apple Intelligence framework

// MARK: - Availability Check

enum FoundationModelAvailability {
    case available
    case appleIntelligenceDisabled
    case deviceNotSupported
    case modelNotReady
}

// MARK: - Apple Foundation Model Service

@MainActor
final class AppleFoundationModelService: ObservableObject {
    static let shared = AppleFoundationModelService()

    @Published var availability: FoundationModelAvailability = .modelNotReady

    private var session: LanguageModelSession?
    private let model = SystemLanguageModel.default

    private init() {
        Task { await checkAvailability() }
    }

    // MARK: - Availability

    func checkAvailability() async {
        switch model.availability {
        case .available:
            availability = .available
            // Warm up session
            session = LanguageModelSession(model: model)
        case .unavailable(.appleIntelligenceNotEnabled):
            availability = .appleIntelligenceDisabled
        case .unavailable(.deviceNotEligible):
            availability = .deviceNotSupported
        default:
            availability = .modelNotReady
        }
    }

    var isAvailable: Bool { availability == .available }

    // MARK: - FODMAP Analysis

    func analyzeFODMAP(
        query: String,
        profile: UserProfile,
        sources: [UserSource] = []
    ) async throws -> AgentResult {

        guard isAvailable else {
            // Return a graceful degraded result so the UI still shows 2/3 panes
            return fallbackResult(reason: unavailabilityMessage)
        }

        // Create fresh session for each query (stateless)
        let querySession = LanguageModelSession(
            model: model,
            instructions: buildSystemInstructions(profile: profile)
        )

        let prompt = buildPrompt(query: query, profile: profile, sources: sources)

        let startTime = Date()
        let response = try await querySession.respond(to: prompt)
        let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)

        return parseResponse(response.content, latencyMs: latencyMs, profile: profile)
    }

    // MARK: - Synthesis (Reconcile Claude + Gemini)

    func synthesizeResults(
        query: String,
        profile: UserProfile,
        sources: [UserSource] = [],
        claudeJSON: String,
        geminiJSON: String
    ) async throws -> SynthesisResult {

        guard isAvailable else {
            return fallbackSynthesisResult(reason: unavailabilityMessage)
        }

        let querySession = LanguageModelSession(
            model: model,
            instructions: buildSynthesisInstructions(profile: profile)
        )

        let prompt = buildSynthesisPrompt(
            query: query,
            claudeJSON: claudeJSON,
            geminiJSON: geminiJSON,
            profile: profile,
            sources: sources
        )

        let startTime = Date()
        let response = try await querySession.respond(to: prompt)
        let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)

        return parseSynthesisResponse(response.content, latencyMs: latencyMs)
    }

    // MARK: - System Instructions (role + rules)

    private func buildSystemInstructions(profile: UserProfile) -> String {
        """
        You are a FODMAP food chemistry expert analyzing food safety for an IBS patient.

        PATIENT PROFILE:
        - IBS Subtype: \(profile.ibsSubtype.rawValue)
        - FODMAP Phase: \(profile.fodmapPhase.rawValue)
        - Known Triggers: \(profile.knownTriggers.map(\.rawValue).joined(separator: ", "))

        FODMAP THRESHOLDS (Monash University):
        - Fructans: >0.20g/serving = HIGH risk
        - GOS: >0.30g/serving = HIGH risk
        - Lactose: >4g/serving = HIGH risk
        - Polyols: sorbitol >0.35g, mannitol >0.20g

        MANDATORY RULES:
        1. This is NOT medical advice — always flag this
        2. Crohn's disease is DISTINCT from IBS — flag if mentioned
        3. Never suggest stopping medications
        4. If enzymes can help (Fodzyme for fructans/GOS, must be <55°C), mention them

        Respond with JSON only. No preamble. No markdown fences.
        Use this schema:
        {
          "agent_type": "apple",
          "fodmap_tiers": [{"ingredient":"..","tier":"low|moderate|high","fructan_g":null,"gos_g":null,"lactose_g":null,"fructose_g":null,"polyol_g":null,"serving_size_g":100,"source":"Apple/Monash"}],
          "ibs_trigger_probability": 0.0,
          "confidence_tier": "clinical",
          "confidence_interval": 0.10,
          "bioavailability": [],
          "enzyme_recommendations": [],
          "citations": [],
          "personalized_risk_delta": 0.0,
          "total_fructan_g": 0.0,
          "total_gos_g": 0.0,
          "safety_flags": [{"message":"Not a substitute for medical advice.","severity":"info"}],
          "processing_latency_ms": 0
        }
        """
    }

    private func buildPrompt(query: String, profile: UserProfile, sources: [UserSource]) -> String {
        var prompt = "Analyze this food for FODMAP content and IBS risk: \(query)"

        if !sources.isEmpty {
            let anecdotes = sources.filter { $0.isAnecdotal }.map { "- [ANECDOTAL] \($0.title): \($0.rawText.prefix(200))" }
            if !anecdotes.isEmpty {
                prompt += "\n\nUser-provided anecdotal sources (widen confidence ±18%):\n" + anecdotes.joined(separator: "\n")
            }
        }

        return prompt
    }

    // MARK: - Response Parsing

    private func parseResponse(_ text: String, latencyMs: Int, profile: UserProfile) -> AgentResult {
        // Strip any accidental markdown
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            let lines = cleaned.components(separatedBy: "\n")
            cleaned = lines.dropFirst().dropLast().joined(separator: "\n")
        }

        guard let data = cleaned.data(using: .utf8) else {
            return fallbackResult(reason: "Apple model returned unexpected format.")
        }
        
        let dto: AgentResultDTO
        do {
            dto = try JSONDecoder().decode(AgentResultDTO.self, from: data)
        } catch {
            // Graceful parse failure — return a flagged result
            return fallbackResult(reason: "Apple model returned unexpected format.")
        }

        let result = dto.toDomain(agentType: .apple)
        // Patch latency with real measurement
        return AgentResult(
            agentType: result.agentType,
            fodmapTiers: result.fodmapTiers,
            ibsTriggerProbability: result.ibsTriggerProbability,
            confidenceTier: result.confidenceTier,
            confidenceInterval: result.confidenceInterval,
            bioavailability: result.bioavailability,
            enzymeRecommendations: result.enzymeRecommendations,
            citations: result.citations,
            personalizedRiskDelta: result.personalizedRiskDelta,
            totalFructanG: result.totalFructanG,
            totalGOSG: result.totalGOSG,
            safetyFlags: result.safetyFlags,
            processingLatencyMs: latencyMs,
            isLoading: false
        )
    }

    // MARK: - Synthesis Instructions & Parsing

    private func buildSynthesisInstructions(profile: UserProfile) -> String {
        """
        You are synthesizing two FODMAP analyses (Claude and Gemini) into a final reconciled verdict.

        PATIENT PROFILE:
        - IBS Subtype: \(profile.ibsSubtype.rawValue)
        - FODMAP Phase: \(profile.fodmapPhase.rawValue)
        - Known Triggers: \(profile.knownTriggers.map(\.rawValue).joined(separator: ", "))

        YOUR TASK:
        1. Reconcile differences between Claude and Gemini analyses
        2. Provide final FODMAP tiers (prefer the more conservative assessment)
        3. Calculate final IBS trigger probability with confidence band
        4. Identify key disagreements between agents
        5. Provide synthesis rationale explaining your reconciliation

        RULES:
        - Be conservative: if agents disagree on tier, choose the higher risk
        - Document all disagreements in key_disagreements array
        - Final probability should reflect reconciled view
        - This is NOT medical advice — always include safety flag

        Respond with JSON only. No preamble. No markdown fences.
        Use this schema:
        {
          "reconciled_tiers": [{"ingredient":"..","tier":"low|moderate|high","fructan_g":null,"gos_g":null,"lactose_g":null,"fructose_g":null,"polyol_g":null,"serving_size_g":100,"source":"Reconciled"}],
          "final_ibs_probability": 0.0,
          "confidence_band": 0.10,
          "enzyme_recommendation": null,
          "key_disagreements": ["Claude says X, Gemini says Y - reconciled to Z"],
          "synthesis_rationale": "Detailed explanation of reconciliation process...",
          "safety_flags": [{"message":"Not a substitute for medical advice.","severity":"info"}]
        }
        """
    }

    private func buildSynthesisPrompt(
        query: String,
        claudeJSON: String,
        geminiJSON: String,
        profile: UserProfile,
        sources: [UserSource]
    ) -> String {
        var prompt = """
        Synthesize these two FODMAP analyses for: \(query)

        CLAUDE ANALYSIS:
        \(claudeJSON)

        GEMINI ANALYSIS:
        \(geminiJSON)
        """

        if !sources.isEmpty {
            let anecdotes = sources.filter { $0.isAnecdotal }.map { "- [ANECDOTAL] \($0.title): \($0.rawText.prefix(200))" }
            if !anecdotes.isEmpty {
                prompt += "\n\nUser-provided anecdotal sources:\n" + anecdotes.joined(separator: "\n")
            }
        }

        return prompt
    }

    private func parseSynthesisResponse(_ text: String, latencyMs: Int) -> SynthesisResult {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            let lines = cleaned.components(separatedBy: "\n")
            cleaned = lines.dropFirst().dropLast().joined(separator: "\n")
        }

        guard let data = cleaned.data(using: .utf8) else {
            return fallbackSynthesisResult(reason: "Apple synthesis returned unexpected format.")
        }

        let dto: SynthesisResultDTO
        do {
            dto = try JSONDecoder().decode(SynthesisResultDTO.self, from: data)
        } catch {
            return fallbackSynthesisResult(reason: "Apple synthesis returned unexpected format: \(error.localizedDescription)")
        }

        return dto.toDomain()
    }

    // MARK: - Fallback

    private var unavailabilityMessage: String {
        switch availability {
        case .appleIntelligenceDisabled:
            return "Apple Intelligence is disabled. Enable in Settings → Apple Intelligence & Siri."
        case .deviceNotSupported:
            return "Apple Foundation Models require iPhone 15 Pro / M-series iPad."
        default:
            return "Apple Foundation Model not available on this device."
        }
    }

    private func fallbackResult(reason: String) -> AgentResult {
        AgentResult(
            agentType: .apple,
            fodmapTiers: [],
            ibsTriggerProbability: 0,
            confidenceTier: .clinical,
            confidenceInterval: 0,
            bioavailability: [],
            enzymeRecommendations: [],
            citations: [],
            personalizedRiskDelta: 0,
            totalFructanG: 0,
            totalGOSG: 0,
            safetyFlags: [SafetyFlag(message: reason, severity: .warning)],
            processingLatencyMs: 0,
            isLoading: false
        )
    }

    private func fallbackSynthesisResult(reason: String) -> SynthesisResult {
        SynthesisResult(
            reconciledTiers: [],
            finalIBSProbability: 0,
            confidenceBand: 0,
            enzymeRecommendation: nil,
            keyDisagreements: [],
            synthesisRationale: reason,
            safetyFlags: [SafetyFlag(message: reason, severity: .warning)],
            isLoading: false
        )
    }
}
