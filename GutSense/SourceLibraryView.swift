//
//  SourceLibraryView.swift
//  GutSense
//
//  Created by Zahirudeen Premji on 3/5/26.
//

import SwiftUI
import SwiftData

struct SourceLibraryView: View {
    @Query var sources: [UserSourceRecord]
    @Environment(\.modelContext) var context
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List(sources) { source in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(source.title)
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        if source.isAnecdotal {
                            Text("💬 Anecdotal")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        } else {
                            Text("🔬 Source")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    Text(source.rawText.prefix(80) + "…")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .navigationTitle("Source Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddSourceSheet()
            }
            .overlay {
                if sources.isEmpty {
                    ContentUnavailableView(
                        "No Sources Added",
                        systemImage: "books.vertical",
                        description: Text("Add URLs, research links, or personal observations to improve analysis.")
                    )
                }
            }
        }
    }
}