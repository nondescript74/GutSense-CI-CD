//
//  ServingAmountView.swift
//  GutSense
//
//  Serving size selector — shows below the food input
//  Produces a fraction (0.25–2.0) and optional description string

import SwiftUI
import Combine

// MARK: - Serving Preset

struct ServingPreset: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let fraction: Double
    let description: String
}

extension ServingPreset {
    static let presets: [ServingPreset] = [
        ServingPreset(label: "¼",   fraction: 0.25, description: "Quarter serving"),
        ServingPreset(label: "½",   fraction: 0.50, description: "Half serving"),
        ServingPreset(label: "¾",   fraction: 0.75, description: "Three-quarter serving"),
        ServingPreset(label: "1×",  fraction: 1.00, description: "Standard serving"),
        ServingPreset(label: "1½",  fraction: 1.50, description: "One and a half servings"),
        ServingPreset(label: "2×",  fraction: 2.00, description: "Double serving"),
    ]

    static var standard: ServingPreset { presets[3] }
}

// MARK: - Serving Amount View Model

@MainActor
final class ServingViewModel: ObservableObject {
    @Published var selectedPreset: ServingPreset = .standard
    @Published var customGrams: String = ""
    @Published var useCustomGrams: Bool = false
    @Published var servingDescription: String = ""

    var fraction: Double { selectedPreset.fraction }

    var servingAmountG: Double? {
        guard useCustomGrams, let g = Double(customGrams), g > 0 else { return nil }
        return g
    }

    var summaryLabel: String {
        if useCustomGrams, let g = servingAmountG {
            return "\(Int(g))g consumed"
        }
        let pct = Int(selectedPreset.fraction * 100)
        return "\(selectedPreset.label) serving (\(pct)%)"
    }

    var isStandardServing: Bool {
        selectedPreset.fraction == 1.0 && !useCustomGrams
    }

    var riskModifierLabel: String? {
        guard !isStandardServing else { return nil }
        if selectedPreset.fraction < 1.0 {
            let reduction = Int((1.0 - selectedPreset.fraction) * 100)
            return "~\(reduction)% lower FODMAP load"
        } else {
            let increase = Int((selectedPreset.fraction - 1.0) * 100)
            return "~\(increase)% higher FODMAP load"
        }
    }
}

// MARK: - Serving Amount View

struct ServingAmountView: View {
    @ObservedObject var vm: ServingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "scalemass.fill")
                    .foregroundColor(.accentColor)
                    .font(.subheadline)
                Text("How much are you consuming?")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(vm.summaryLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.accentColor)
            }

            // Preset fraction buttons
            HStack(spacing: 6) {
                ForEach(ServingPreset.presets) { preset in
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            vm.selectedPreset = preset
                            vm.useCustomGrams = false
                        }
                    } label: {
                        Text(preset.label)
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(vm.selectedPreset == preset && !vm.useCustomGrams
                                        ? Color.accentColor
                                        : Color(.secondarySystemBackground))
                            .foregroundColor(vm.selectedPreset == preset && !vm.useCustomGrams
                                             ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Optional custom grams row
            HStack(spacing: 8) {
                Toggle("Exact grams", isOn: $vm.useCustomGrams)
                    .font(.caption)
                    .toggleStyle(.button)
                    .tint(.accentColor)

                if vm.useCustomGrams {
                    HStack(spacing: 4) {
                        TextField("e.g. 45", text: $vm.customGrams)
                            .keyboardType(.decimalPad)
                            .font(.caption.monospaced())
                            .frame(width: 70)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text("g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }

                Spacer()

                // Optional description
                TextField("e.g. two slices", text: $vm.servingDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 120)
            }

            // Risk modifier hint
            if let modifier = vm.riskModifierLabel {
                HStack(spacing: 4) {
                    Image(systemName: vm.selectedPreset.fraction < 1.0
                          ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.caption2)
                        .foregroundColor(vm.selectedPreset.fraction < 1.0 ? .green : .orange)
                    Text(modifier)
                        .font(.caption2)
                        .foregroundColor(vm.selectedPreset.fraction < 1.0 ? .green : .orange)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.15)))
        .animation(.easeInOut(duration: 0.2), value: vm.useCustomGrams)
    }
}

// MARK: - Preview

#Preview {
    ServingAmountView(vm: ServingViewModel())
        .padding()
}
