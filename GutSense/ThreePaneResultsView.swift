//
//  ThreePaneResultsView.swift
//  GutSense
//
//  Created by Zahirudeen Premji on 3/5/26.
//

// GutSense — ThreePaneResultsView.swift
// iOS 18 | SwiftUI | Multi-Agent FODMAP Analysis
// Pane layout: Apple (top-left) | Claude (top-right) | Gemini Synthesis (bottom)

import SwiftUI


// MARK: - Mock Data

extension AgentResult {
    static var geminiMock: AgentResult {
        AgentResult(
            agentType: .gemini,
            fodmapTiers: [
                IngredientFODMAP(ingredient: "Garlic", tier: .high, fructanG: 0.41, gosG: nil, lactoseG: nil, fructoseG: nil, polyolG: nil, servingSizeG: 3, source: "Monash"),
                IngredientFODMAP(ingredient: "Wheat bread", tier: .high, fructanG: 0.65, gosG: nil, lactoseG: nil, fructoseG: nil, polyolG: nil, servingSizeG: 30, source: "Monash"),
                IngredientFODMAP(ingredient: "Olive oil", tier: .low, fructanG: nil, gosG: nil, lactoseG: nil, fructoseG: nil, polyolG: nil, servingSizeG: 15, source: "Monash"),
            ],
            ibsTriggerProbability: 0.78,
            confidenceTier: .clinical,
            confidenceInterval: 0.09,
            bioavailability: [
                BioavailabilityChange(nutrient: "Allicin (garlic)", rawPercent: 100, cookedPercent: 45, note: "Heat degrades allicin but also reduces fructan load slightly")
            ],
            enzymeRecommendations: [
                EnzymeRecommendation(name: "Fructan Hydrolase", brand: "Fodzyme", targets: "Fructans", dose: "1 sachet", temperatureWarning: true, notes: "Sprinkle on food below 55°C")
            ],
            citations: [
                Citation(title: "Monash FODMAP App Database 2024", source: "Monash University", confidenceTier: .peerReviewed, url: nil)
            ],
            personalizedRiskDelta: +0.22,
            totalFructanG: 1.06,
            totalGOSG: 0.0,
            safetyFlags: [],
            processingLatencyMs: 312,
            isLoading: false
        )
    }

    static var claudeMock: AgentResult {
        AgentResult(
            agentType: .claude,
            fodmapTiers: [
                IngredientFODMAP(ingredient: "Garlic", tier: .high, fructanG: 0.38, gosG: 0.02, lactoseG: nil, fructoseG: nil, polyolG: nil, servingSizeG: 3, source: "PubMed/Monash"),
                IngredientFODMAP(ingredient: "Wheat bread", tier: .high, fructanG: 0.72, gosG: nil, lactoseG: nil, fructoseG: nil, polyolG: nil, servingSizeG: 30, source: "USDA/Monash"),
                IngredientFODMAP(ingredient: "Olive oil", tier: .low, fructanG: nil, gosG: nil, lactoseG: nil, fructoseG: nil, polyolG: nil, servingSizeG: 15, source: "USDA"),
            ],
            ibsTriggerProbability: 0.82,
            confidenceTier: .peerReviewed,
            confidenceInterval: 0.07,
            bioavailability: [
                BioavailabilityChange(nutrient: "Allicin (garlic)", rawPercent: 100, cookedPercent: 38, note: "Stichting et al. 2019: cooking reduces allicin by 60-70%"),
                BioavailabilityChange(nutrient: "Fructans (wheat)", rawPercent: 100, cookedPercent: 95, note: "Baking does not significantly reduce fructan content")
            ],
            enzymeRecommendations: [
                EnzymeRecommendation(name: "Fructan Hydrolase", brand: "Fodzyme", targets: "Fructans, GOS", dose: "1 sachet per meal", temperatureWarning: true, notes: "⚠️ Must be <55°C. Add after food cools."),
                EnzymeRecommendation(name: "Alpha-galactosidase", brand: "Beano", targets: "GOS, galactans", dose: "2-3 drops", temperatureWarning: false, notes: "Take with first bite")
            ],
            citations: [
                Citation(title: "Gibson PR et al. — Evidence-based dietary management of functional GI symptoms", source: "PubMed", confidenceTier: .peerReviewed, url: "https://pubmed.ncbi.nlm.nih.gov/22738241/"),
                Citation(title: "Monash University FODMAP Program", source: "Monash University", confidenceTier: .peerReviewed, url: nil),
                Citation(title: "NICE CG61 — Irritable bowel syndrome in adults", source: "NICE/NHS", confidenceTier: .clinical, url: nil)
            ],
            personalizedRiskDelta: +0.26,
            totalFructanG: 1.10,
            totalGOSG: 0.02,
            safetyFlags: [
                SafetyFlag(message: "Total fructan load (1.10g) exceeds Monash symptomatic threshold (0.20g) by 5.5×", severity: .warning)
            ],
            processingLatencyMs: 1840,
            isLoading: false
        )
    }
}

