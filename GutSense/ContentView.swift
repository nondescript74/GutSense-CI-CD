//
//  ContentView.swift
//  GutSense
//
//  Created by Zahirudeen Premji on 3/5/26.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Content View (Tab Navigation)

struct ContentView: View {
    @EnvironmentObject var credentialsStore: CredentialsStore
    @Query private var profile: [UserProfileRecord]
    @Query private var sources: [UserSourceRecord]
    @StateObject private var queryViewModel = QueryViewModel()

    var resolvedProfile: UserProfile {
        profile.first?.toModel() ?? .default
    }

    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("UI-TESTING-SIMULATION") {
            SimulationUITestRootView()
        } else {
            TabView {
                Tab("Analyze", systemImage: "flask.fill") {
                    QueryInputView(
                        viewModel: queryViewModel,
                        userProfile: resolvedProfile,
                        userSources: sources.map { $0.toModel() }
                    )
                }

                Tab("History", systemImage: "clock.fill") {
                    QueryHistoryView()
                        .environmentObject(queryViewModel)
                }

                Tab("Sources", systemImage: "books.vertical.fill") {
                    SourceLibraryView()
                }

                Tab("Settings", systemImage: "gearshape.fill") {
                    SettingsView()
                }
            }
            .tint(.accentColor)
        }
    }
}

private struct SimulationUITestRootView: View {
    @StateObject private var simulationVM = SimulationViewModel()
    private let claudeResult = AgentResult.claudeMock
    private let geminiResult = AgentResult.geminiMock
    private let synthesisResult = SynthesisResult.appleSynthesisMock

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                ThreePaneResultsView(
                    query: "UI Testing Meal",
                    claudeResult: claudeResult,
                    geminiResult: geminiResult,
                    appleResult: synthesisResult,
                    servingInfo: "1× serving (100%)",
                    appleService: AppleFoundationModelService.shared,
                    simulationVM: simulationVM
                )

                Text("Simulation UI Test")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("simulation.ui.root")
            }
            .onAppear {
                if simulationVM.ingredients.isEmpty {
                    simulationVM.initialize(
                        primaryResult: claudeResult,
                        geminiResult: geminiResult,
                        synthesisResult: synthesisResult,
                        baselineProb: synthesisResult.finalIBSProbability,
                        query: "UI Testing Meal"
                    )
                }
                simulationVM.isOpen = true
            }
        }
    }
}
