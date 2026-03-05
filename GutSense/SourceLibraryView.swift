// Strong Gut — SourceLibraryView.swift
// Full source library: add by URL (auto-fetch), manual text, or personal observation
// Sources are injected into Claude + Gemini prompts as RAG context

import SwiftUI
import SwiftData

// MARK: - Source Library View

struct SourceLibraryView: View {
    @Query(sort: \UserSourceRecord.dateAdded, order: .reverse) var sources: [UserSourceRecord]
    @Environment(\.modelContext) var context
    @State private var showAdd = false
    @State private var searchText = ""
    @State private var filterType: SourceFilter = .all

    enum SourceFilter: String, CaseIterable {
        case all        = "All"
        case research   = "Research"
        case anecdotal  = "Personal"
    }

    var filtered: [UserSourceRecord] {
        sources.filter { source in
            let matchesSearch = searchText.isEmpty
                || source.title.localizedCaseInsensitiveContains(searchText)
                || source.rawText.localizedCaseInsensitiveContains(searchText)
            let matchesFilter: Bool = {
                switch filterType {
                case .all:       return true
                case .research:  return !source.isAnecdotal
                case .anecdotal: return source.isAnecdotal
                }
            }()
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sources.isEmpty {
                    emptyState
                } else {
                    sourceList
                }
            }
            .navigationTitle("Source Library")
            .searchable(text: $searchText, prompt: "Search sources…")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    filterPicker
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddSourceSheet()
            }
        }
    }

    // MARK: - Source List

    private var sourceList: some View {
        List {
            // Summary header
            Section {
                HStack(spacing: 16) {
                    StatPill(
                        value: sources.filter { !$0.isAnecdotal }.count,
                        label: "Research",
                        color: .blue,
                        icon: "doc.text.magnifyingglass"
                    )
                    StatPill(
                        value: sources.filter { $0.isAnecdotal }.count,
                        label: "Personal",
                        color: .orange,
                        icon: "person.bubble"
                    )
                    Spacer()
                    Text("Injected into every analysis")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 4)
            }

            // Source rows
            Section {
                if filtered.isEmpty {
                    Text("No sources match your filter.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(filtered) { source in
                        NavigationLink(destination: SourceDetailView(source: source)) {
                            SourceRow(source: source)
                        }
                    }
                    .onDelete(perform: deleteSources)
                }
            } header: {
                Text(filtered.count == sources.count
                     ? "\(sources.count) sources"
                     : "\(filtered.count) of \(sources.count) sources")
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 52))
                .foregroundColor(.accentColor.opacity(0.4))

            VStack(spacing: 6) {
                Text("No Sources Yet")
                    .font(.title3.weight(.semibold))
                Text("Add research links, Monash studies, or\npersonal food observations to improve\nyour FODMAP analysis accuracy.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Seed examples
            VStack(spacing: 10) {
                SeedExampleButton(
                    title: "Monash FODMAP Diet",
                    url: "https://www.monashfodmap.com",
                    isAnecdotal: false,
                    context: context
                )
                SeedExampleButton(
                    title: "My personal trigger observation",
                    url: nil,
                    isAnecdotal: true,
                    context: context,
                    customText: "I notice that even small amounts of onion cause bloating within 2 hours, even below the Monash threshold."
                )
            }
            .padding(.horizontal)

            Button {
                showAdd = true
            } label: {
                Label("Add Your First Source", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(32)
    }

    // MARK: - Filter Picker

    private var filterPicker: some View {
        Menu {
            ForEach(SourceFilter.allCases, id: \.self) { f in
                Button {
                    filterType = f
                } label: {
                    if filterType == f {
                        Label(f.rawValue, systemImage: "checkmark")
                    } else {
                        Text(f.rawValue)
                    }
                }
            }
        } label: {
            Label(filterType.rawValue, systemImage: "line.3.horizontal.decrease.circle")
                .font(.subheadline)
        }
    }

    // MARK: - Delete

    private func deleteSources(at offsets: IndexSet) {
        for i in offsets {
            context.delete(filtered[i])
        }
    }
}

// MARK: - Source Row

struct SourceRow: View {
    let source: UserSourceRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if let url = source.sourceURL, !url.isEmpty {
                        Text(url)
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                            .lineLimit(1)
                    }
                }
                Spacer()
                SourceTypeBadge(isAnecdotal: source.isAnecdotal)
            }

            Text(source.rawText.prefix(120) + (source.rawText.count > 120 ? "…" : ""))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Text(source.dateAdded.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(source.rawText.split(separator: " ").count) words")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Source Detail View

struct SourceDetailView: View {
    let source: UserSourceRecord
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SourceTypeBadge(isAnecdotal: source.isAnecdotal)
                        Spacer()
                        Text(source.dateAdded.formatted(date: .long, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(source.title)
                        .font(.title3.weight(.semibold))

                    if let url = source.sourceURL, !url.isEmpty {
                        Link(url, destination: URL(string: url) ?? URL(string: "https://example.com")!)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Confidence note
                if source.isAnecdotal {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Personal observations widen confidence intervals by ±18% per GutSense safety rules.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Full text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Content")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(source.rawText)
                        .font(.body)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if !source.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        Text(source.notes)
                            .font(.body)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationTitle("Source Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    context.delete(source)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - Add Source Sheet

struct AddSourceSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var context

    @State private var title = ""
    @State private var text = ""
    @State private var url = ""
    @State private var isAnecdotal = false
    @State private var notes = ""
    @State private var isFetching = false
    @State private var fetchError: String?
    @State private var inputMode: InputMode = .url

    enum InputMode: String, CaseIterable {
        case url    = "Fetch URL"
        case manual = "Manual Text"
        case personal = "Personal Note"
    }

    var canSave: Bool {
        !title.isEmpty && !text.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Mode picker
                Section {
                    Picker("Input Type", selection: $inputMode) {
                        ForEach(InputMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: inputMode) { _, new in
                        isAnecdotal = (new == .personal)
                    }
                }

                // URL fetch mode
                if inputMode == .url {
                    Section("URL") {
                        HStack {
                            TextField("https://monashfodmap.com/…", text: $url)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            Button {
                                Task { await fetchURL() }
                            } label: {
                                if isFetching {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Text("Fetch")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .disabled(url.isEmpty || isFetching)
                        }
                    }

                    if let error = fetchError {
                        Section {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                // Title
                Section("Title") {
                    TextField(inputMode == .personal
                              ? "e.g. Onion sensitivity observation"
                              : "e.g. Monash FODMAP garlic study",
                              text: $title)
                }

                // Content
                Section("Content") {
                    TextEditor(text: $text)
                        .frame(minHeight: 120)
                        .font(.body)
                }

                // Notes
                Section("Notes (optional)") {
                    TextField("Any personal context…", text: $notes)
                }

                // Anecdotal toggle (auto-set for personal mode)
                Section {
                    Toggle("Personal / Anecdotal Source", isOn: $isAnecdotal)
                    Text(isAnecdotal
                         ? "⚠️ Widens confidence intervals ±18% — your lived experience matters but carries higher uncertainty."
                         : "✅ Research sources use standard confidence intervals from Monash / PubMed / NICE.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Fetch URL via backend

    private func fetchURL() async {
        guard let backendURL = KeychainService.shared.read(forKey: "gutsense.backend_url"),
              !backendURL.isEmpty else {
            fetchError = "Backend URL not configured. Go to Settings → API Keys."
            return
        }

        isFetching = true
        fetchError = nil

        let clean = backendURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
        let endpoint = "\(clean)/sources/fetch?url=\(encodedURL)&is_anecdotal=\(isAnecdotal)"

        guard let requestURL = URL(string: endpoint) else {
            fetchError = "Invalid URL."
            isFetching = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: requestURL)
            if let json = try? JSONDecoder().decode(FetchedSourceResponse.self, from: data) {
                text = json.text
                if title.isEmpty {
                    title = URL(string: url)?.host ?? url
                }
            } else {
                fetchError = "Could not parse response from server."
            }
        } catch {
            fetchError = "Fetch failed: \(error.localizedDescription)"
        }

        isFetching = false
    }

    private struct FetchedSourceResponse: Decodable {
        let url: String
        let text: String
        let status: String
    }

    // MARK: - Save

    private func save() {
        let record = UserSourceRecord(
            title: title,
            rawText: text,
            isAnecdotal: isAnecdotal,
            sourceURL: url.isEmpty ? nil : url,
            notes: notes
        )
        context.insert(record)
        dismiss()
    }
}

// MARK: - Supporting Views

struct SourceTypeBadge: View {
    let isAnecdotal: Bool
    var body: some View {
        Label(isAnecdotal ? "Personal" : "Research",
              systemImage: isAnecdotal ? "person.bubble.fill" : "doc.text.magnifyingglass")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isAnecdotal ? Color.orange.opacity(0.15) : Color.blue.opacity(0.12))
            .foregroundColor(isAnecdotal ? .orange : .blue)
            .clipShape(Capsule())
    }
}

struct StatPill: View {
    let value: Int
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(.subheadline.weight(.bold))
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SeedExampleButton: View {
    let title: String
    let url: String?
    let isAnecdotal: Bool
    let context: ModelContext
    var customText: String = ""

    @State private var added = false

    var body: some View {
        Button {
            let record = UserSourceRecord(
                title: title,
                rawText: customText.isEmpty
                    ? "Reference source: \(url ?? title). Add full content by tapping the source."
                    : customText,
                isAnecdotal: isAnecdotal,
                sourceURL: url
            )
            context.insert(record)
            added = true
        } label: {
            HStack {
                Image(systemName: added ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundColor(added ? .green : .accentColor)
                Text(title)
                    .font(.subheadline)
                Spacer()
                SourceTypeBadge(isAnecdotal: isAnecdotal)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(added)
    }
}