extension SynthesisResult {
    static var appleSynthesisMock: SynthesisResult {
        SynthesisResult(
            reconciledTiers: [
                IngredientFODMAP(ingredient: "Garlic", tier: .high, fructanG: 0.40, gosG: 0.01, lactoseG: nil, fructoseG: nil, polyolG: nil, servingSizeG: 3, source: "Reconciled"),
                IngredientFODMAP(ingredient: "Wheat bread", tier: .high, fructanG: 0.69, gosG: nil, lactoseG: nil, fructoseG: nil, polyolG: nil, servingSizeG: 30, source: "Reconciled"),
                IngredientFODMAP(ingredient: "Olive oil", tier: .low, fructanG: nil, gosG: nil, lactoseG: nil, fructoseG: nil, polyolG: nil, servingSizeG: 15, source: "Reconciled"),
            ],
            finalIBSProbability: 0.80,
            confidenceBand: 0.11,
            enzymeRecommendation: EnzymeRecommendation(
                name: "Fructan Hydrolase",
                brand: "Fodzyme",
                targets: "Fructans (primary driver)",
                dose: "1 sachet — add to cooled food (<55°C)",
                temperatureWarning: true,
                notes: "Primary mitigation. Combine with Beano if GOS is a known trigger for this user."
            ),
            keyDisagreements: [
                "Garlic fructan content: Apple 0.41g vs Claude 0.38g — minor variance, reconciled to 0.40g",
                "Allicin bioavailability loss: Apple 55% vs Claude 62% — reconciled to 58%"
            ],
            synthesisRationale: "Both agents agree this meal is HIGH risk for IBS-D individuals. The primary driver is combined fructan load (~1.09g) from garlic and wheat, exceeding the Monash symptomatic threshold by >5×. Fodzyme is the recommended mitigation. Disagreements are minor and within measurement variance.",
            safetyFlags: [
                SafetyFlag(message: "⚕️ Not a substitute for medical advice. Consult your gastroenterologist.", severity: .info),
                SafetyFlag(message: "Fructan load 5× above symptomatic threshold — HIGH symptom risk for IBS-D", severity: .critical)
            ],
            isLoading: false
        )
    }
}

// MARK: - Subcomponents

struct FODMAPTierBadge: View {
    let item: IngredientFODMAP

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: item.tier.icon)
                .foregroundColor(item.tier.color)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.ingredient)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)

                if let f = item.fructanG {
                    Text("Fructans \(f, specifier: "%.2f")g")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let g = item.gosG {
                    Text("GOS \(g, specifier: "%.2f")g")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(item.tier.rawValue)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(item.tier.color.opacity(0.15))
                .foregroundColor(item.tier.color)
                .clipShape(Capsule())
        }
        .padding(.vertical, 3)
    }
}

struct ProbabilityGauge: View {
    let probability: Double
    let confidenceInterval: Double
    let label: String

    private var gaugeColor: Color {
        if probability < 0.35 { return .green }
        if probability < 0.65 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)

