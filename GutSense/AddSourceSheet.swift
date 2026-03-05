//
//  AddSourceSheet.swift
//  GutSense
//
//  Created by Zahirudeen Premji on 3/5/26.
//

import SwiftUI
import SwiftData

struct AddSourceSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context
    @State private var title = ""
    @State private var text = ""
    @State private var url = ""
    @State private var isAnecdotal = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Source Details") {
                    TextField("Title (e.g. Beets and Crohn's — friend's tip)", text: $title)
                    Toggle("Personal / Anecdotal", isOn: $isAnecdotal)
                }
                Section("Content") {
                    TextEditor(text: $text)
                        .frame(minHeight: 100)
                }
                Section("Optional URL") {
                    TextField("https://…", text: $url)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section {
                    Text(isAnecdotal
                         ? "⚠️ Anecdotal sources widen confidence intervals by ±18% per safety rules."
                         : "Peer-reviewed or clinical sources use standard confidence intervals.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !title.isEmpty, !text.isEmpty else { return }
                        let record = UserSourceRecord(
                            title: title, rawText: text, isAnecdotal: isAnecdotal,
                            sourceURL: url.isEmpty ? nil : url
                        )
                        context.insert(record)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty || text.isEmpty)
                }
            }
        }
    }
}