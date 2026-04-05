//
//  IngredientSimulationView.swift
//  GutSense
//
//  Ingredient simulation panel for what-if FODMAP analysis.
//  Matches the web IngredientSimulationPanel + summary card + ingredient rows.
//

import SwiftUI

// MARK: - Provenance Badge

struct ProvenanceBadge: View {
    let provenance: IngredientProvenance

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: provenance.icon)
                .font(.system(size: 9))
            Text(provenance.label)
                .font(.system(size: 9, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(provenance.color.opacity(0.12))
        .foregroundColor(provenance.color)
        .clipShape(Capsule())
    }
}

// MARK: - Risk Tier Badge

struct RiskTierBadge: View {
    let tier: SimulationRiskTier

    var body: some View {
        Text(tier.label)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tier.color.opacity(0.15))
            .foregroundColor(tier.color)
            .clipShape(Capsule())
            .accessibilityIdentifier("simulation.summary.tier")
    }
}

// MARK: - Simulation Summary Card

struct SimulationSummaryCard: View {
    let risk: SimulationRiskResult

    private var gaugeColor: Color {
        if risk.estimatedProbability < 0.3 { return .green }
        if risk.estimatedProbability < 0.6 { return .orange }
        return .red
    }

    private var deltaText: String {
        let pct = Int(abs(risk.delta) * 100)
        if risk.delta > 0 { return "+\(pct)%" }
        if risk.delta < 0 { return "-\(pct)%" }
        return "0%"
    }

    private var deltaColor: Color {
        if risk.delta > 0.01 { return .red }
        if risk.delta < -0.01 { return .green }
        return .secondary
    }

    var body: some View {
        VStack(spacing: 12) {
            // Top row: gauge + tier badge
            HStack(alignment: .center, spacing: 12) {
                // Mini probability gauge
                VStack(alignment: .leading, spacing: 4) {
                    Text("Simulated Risk")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 10)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(gaugeColor)
                                .frame(width: geo.size.width * min(1.0, risk.estimatedProbability), height: 10)
                        }
                    }
                    .frame(height: 10)
                }

                Text("\(Int(risk.estimatedProbability * 100))%")
                    .font(.title3.weight(.bold))
                    .foregroundColor(gaugeColor)
                    .frame(width: 44, alignment: .trailing)
                    .accessibilityIdentifier("simulation.summary.percent")