            HStack(alignment: .center, spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 10)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(gaugeColor)
                            .frame(width: geo.size.width * probability, height: 10)
                    }
                }
                .frame(height: 10)

                Text("\(Int(probability * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundColor(gaugeColor)
                    .frame(width: 36, alignment: .trailing)
            }

            Text("±\(Int(confidenceInterval * 100))% CI")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct EnzymeCard: View {
    let enzyme: EnzymeRecommendation

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("💊")
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(enzyme.brand)
                        .font(.caption.weight(.bold))
                    if enzyme.temperatureWarning {
                        Label("< 55°C", systemImage: "thermometer.medium")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                Text(enzyme.targets)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(enzyme.dose)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.primary)
                if !enzyme.notes.isEmpty {
                    Text(enzyme.notes)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(8)
        .background(Color.yellow.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CitationRow: View {
    let citation: Citation

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(citation.confidenceTier.badge)
                .font(.caption)
            VStack(alignment: .leading, spacing: 1) {
                Text(citation.title)
                    .font(.caption2.weight(.medium))
                    .lineLimit(2)
                Text(citation.source)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SafetyFlagView: View {
    let flag: SafetyFlag

    private var flagColor: Color {
        switch flag.severity {
        case .info:     return .blue
        case .warning:  return .orange
        case .critical: return .red
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: flag.severity == .info ? "info.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(flagColor)
                .font(.caption)
            Text(flag.message)
                .font(.caption2)
                .foregroundColor(flagColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(6)
        .background(flagColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Agent Pane Header

struct AgentPaneHeader: View {
    let title: String
    let icon: String
    let color: Color
    let latencyMs: Int?
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.subheadline.weight(.bold))

            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundColor(color)

            Spacer()

            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            } else if let ms = latencyMs {
                Text("\(ms)ms")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
    }
}

// MARK: - Apple Agent Pane

// GutSense — AppleAgentPane.swift
// Drop-in replacement for the Apple pane in ThreePaneResultsView
// Shows device capability card when Apple Intelligence is unavailable

import SwiftUI

// MARK: - Apple Agent Pane

struct AppleAgentPane: View {
    let result: AgentResult
    @ObservedObject var appleService: AppleFoundationModelService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "apple.logo")
                    .font(.subheadline.weight(.semibold))
                Text("Apple")
                    .font(.subheadline.weight(.bold))
                Spacer()
                if result.isLoading {
                    ProgressView().scaleEffect(0.7)
                } else if appleService.isAvailable {
                    Text("\(result.processingLatencyMs)ms")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Content
            if result.isLoading {
                loadingView
            } else if appleService.isAvailable {
                resultView
            } else {
                unavailableView
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.15)))
    }

    // MARK: - Unavailable View

    private var unavailableView: some View {
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: "brain")
                    .font(.title2)
                    .foregroundColor(.orange)
            }

            // Message
            VStack(spacing: 6) {
                Text(unavailabilityTitle)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(unavailabilityDetail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // What it means for this analysis
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                Text("Claude & Gemini are providing full analysis")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Action hint if just disabled (not unsupported device)
            if appleService.availability == .appleIntelligenceDisabled {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Settings", systemImage: "gear")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Analyzing on-device...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }

    // MARK: - Result View (normal path — Apple Intelligence available)

    private var resultView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !result.fodmapTiers.isEmpty {
                Text("FODMAP Analysis")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                ForEach(result.fodmapTiers) { ingredient in
                    IngredientRow(ingredient: ingredient)
                        .padding(.horizontal, 12)
                }
            }

            Divider().padding(.horizontal, 12)

            // IBS Risk
            VStack(alignment: .leading, spacing: 4) {
                Text("IBS Trigger Risk")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)

                HStack {
                    ProgressView(value: result.ibsTriggerProbability)
                        .tint(riskColor(result.ibsTriggerProbability))
                    Text("\(Int(result.ibsTriggerProbability * 100))%")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(riskColor(result.ibsTriggerProbability))
                }

                Text("±\(Int(result.confidenceInterval * 100))% CI")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Helpers

    private var unavailabilityTitle: String {
        switch appleService.availability {
        case .deviceNotSupported:
            return "Apple Intelligence not supported"
        case .appleIntelligenceDisabled:
            return "Apple Intelligence is off"
        default:
            return "Apple Intelligence unavailable"
        }
    }

    private var unavailabilityDetail: String {
        switch appleService.availability {
        case .deviceNotSupported:
            return "Requires iPhone 15 Pro, iPhone 16, or M-series iPad. Your device doesn't support on-device AI."
        case .appleIntelligenceDisabled:
            return "Enable Apple Intelligence in Settings → Apple Intelligence & Siri to use on-device analysis."
        default:
            return "The on-device model isn't ready yet. It may still be downloading."
        }
    }

    private func riskColor(_ probability: Double) -> Color {
        switch probability {
        case ..<0.30: return .green
        case ..<0.60: return .orange
        default:      return .red
        }
    }
}

// MARK: - Ingredient Row

private struct IngredientRow: View {
    let ingredient: IngredientFODMAP

    var body: some View {
        HStack {
            Image(systemName: ingredient.tier.icon)
                .foregroundColor(ingredient.tier.color)
                .font(.caption)
                .frame(width: 16)
            Text(ingredient.ingredient)
                .font(.caption)
            Spacer()
            Text(ingredient.tier.rawValue)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(ingredient.tier.color.opacity(0.15))
                .foregroundColor(ingredient.tier.color)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Claude Agent Pane

struct ClaudeAgentPane: View {
    let result: AgentResult

    var body: some View {
        VStack(spacing: 0) {
            AgentPaneHeader(
                title: "Claude",
                icon: "sparkles",
                color: Color(red: 0.85, green: 0.55, blue: 0.30),
                latencyMs: result.isLoading ? nil : result.processingLatencyMs,
                isLoading: result.isLoading
            )

            if result.isLoading {
                Spacer()
                ProgressView("Researching citations…")
                    .font(.caption)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {

                        // FODMAP Tiers
                        Text("FODMAP Analysis")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        ForEach(result.fodmapTiers) { item in
                            FODMAPTierBadge(item: item)
                        }

                        Divider()

                        // IBS Probability
                        ProbabilityGauge(
                            probability: result.ibsTriggerProbability,
                            confidenceInterval: result.confidenceInterval + result.confidenceTier.uncertaintyBoost,
                            label: "IBS Trigger Risk"
                        )

                        if result.personalizedRiskDelta > 0 {
                            Text("↑ \(Int(result.personalizedRiskDelta * 100))% above your baseline")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }

                        // Bioavailability
                        if !result.bioavailability.isEmpty {
                            Divider()
                            Text("Bioavailability (raw→cooked)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                            ForEach(result.bioavailability) { b in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(b.nutrient)
                                        .font(.caption2.weight(.medium))
                                    Text("\(Int(b.rawPercent))% → \(Int(b.cookedPercent))%")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text(b.note)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }

                        // Enzymes
                        if !result.enzymeRecommendations.isEmpty {
                            Divider()
                            Text("Enzyme Options")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                            ForEach(result.enzymeRecommendations) { enzyme in
                                EnzymeCard(enzyme: enzyme)
                            }
                        }

                        // Safety Flags
                        if !result.safetyFlags.isEmpty {
                            Divider()
                            ForEach(result.safetyFlags) { flag in
                                SafetyFlagView(flag: flag)
                            }
                        }

                        // Citations
                        if !result.citations.isEmpty {
                            Divider()
                            Text("Sources (\(result.confidenceTier.badge) \(result.confidenceTier.rawValue))")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                            ForEach(result.citations) { citation in
                                CitationRow(citation: citation)
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
    }
}

// MARK: - Gemini Agent Pane

struct GeminiAgentPane: View {
    let result: AgentResult

    var body: some View {
        VStack(spacing: 0) {
            AgentPaneHeader(
                title: "Gemini",
                icon: "brain.head.profile",
                color: Color(red: 0.25, green: 0.52, blue: 0.96),
                latencyMs: result.isLoading ? nil : result.processingLatencyMs,
                isLoading: result.isLoading
            )

            if result.isLoading {
                Spacer()
                ProgressView("Analyzing patterns…")
                    .font(.caption)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {

                        // FODMAP Tiers
                        Text("FODMAP Analysis")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        ForEach(result.fodmapTiers) { item in
                            FODMAPTierBadge(item: item)
                        }

                        Divider()

                        // IBS Probability
                        ProbabilityGauge(
                            probability: result.ibsTriggerProbability,
                            confidenceInterval: result.confidenceInterval + result.confidenceTier.uncertaintyBoost,
                            label: "IBS Trigger Risk"
                        )

                        if result.personalizedRiskDelta > 0 {
                            Text("↑ \(Int(result.personalizedRiskDelta * 100))% above your baseline")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }

                        // Safety Flags
                        if !result.safetyFlags.isEmpty {
                            Divider()
                            ForEach(result.safetyFlags) { flag in
                                SafetyFlagView(flag: flag)
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
    }
}

// MARK: - Apple Synthesis Pane

struct AppleSynthesisPane: View {
    let result: SynthesisResult
    @ObservedObject var appleService: AppleFoundationModelService

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "apple.logo")
                    .foregroundColor(.blue)
                    .font(.subheadline.weight(.bold))
                Text("Apple Synthesis")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.blue)
                Spacer()
                if result.isLoading {
                    ProgressView().scaleEffect(0.7)
                } else if appleService.isAvailable {
                    Text("Reconciled verdict")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Unavailable")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.08))

            if result.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Synthesizing Claude + Gemini results…")
                        .font(.subheadline)
                    Text("Apple Intelligence is reconciling the analyses")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {

                        // Reconciled FODMAP
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reconciled FODMAP")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                            ForEach(result.reconciledTiers) { item in
                                FODMAPTierBadge(item: item)
                            }
                        }
                        .frame(minWidth: 180)

                        Divider().frame(height: 120)

                        // Final Probability + Band
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Final Risk Assessment")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                            ProbabilityGauge(
                                probability: result.finalIBSProbability,
                                confidenceInterval: result.confidenceBand,
                                label: "IBS Trigger Probability"
                            )
                            .frame(minWidth: 160)
                        }
                        .frame(minWidth: 180)

                        Divider().frame(height: 120)

                        // Enzyme Recommendation
                        if let enzyme = result.enzymeRecommendation {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Top Enzyme Mitigation")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                                EnzymeCard(enzyme: enzyme)
                            }
                            .frame(minWidth: 200)
                        }

                        Divider().frame(height: 120)

                        // Disagreements + Rationale
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Synthesis Rationale")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                            Text(result.synthesisRationale)
                                .font(.caption2)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: 260)

                            if !result.keyDisagreements.isEmpty {
                                Text("Agent Disagreements")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                                ForEach(result.keyDisagreements, id: \.self) { d in
                                    Label(d, systemImage: "arrow.triangle.2.circlepath")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(minWidth: 280)
                    }
                    .padding(12)
                }

                // Safety Flags — always shown full width
                if !result.safetyFlags.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(result.safetyFlags) { flag in
                            SafetyFlagView(flag: flag)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            Color(red: 0.25, green: 0.52, blue: 0.96).opacity(0.3), lineWidth: 1.5
        ))
    }
}

// MARK: - Three Pane Results View

struct ThreePaneResultsView: View {
    let query: String
    let claudeResult: AgentResult
    let geminiResult: AgentResult
    let appleResult: SynthesisResult
    var servingInfo: String? = nil
    var capturedImage: UIImage? = nil
    var productName: String? = nil
    var productImage: UIImage? = nil
    var barcodeValue: String? = nil
    @ObservedObject var appleService: AppleFoundationModelService
    
    @State private var showFeedback = false

    var body: some View {
        VStack(spacing: 0) {
            // Query header
            VStack(spacing: 0) {
                // Barcode product info if available
                if let barcode = barcodeValue {
                    HStack(alignment: .top, spacing: 12) {
                        // Product image
                        if let productImg = productImage {
                            Image(uiImage: productImg)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        } else {
                            Image(systemName: "barcode")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                                .frame(width: 60, height: 60)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if let name = productName {
                                Text(name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)
                            } else {
                                Text("Barcode Product")
                                    .font(.subheadline.weight(.semibold))
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "barcode")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(barcode)
                                    .font(.caption.monospaced())
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                // Image thumbnail if available
                else if let image = capturedImage {
                    HStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                                    .font(.caption2)
                                Text("Analyzing this image")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(query)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                } else {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        Text(query)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                
                // Serving size info if available
                if let serving = servingInfo {
                    HStack {
                        Image(systemName: "scalemass.fill")
                            .foregroundColor(.accentColor)
                            .font(.caption2)
                        Text(serving)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .background(Color(.secondarySystemBackground))

            ScrollView {
                VStack(spacing: 12) {
                    // Top: Apple Synthesis (reconciles Claude + Gemini)
                    AppleSynthesisPane(result: appleResult, appleService: appleService)
                        .frame(minHeight: 240)
                    
                    // Feedback button
                    Button {
                        showFeedback = true
                    } label: {
                        Label("Rate this analysis", systemImage: "hand.thumbsup")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.top, 8)

                    // Bottom row: Claude | Gemini (primary analyses)
                    GeometryReader { geo in
                        HStack(alignment: .top, spacing: 10) {
                            ClaudeAgentPane(result: claudeResult)
                                .frame(width: (geo.size.width - 10) / 2)

                            GeminiAgentPane(result: geminiResult)
                                .frame(width: (geo.size.width - 10) / 2)
                        }
                    }
                    .frame(height: 380)
                }
                .padding(12)
            }
        }
        .navigationTitle("GutSense Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showFeedback) {
            FeedbackView(
                foodItem: query,
                backendURL: "https://web-production-825a4.up.railway.app",
                onDismiss: { showFeedback = false }
            )
            .background(ClearBackgroundView())
        }
    }
}

// MARK: - Clear Background Helper

struct ClearBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ThreePaneResultsView(
            query: "Garlic bread with olive oil — is it safe for IBS-D?",
            claudeResult: .claudeMock,
            geminiResult: .geminiMock,
            appleResult: .appleSynthesisMock,
            servingInfo: "1× serving (100%)",
            appleService: AppleFoundationModelService.shared
        )
    }
}


//import SwiftUI
//
//// MARK: - Three Pane Results View
//
//struct ThreePaneResultsView: View {
//    let query: String
//    let appleResult: AgentResult
//    let claudeResult: AgentResult
//    let geminiResult: SynthesisResult
//    
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 20) {
//                // Query Display
//                VStack(alignment: .leading, spacing: 8) {
//                    Text("Query")
//                        .font(.caption.weight(.semibold))
//                        .foregroundColor(.secondary)
//                    Text(query)
//                        .font(.body)
//                        .padding()
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .background(Color(.secondarySystemBackground))
//                        .clipShape(RoundedRectangle(cornerRadius: 12))
//                }
//                .padding(.horizontal)
//                
//                // Apple Pane
//                AgentResultPane(
//                    title: "🍎 Apple Intelligence",
//                    result: appleResult,
//                    color: .blue
//                )
//                
//                // Claude Pane
//                AgentResultPane(
//                    title: "🤖 Claude",
//                    result: claudeResult,
//                    color: .purple
//                )
//                
//                // Gemini Synthesis Pane
//                SynthesisResultPane(
//                    title: "🧠 Gemini Synthesis",
//                    result: geminiResult,
//                    color: .green
//                )
//                
//                Spacer(minLength: 40)
//            }
//            .padding(.top, 16)
//        }
//        .navigationTitle("Analysis Results")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//}
//
//// MARK: - Agent Result Pane
//
//struct AgentResultPane: View {
//    let title: String
//    let result: AgentResult
//    let color: Color
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            // Header
//            HStack {
//                Text(title)
//                    .font(.headline)
//                Spacer()
//                if result.isLoading {
//                    ProgressView()
//                        .scaleEffect(0.8)
//                }
//            }
//            
//            if result.isLoading {
//                Text("Analyzing...")
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//            } else {
//                // IBS Trigger Probability
//                HStack {
//                    Text("IBS Trigger Risk:")
//                        .font(.subheadline.weight(.medium))
//                    Spacer()
//                    Text(String(format: "%.1f%%", result.ibsTriggerProbability * 100))
//                        .font(.subheadline.weight(.bold))
//                        .foregroundColor(probabilityColor(result.ibsTriggerProbability))
//                }
//                
//                // FODMAP Tiers
//                if !result.fodmapTiers.isEmpty {
//                    VStack(alignment: .leading, spacing: 8) {
//                        Text("FODMAP Analysis")
//                            .font(.caption.weight(.semibold))
//                            .foregroundColor(.secondary)
//                        
//                        ForEach(Array(result.fodmapTiers.enumerated()), id: \.offset) { _, item in
//                            HStack {
//                                Text(item.ingredient)
//                                    .font(.caption)
//                                Spacer()
//                                Text(item.tier.rawValue)
//                                    .font(.caption.weight(.medium))
//                                    .foregroundColor(tierColor(item.tier))
//                            }
//                        }
//                    }
//                }
//                
//                // Safety Flags
//                if !result.safetyFlags.isEmpty {
//                    ForEach(Array(result.safetyFlags.enumerated()), id: \.offset) { _, flag in
//                        HStack(spacing: 8) {
//                            Image(systemName: flagIcon(flag.severity))
//                                .font(.caption)
//                                .foregroundColor(flagColor(flag.severity))
//                            Text(flag.message)
//                                .font(.caption2)
//                                .foregroundColor(.secondary)
//                        }
//                    }
//                }
//                
//                // Latency
//                Text("Processed in \(result.processingLatencyMs)ms")
//                    .font(.caption2)
//                    .foregroundColor(.secondary)
//            }
//        }
//        .padding()
//        .background(color.opacity(0.08))
//        .clipShape(RoundedRectangle(cornerRadius: 12))
//        .overlay(
//            RoundedRectangle(cornerRadius: 12)
//                .stroke(color.opacity(0.3), lineWidth: 1)
//        )
//        .padding(.horizontal)
//    }
//    
//    private func probabilityColor(_ prob: Double) -> Color {
//        if prob < 0.3 { return .green }
//        if prob < 0.7 { return .orange }
//        return .red
//    }
//    
//    private func tierColor(_ tier: FODMAPTier) -> Color {
//        switch tier {
//        case .low: return .green
//        case .moderate: return .orange
//        case .high: return .red
//        }
//    }
//    
//    private func flagColor(_ severity: FlagSeverity) -> Color {
//        switch severity {
//        case .info: return .blue
//        case .warning: return .orange
//        case .critical: return .red
//        }
//    }
//    
//    private func flagIcon(_ severity: FlagSeverity) -> String {
//        switch severity {
//        case .info: return "info.circle.fill"
//        case .warning: return "exclamationmark.triangle.fill"
//        case .critical: return "xmark.octagon.fill"
//        }
//    }
//}
//
//// MARK: - Synthesis Result Pane
//
//struct SynthesisResultPane: View {
//    let title: String
//    let result: SynthesisResult
//    let color: Color
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 12) {
//            // Header
//            HStack {
//                Text(title)
//                    .font(.headline)
//                Spacer()
//                if result.isLoading {
//                    ProgressView()
//                        .scaleEffect(0.8)
//                }
//            }
//            
//            if result.isLoading {
//                Text("Synthesizing results...")
//                    .font(.subheadline)
//                    .foregroundColor(.secondary)
//            } else {
//                // Final IBS Probability
//                HStack {
//                    Text("Final IBS Risk:")
//                        .font(.subheadline.weight(.medium))
//                    Spacer()
//                    Text(String(format: "%.1f%%", result.finalIBSProbability * 100))
//                        .font(.subheadline.weight(.bold))
//                        .foregroundColor(probabilityColor(result.finalIBSProbability))
//                }
//                
//                // Synthesis Rationale
//                if !result.synthesisRationale.isEmpty {
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text("Synthesis")
//                            .font(.caption.weight(.semibold))
//                            .foregroundColor(.secondary)
//                        Text(result.synthesisRationale)
//                            .font(.caption)
//                            .foregroundColor(.primary)
//                    }
//                }
//                
//                // Key Disagreements
//                if !result.keyDisagreements.isEmpty {
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text("Key Disagreements")
//                            .font(.caption.weight(.semibold))
//                            .foregroundColor(.secondary)
//                        ForEach(Array(result.keyDisagreements.enumerated()), id: \.offset) { _, disagreement in
//                            Text("• \(disagreement)")
//                                .font(.caption2)
//                                .foregroundColor(.secondary)
//                        }
//                    }
//                }
//                
//                // Safety Flags
//                if !result.safetyFlags.isEmpty {
//                    ForEach(Array(result.safetyFlags.enumerated()), id: \.offset) { _, flag in
//                        HStack(spacing: 8) {
//                            Image(systemName: flagIcon(flag.severity))
//                                .font(.caption)
//                                .foregroundColor(flagColor(flag.severity))
//                            Text(flag.message)
//                                .font(.caption2)
//                                .foregroundColor(.secondary)
//                        }
//                    }
//                }
//            }
//        }
//        .padding()
//        .background(color.opacity(0.08))
//        .clipShape(RoundedRectangle(cornerRadius: 12))
//        .overlay(
//            RoundedRectangle(cornerRadius: 12)
//                .stroke(color.opacity(0.3), lineWidth: 1)
//        )
//        .padding(.horizontal)
//    }
//    
//    private func probabilityColor(_ prob: Double) -> Color {
//        if prob < 0.3 { return .green }
//        if prob < 0.7 { return .orange }
//        return .red
//    }
//    
//    private func flagColor(_ severity: FlagSeverity) -> Color {
//        switch severity {
//        case .info: return .blue
//        case .warning: return .orange
//        case .critical: return .red
//        }
//    }
//    
//    private func flagIcon(_ severity: FlagSeverity) -> String {
//        switch severity {
//        case .info: return "info.circle.fill"
//        case .warning: return "exclamationmark.triangle.fill"
//        case .critical: return "xmark.octagon.fill"
//        }
//    }
//}
