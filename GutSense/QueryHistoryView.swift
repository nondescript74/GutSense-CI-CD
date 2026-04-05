//
//  QueryHistoryView.swift
//  GutSense
//
//  Created by Zahirudeen Premji on 3/5/26.
//

import SwiftUI
import SwiftData

struct QueryHistoryView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var queryViewModel: QueryViewModel
    @Query(sort: \FoodQueryRecord.timestamp, order: .reverse) var records: [FoodQueryRecord]
    
    @State private var selectedRecords: Set<UUID> = []
    @State private var isSelecting = false

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "No Queries Yet",
                        systemImage: "clock",
                        description: Text("Your analysis history will appear here.")
                    )
                } else {
                    List(selection: $selectedRecords) {
                        ForEach(records) { record in
                            NavigationLink(value: record) {
                                HistoryRowView(record: record, isSelecting: isSelecting)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteRecord(record)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .environment(\.editMode, isSelecting ? .constant(.active) : .constant(.inactive))
                }
            }
            .navigationTitle("Query History")
            .navigationDestination(for: FoodQueryRecord.self) { record in
                if record.isComplete {
                    // Complete analysis - show results
                    if let claude = record.loadClaudeResult(),
                       let gemini = record.loadGeminiResult(),
                       let apple = record.loadAppleResult() {
                        HistoryResultsWrapper(
                            query: record.queryText,
                            claudeResult: claude,
                            geminiResult: gemini,
                            appleResult: apple,
                            servingInfo: record.servingInfo
                        )
                    } else {
                        Text("Unable to load saved results")
                    }
                } else {
                    // Incomplete analysis - offer to resume
                    IncompleteAnalysisView(record: record)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !records.isEmpty {
                        if isSelecting {
                            Button("Done") {
                                isSelecting = false
                                selectedRecords.removeAll()
                            }
                        } else {
                            Menu {
                                Button {
                                    isSelecting = true
                                } label: {
                                    Label("Select", systemImage: "checkmark.circle")
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    deleteAllRecords()
                                } label: {
                                    Label("Delete All", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .bottomBar) {
                    if isSelecting && !selectedRecords.isEmpty {
                        Button {
                            rerunSelected()
                        } label: {
                            Label("Re-run \(selectedRecords.count)", systemImage: "arrow.clockwise")
                        }
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            deleteSelected()
                        } label: {
                            Label("Delete \(selectedRecords.count)", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func deleteRecord(_ record: FoodQueryRecord) {
        context.delete(record)
        try? context.save()
    }
    
    private func deleteSelected() {
        for id in selectedRecords {
            if let record = records.first(where: { $0.id == id }) {
                context.delete(record)
            }
        }
        try? context.save()
        selectedRecords.removeAll()
        isSelecting = false
    }
    
    private func deleteAllRecords() {
        for record in records {
            context.delete(record)
        }
        try? context.save()
    }
    
    private func rerunSelected() {
        // Re-run the first selected query
        guard let firstId = selectedRecords.first,
              let record = records.first(where: { $0.id == firstId }) else { return }
        
        // Set the query text and switch to Analyze tab
        queryViewModel.textQuery = record.queryText
        queryViewModel.inputMode = .text
        
        // Clear selection and exit selection mode
        selectedRecords.removeAll()
        isSelecting = false
        
        // TODO: Programmatically switch to Analyze tab
        // This would require tab selection binding from ContentView
    }
}

// MARK: - History Results Wrapper (owns a SimulationViewModel for saved analyses)

struct HistoryResultsWrapper: View {
    let query: String
    let claudeResult: AgentResult
    let geminiResult: AgentResult
    let appleResult: SynthesisResult
    let servingInfo: String?

    @StateObject private var simulationVM = SimulationViewModel()

    var body: some View {
        ThreePaneResultsView(
            query: query,
            claudeResult: claudeResult,
            geminiResult: geminiResult,
            appleResult: appleResult,
            servingInfo: servingInfo,
            appleService: AppleFoundationModelService.shared,
            simulationVM: simulationVM
        )
        .navigationTitle("Saved Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            simulationVM.initialize(
                primaryResult: claudeResult,
                geminiResult: geminiResult,
                baselineProb: appleResult.finalIBSProbability
            )
        }
    }
}

// MARK: - Incomplete Analysis View

struct IncompleteAnalysisView: View {
    let record: FoodQueryRecord
    @EnvironmentObject var queryViewModel: QueryViewModel
    @Environment(\.dismiss) private var dismiss
    
    private var hasClaudeResult: Bool {
        record.loadClaudeResult() != nil
    }
    
    private var hasGeminiResult: Bool {
        record.loadGeminiResult() != nil
    }
    
    private var hasAppleResult: Bool {
        record.loadAppleResult() != nil
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Warning icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Incomplete Analysis")
                .font(.title2.weight(.bold))
            
            Text("This analysis was interrupted before completing. Some results may be available.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Show what's available
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: hasClaudeResult ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(hasClaudeResult ? .green : .red)
                    Text("Claude Analysis")
                    Spacer()
                }
                
                HStack {
                    Image(systemName: hasGeminiResult ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(hasGeminiResult ? .green : .red)
                    Text("Gemini Analysis")
                    Spacer()
                }
                
                HStack {
                    Image(systemName: hasAppleResult ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(hasAppleResult ? .green : .red)
                    Text("Apple Synthesis")
                    Spacer()
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            // Actions
            VStack(spacing: 12) {
                if hasClaudeResult || hasGeminiResult {
                    Button {
                        resumeAnalysis()
                    } label: {
                        Label("Resume Analysis", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                Button {
                    restartAnalysis()
                } label: {
                    Label("Start Over", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .navigationTitle("Incomplete Analysis")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func resumeAnalysis() {
        // Load partial results into view model
        queryViewModel.textQuery = record.queryText
        queryViewModel.inputMode = .text
        
        if let claude = record.loadClaudeResult() {
            queryViewModel.claudeResult = claude
            queryViewModel.claudeComplete = true
        }
        
        if let gemini = record.loadGeminiResult() {
            queryViewModel.geminiResult = gemini
            queryViewModel.geminiComplete = true
        }
        
        if let apple = record.loadAppleResult() {
            queryViewModel.appleResult = apple
            queryViewModel.appleComplete = true
        }
        
        // Set the current record so it updates in place
        queryViewModel.currentQueryRecord = record
        
        // Trigger resume
        Task {
            await queryViewModel.resumeAnalysis()
        }
        
        dismiss()
    }
    
    private func restartAnalysis() {
        queryViewModel.textQuery = record.queryText
        queryViewModel.inputMode = .text
        dismiss()
    }
}

// MARK: - History Row View

struct HistoryRowView: View {
    let record: FoodQueryRecord
    let isSelecting: Bool
    
    private var riskColor: Color {
        if record.ibsProbabilityGemini > 0.65 { return .red }
        if record.ibsProbabilityGemini > 0.35 { return .orange }
        return .green
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.queryText)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                
                if !record.isComplete {
                    Spacer()
                    Text("INCOMPLETE")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(4)
                }
            }
            
            HStack(spacing: 12) {
                // Timestamp
                Label(
                    record.timestamp.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "clock"
                )
                .font(.caption2)
                .foregroundColor(.secondary)
                
                // Serving info if available
                if let serving = record.servingInfo {
                    Label(serving, systemImage: "scalemass")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Risk indicator (only show if complete)
                if record.isComplete {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(riskColor)
                            .frame(width: 6, height: 6)
                        Text("\(Int(record.ibsProbabilityGemini * 100))%")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(riskColor)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

