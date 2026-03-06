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
                if let claude = record.loadClaudeResult(),
                   let gemini = record.loadGeminiResult(),
                   let apple = record.loadAppleResult() {
                    // Note: Historical data has old structure (Apple as agent, Gemini as synthesis)
                    // We'll display it as-is for historical records
                    ThreePaneResultsView(
                        query: record.queryText,
                        claudeResult: claude,
                        geminiResult: gemini,
                        appleResult: apple,
                        servingInfo: record.servingInfo,
                        appleService: AppleFoundationModelService.shared
                    )
                    .navigationTitle("Saved Analysis")
                    .navigationBarTitleDisplayMode(.inline)
                } else {
                    Text("Unable to load saved results")
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
            Text(record.queryText)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
            
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
                
                // Risk indicator
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
        .padding(.vertical, 4)
    }
}

