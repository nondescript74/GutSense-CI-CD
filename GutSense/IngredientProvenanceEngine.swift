//
//  IngredientProvenanceEngine.swift
//  GutSense
//
//  Merges ingredient lists from Claude, Gemini, and Apple agent results
//  to build the initial simulation ingredient set with provenance attribution.
//  Extracted from SimulationViewModel for testability.
//  Ported from GutSense-Web deriveIngredientProvenance.ts
//
//  Key behaviors:
//    - Fuzzy name matching (normalized lowercase, trimmed whitespace)
//    - If two agents detect the same ingredient, mark provenance "both"
//      and take the conservative (higher) tier + averaged FODMAP values
//    - Apple synthesis reconciledTiers can also contribute ingredients
//

import Foundation

// MARK: - Provenance Engine

enum IngredientProvenanceEngine {

    /// Merge ingredients from primary (Claude/OpenAI) + Gemini agent results
    /// into SimulationIngredients with provenance attribution.
    /// If the Apple synthesis also has reconciled tiers, those are used to
    /// add any ingredients detected only by Apple's on-device model.
    ///
    /// - Parameters:
    ///   - primaryResult: Claude or OpenAI agent result (may be loading/error — safe to pass nil)
    ///   - geminiResult: Gemini agent result (may be loading/error — safe to pass nil)
    ///   - synthesisResult: Apple on-device synthesis result (optional cross-reference)
    /// - Returns: Merged ingredient list with provenance tags
    static func deriveSimulationIngredients(
        primaryResult: AgentResult?,
        geminiResult: AgentResult?,
        synthesisResult: SynthesisResult? = nil
    ) -> [SimulationIngredient] {

        let primaryTiers = primaryResult?.fodmapTiers ?? []
        let geminiTiers  = geminiResult?.fodmapTiers ?? []

        // Determine primary provenance based on agent type
        let primaryProvenance: IngredientProvenance =
            primaryResult?.agentType == .openai ? .openai : .claude

        // Index primary ingredients by normalized name
        var primaryMap: [String: IngredientFODMAP] = [:]
        for t in primaryTiers {
            primaryMap[normalize(t.ingredient)] = t
        }

        var result: [SimulationIngredient] = []
        var matched: Set<String> = []
        var counter = 0

        func nextID() -> String {
            counter += 1
            return "sim_\(counter)"
        }

        // Process Gemini ingredients, check for overlaps with primary
        for gt in geminiTiers {
            let key = normalize(gt.ingredient)
            if let pt = primaryMap[key] {
                // Both agents detected this ingredient — merge
                matched.insert(key)
                result.append(mergedIngredient(
                    primary: pt, gemini: gt, id: nextID()
                ))
            } else {
                result.append(toSimIngredient(gt, provenance: .gemini, id: nextID()))
            }
        }

        // Add primary-only ingredients
        for pt in primaryTiers {
            let key = normalize(pt.ingredient)
            if !matched.contains(key) {
                result.append(toSimIngredient(pt, provenance: primaryProvenance, id: nextID()))
            }
        }

        // If Apple synthesis has additional reconciled ingredients not from either agent,
        // add them with .apple provenance
        if let synthesis = synthesisResult, !synthesis.isLoading {
            let existingKeys = Set(result.map { normalize($0.ingredient) })
            for rt in synthesis.reconciledTiers {
                let key = normalize(rt.ingredient)
                if !existingKeys.contains(key) {
                    result.append(toSimIngredient(rt, provenance: .apple, id: nextID()))
                }
            }
        }

        return result
    }

    // MARK: - Internals

    /// Normalize ingredient name for fuzzy matching
    private static func normalize(_ name: String) -> String {
        name.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Convert an IngredientFODMAP to SimulationIngredient
    private static func toSimIngredient(
        _ fodmap: IngredientFODMAP,
        provenance: IngredientProvenance,
        id: String
    ) -> SimulationIngredient {
        SimulationIngredient(
            id: id,
            ingredient: fodmap.ingredient,
            tier: fodmap.tier,
            fructanG: fodmap.fructanG ?? 0,
            gosG: fodmap.gosG ?? 0,
            lactoseG: fodmap.lactoseG ?? 0,
            fructoseG: fodmap.fructoseG ?? 0,
            polyolG: fodmap.polyolG ?? 0,
            servingSizeG: fodmap.servingSizeG,
            source: fodmap.source,
            provenance: provenance,
            included: true
        )
    }

    /// Merge two agent detections into a single SimulationIngredient.
    /// Takes conservative (higher) tier and averaged FODMAP values.
    private static func mergedIngredient(
        primary: IngredientFODMAP,
        gemini: IngredientFODMAP,
        id: String
    ) -> SimulationIngredient {
        SimulationIngredient(
            id: id,
            ingredient: primary.ingredient,  // prefer primary casing
            tier: higherTier(primary.tier, gemini.tier),
            fructanG:  avg(primary.fructanG, gemini.fructanG),
            gosG:      avg(primary.gosG, gemini.gosG),
            lactoseG:  avg(primary.lactoseG, gemini.lactoseG),
            fructoseG: avg(primary.fructoseG, gemini.fructoseG),
            polyolG:   avg(primary.polyolG, gemini.polyolG),
            servingSizeG: primary.servingSizeG,
            source: "\(primary.source); \(gemini.source)",
            provenance: .both,
            included: true
        )
    }

    /// Average two optional gram values
    private static func avg(_ a: Double?, _ b: Double?) -> Double {
        let va = a ?? 0
        let vb = b ?? 0
        return ((va + vb) / 2 * 100).rounded() / 100
    }

    /// Return the more conservative (higher risk) of two FODMAPTiers
    private static func higherTier(_ a: FODMAPTier, _ b: FODMAPTier) -> FODMAPTier {
        let rank: [FODMAPTier: Int] = [.low: 0, .moderate: 1, .high: 2]
        return (rank[a] ?? 0) >= (rank[b] ?? 0) ? a : b
    }
}