                RiskTierBadge(tier: risk.riskTier)
            }

            // Delta indicator
            HStack(spacing: 4) {
                Image(systemName: risk.delta > 0.01 ? "arrow.up.right" : risk.delta < -0.01 ? "arrow.down.right" : "arrow.right")
                    .font(.caption2)
                    .foregroundColor(deltaColor)
                Text("Delta: \(deltaText) from baseline")
                    .font(.caption2)
                    .foregroundColor(deltaColor)
                Spacer()
                Text("\(risk.includedCount) included, \(risk.excludedCount) excluded")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // FODMAP Breakdown
            VStack(alignment: .leading, spacing: 4) {
                Text("FODMAP Breakdown")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 0) {
                    fodmapBar(label: "Fructan", value: risk.totalFructan, color: .purple)
                    fodmapBar(label: "GOS", value: risk.totalGOS, color: .blue)
                    fodmapBar(label: "Lactose", value: risk.totalLactose, color: .cyan)
                    fodmapBar(label: "Fructose", value: risk.totalFructose, color: .orange)
                    fodmapBar(label: "Polyol", value: risk.totalPolyol, color: .pink)
                }

                HStack(spacing: 4) {
                    Text("Total FODMAP load:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(risk.totalFODMAPLoad, specifier: "%.2f")g")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("simulation.summary")
    }

    @ViewBuilder
    private func fodmapBar(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
            Text("\(value, specifier: "%.2f")g")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Ingredient Row

struct SimulationIngredientRow: View {
    let ingredient: SimulationIngredient
    let onToggle: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Toggle
            Button(action: onToggle) {
                Image(systemName: ingredient.included ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(ingredient.included ? .accentColor : .gray)
                    .font(.body)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("simulation.ingredient.toggle")

            // Tier indicator
            Image(systemName: ingredient.tier.icon)
                .foregroundColor(ingredient.tier.color)
                .font(.caption)

            // Name + details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(ingredient.ingredient)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(ingredient.included ? .primary : .secondary)
                        .strikethrough(!ingredient.included)
                        .accessibilityIdentifier("simulation.ingredient.name")
                    ProvenanceBadge(provenance: ingredient.provenance)
                }
                if ingredient.totalFODMAP > 0 {
                    Text("\(ingredient.totalFODMAP, specifier: "%.2f")g FODMAP")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Tier pill
            Text(ingredient.tier.rawValue)
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(ingredient.tier.color.opacity(0.15))
                .foregroundColor(ingredient.tier.color)
                .clipShape(Capsule())

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(0.5))
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("simulation.ingredient.remove")
        }
        .padding(.vertical, 4)
        .opacity(ingredient.included ? 1.0 : 0.6)
    }
}

// MARK: - Add Ingredient Control

struct AddIngredientControl: View {
    @Binding var isExpanded: Bool
    @State private var newName: String = ""
    let onAdd: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            if isExpanded {
                HStack(spacing: 8) {
                    TextField("Ingredient name", text: $newName)
                        .font(.caption)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("simulation.add.field")

                    Button {
                        let trimmed = newName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onAdd(trimmed)
                        newName = ""
                        isExpanded = false
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("simulation.add.confirm")

                    Button {
                        newName = ""
                        isExpanded = false
                    } label: {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("simulation.add.cancel")
                }
            } else {
                Button {
                    isExpanded = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                        Text("Add ingredient")
                            .font(.caption)
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("simulation.add.open")
            }
        }
    }
}

// MARK: - Re-synthesis Result View

struct SimulationResynthesisResultView: View {
    let result: SimulationResynthesisResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                    .font(.caption)
                Text("Re-synthesis Result")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.purple)
            }

            // Probability
            HStack {
                Text("Updated IBS Risk:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(result.finalIBSProbability * 100))% ±\(Int(result.confidenceBand * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundColor(result.finalIBSProbability < 0.3 ? .green : result.finalIBSProbability < 0.6 ? .orange : .red)
            }

            // Rationale
            if !result.synthesisRationale.isEmpty {
                Text(result.synthesisRationale)
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Key disagreements
            if !result.keyDisagreements.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Key Disagreements")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                    ForEach(Array(result.keyDisagreements.enumerated()), id: \.offset) { _, item in
                        Text("• \(item)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Safety flags
            ForEach(result.safetyFlags) { flag in
                SafetyFlagView(flag: flag)
            }

            // Enzyme recommendation
            if let enzyme = result.enzymeRecommendation {
                EnzymeCard(enzyme: enzyme)
            }
        }
        .padding(10)
        .background(Color.purple.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Main Simulation Panel

struct IngredientSimulationPanel: View {
    @ObservedObject var viewModel: SimulationViewModel
    let originalQuery: String
    let primaryResult: AgentResult?
    let geminiResult: AgentResult?
    let userProfile: UserProfile

    @State private var addingIngredient = false

    var body: some View {
        VStack(spacing: 0) {
            // Collapsible header
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.isOpen.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.indigo)
                        .font(.subheadline.weight(.bold))

                    Text("Ingredient Simulation")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.indigo)

                    if viewModel.isDirty {
                        Text("Modified")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                            .accessibilityIdentifier("simulation.modified.badge")
                    }

                    Spacer()

                    Image(systemName: viewModel.isOpen ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.indigo.opacity(0.08))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("simulation.panel.toggle")
            .accessibilityLabel("Ingredient Simulation")

            // Expanded content
            if viewModel.isOpen {
                VStack(spacing: 12) {
                    // Summary card
                    if let risk = viewModel.risk {
                        SimulationSummaryCard(risk: risk)
                    }

                    // Ingredient list
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Ingredients (\(viewModel.ingredients.count))")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                            .accessibilityIdentifier("simulation.ingredients.header")

                        ForEach(viewModel.ingredients) { ingredient in
                            SimulationIngredientRow(
                                ingredient: ingredient,
                                onToggle: { viewModel.toggleIngredient(ingredient.id) },
                                onRemove: { viewModel.removeIngredient(ingredient.id) }
                            )
                            if ingredient.id != viewModel.ingredients.last?.id {
                                Divider()
                            }
                        }

                        AddIngredientControl(isExpanded: $addingIngredient) { name in
                            viewModel.addIngredient(name: name)
                        }
                        .padding(.top, 6)
                    }

                    // Re-synthesize section
                    if viewModel.isDirty {
                        VStack(spacing: 8) {
                            if viewModel.resynthLoading {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Re-synthesizing with edited ingredients...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                            } else {
                                Button {
                                    guard let primary = primaryResult,
                                          let gemini = geminiResult else { return }
                                    Task {
                                        await viewModel.resynthesize(
                                            originalQuery: originalQuery,
                                            primaryResult: primary,
                                            geminiResult: gemini,
                                            userProfile: userProfile
                                        )
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "sparkles")
                                        Text("Re-synthesize")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.purple.opacity(0.12))
                                    .foregroundColor(.purple)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("simulation.resynthesize.button")
                                .disabled(primaryResult == nil || geminiResult == nil)
                            }

                            if let error = viewModel.resynthError {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    Text(error)
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                }
                                .padding(8)
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }

                    // Re-synthesis result
                    if let resynthResult = viewModel.resynthResult {
                        SimulationResynthesisResultView(result: resynthResult)
                    }
                }
                .padding(12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.indigo.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("simulation.panel")
    }
}
