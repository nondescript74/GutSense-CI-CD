//
//  FODMAPRiskCalculator.swift
//  GutSense
//
//  Deterministic on-device FODMAP risk calculation.
//  Extracted from SimulationViewModel for testability.
//  Ported from GutSense-Web calculateSimulationRisk.ts
//
//  Uses Monash-aligned FODMAP thresholds:
//    Fructan:  < 0.3g low, 0.3–0.9g moderate, ≥ 1.0g high
//    GOS:     < 0.3g low, 0.3–0.9g moderate, ≥ 1.0g high
//    Lactose: < 1.0g low, 1.0–4.0g moderate, > 4.0g high
//    Fructose: < 0.15g (excess) low, 0.15–0.5g moderate, > 0.5g high
//    Polyol:  < 0.3g low, 0.3–0.5g moderate, > 0.5g high
//

import Foundation

// MARK: - FODMAP Category Thresholds

/// Per-category threshold defining low/high cutoffs in grams (cumulative)
private struct FODMAPThreshold {
    let low: Double    // below this → low risk contribution
    let high: Double   // above this → high risk contribution
}

/// Monash-aligned thresholds
private let monashThresholds: [String: FODMAPThreshold] = [
    "fructan":  FODMAPThreshold(low: 0.3,  high: 1.0),
    "gos":      FODMAPThreshold(low: 0.3,  high: 1.0),
    "lactose":  FODMAPThreshold(low: 1.0,  high: 4.0),
    "fructose": FODMAPThreshold(low: 0.15, high: 0.5),
    "polyol":   FODMAPThreshold(low: 0.3,  high: 0.5),
]

/// Category weights for final risk computation (sum = 1.0)
private let categoryWeights: [String: Double] = [
    "fructan":  0.25,
    "gos":      0.20,
    "lactose":  0.20,
    "fructose": 0.15,
    "polyol":   0.20,
]

// MARK: - Calculator

enum FODMAPRiskCalculator {

    /// Calculate simulation risk from the current ingredient set.
    /// Runs entirely on-device — no network call needed.
    ///
    /// - Parameters:
    ///   - ingredients: The full simulation ingredient list (included + excluded)
    ///   - baselineProbability: The original synthesis probability to compute delta against
    /// - Returns: A deterministic `SimulationRiskResult`
    static func calculate(
        ingredients: [SimulationIngredient],
        baselineProbability: Double
    ) -> SimulationRiskResult {

        let included = ingredients.filter(\.included)
        let excluded = ingredients.filter { !$0.included }

        // Sum FODMAP grams across all included ingredients
        let totalFructan  = included.reduce(0.0) { $0 + $1.fructanG }
        let totalGOS      = included.reduce(0.0) { $0 + $1.gosG }
        let totalLactose  = included.reduce(0.0) { $0 + $1.lactoseG }
        let totalFructose = included.reduce(0.0) { $0 + $1.fructoseG }
        let totalPolyol   = included.reduce(0.0) { $0 + $1.polyolG }

        let totalLoad = totalFructan + totalGOS + totalLactose + totalFructose + totalPolyol

        // Weighted risk across FODMAP categories, clamped to [0, 1]
        let rawRisk =
            categoryRisk(total: totalFructan,  threshold: monashThresholds["fructan"]!)  * categoryWeights["fructan"]!  +
            categoryRisk(total: totalGOS,       threshold: monashThresholds["gos"]!)      * categoryWeights["gos"]!      +
            categoryRisk(total: totalLactose,   threshold: monashThresholds["lactose"]!)  * categoryWeights["lactose"]!  +
            categoryRisk(total: totalFructose,  threshold: monashThresholds["fructose"]!) * categoryWeights["fructose"]! +
            categoryRisk(total: totalPolyol,    threshold: monashThresholds["polyol"]!)   * categoryWeights["polyol"]!

        let probability = min(1.0, max(0.0, rawRisk))
        let delta = probability - baselineProbability

        let tier: SimulationRiskTier
        if probability < 0.3      { tier = .low }
        else if probability < 0.6 { tier = .moderate }
        else                      { tier = .high }

        return SimulationRiskResult(
            totalFructan:         round2(totalFructan),
            totalGOS:             round2(totalGOS),
            totalLactose:         round2(totalLactose),
            totalFructose:        round2(totalFructose),
            totalPolyol:          round2(totalPolyol),
            totalFODMAPLoad:      round2(totalLoad),
            estimatedProbability: round3(probability),
            riskTier:             tier,
            delta:                round3(delta),
            includedCount:        included.count,
            excludedCount:        excluded.count
        )
    }

    // MARK: - Internals

    /// Per-category risk contribution based on threshold brackets
    private static func categoryRisk(total: Double, threshold: FODMAPThreshold) -> Double {
        if total <= 0              { return 0 }
        if total < threshold.low   { return 0.05 }
        if total < threshold.high  { return 0.25 }
        return 0.55
    }

    private static func round2(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    private static func round3(_ value: Double) -> Double {
        (value * 1000).rounded() / 1000
    }
}
