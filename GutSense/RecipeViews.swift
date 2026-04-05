//
//  RecipeViews.swift
//  GutSense
//
//  Recipe URL input, extraction result, and saved recipe list views.
//

import SwiftUI
import Combine

// MARK: - Recipe View Model

@MainActor
final class RecipeViewModel: ObservableObject {

    enum Phase: Equatable {
        case idle
        case extracting
        case extracted
        case savingFull
        case saved
        case analyzing       // Full 3-agent FODMAP pipeline running
        case analysisComplete // Three-pane results ready
        case failed(String)

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.extracting, .extracting), (.extracted, .extracted),
                 (.savingFull, .savingFull), (.saved, .saved),
                 (.analyzing, .analyzing), (.analysisComplete, .analysisComplete):
                return true
            case (.failed(let a), .failed(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    @Published var urlText: String = ""
    @Published var phase: Phase = .idle
    @Published var extractResult: RecipeExtractResult?
    @Published var fullDetails: RecipeFullDetails?
    @Published var savedRecipes: [SavedRecipe] = []

    // Three-pane analysis results
    @Published var claudeResult: AgentResult = AgentResult.loading(for: .claude)
    @Published var geminiResult: AgentResult = AgentResult.loading(for: .gemini)
    @Published var appleResult: SynthesisResult = .loading
    @Published var claudeComplete = false
    @Published var geminiComplete = false
    @Published var appleComplete = false

    private let api = BackendAPIService.shared

    var canExtract: Bool {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && (trimmed.contains(".") || trimmed.hasPrefix("http"))
    }

    /// The ingredient query string built from extracted ingredients.
    private var ingredientQuery: String {
        extractResult?.ingredients.joined(separator: ", ") ?? ""
    }

    // MARK: - Extract ingredients + images from URL

    func extract() async {
        guard canExtract else { return }
        phase = .extracting
        do {
            let result = try await api.extractRecipe(url: urlText)
            extractResult = result
            phase = .extracted
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: - Save Full Recipe + Run 3-Agent FODMAP Analysis

    func saveAndAnalyze(profile: UserProfile) async {
        guard let result = extractResult else { return }
        phase = .savingFull

        // Step 1: Extract full recipe details and save
        do {
            let full = try await api.extractFullRecipe(url: result.url, pageHash: result.pageHash)
            fullDetails = full

            let saveReq = RecipeSaveRequestDTO(
                url: result.url,
                title: full.title.isEmpty ? result.title : full.title,
                ingredients: full.ingredients.isEmpty ? result.ingredients : full.ingredients,
                images: result.images.map { RecipeImageDTO(url: $0.url, alt: $0.alt, width: $0.width, height: $0.height) },
                instructions: full.instructions,
                prep_time: full.prepTime,
                cook_time: full.cookTime,
                servings: full.servings,
                page_hash: result.pageHash
            )
            _ = try await api.saveRecipe(saveReq)
            phase = .saved
            await loadSavedRecipes()
        } catch {
            phase = .failed("Save failed: \(error.localizedDescription)")
            return
        }

        // Step 2: Run full 3-agent FODMAP analysis
        phase = .analyzing
        claudeComplete = false
        geminiComplete = false
        appleComplete = false
        claudeResult = AgentResult.loading(for: .claude)
        geminiResult = AgentResult.loading(for: .gemini)
        appleResult = .loading

        let query = "FODMAP analysis of recipe ingredients: \(ingredientQuery)"

        // Claude + Gemini in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.runClaude(query: query, profile: profile) }
            group.addTask { await self.runGemini(query: query, profile: profile) }
        }

        // Apple synthesis
        await runAppleSynthesis(query: query, profile: profile)

        phase = .analysisComplete
    }

    // MARK: - Claude Agent

    private func runClaude(query: String, profile: UserProfile) async {
        do {
            let result = try await api.analyzeClaude(query: query, profile: profile)
            claudeResult = result
            claudeComplete = true
        } catch {
            claudeResult = AgentResult.error(for: .claude, message: error.localizedDescription)
            claudeComplete = true
        }
    }

    // MARK: - Gemini Agent

    private func runGemini(query: String, profile: UserProfile) async {
        do {
            let result = try await api.analyzeGemini(query: query, profile: profile)
            geminiResult = result
            geminiComplete = true
        } catch {
            geminiResult = AgentResult.error(for: .gemini, message: error.localizedDescription)
            geminiComplete = true
        }
    }

    // MARK: - Apple Synthesis

    private func runAppleSynthesis(query: String, profile: UserProfile) async {
        let appleService = AppleFoundationModelService.shared
        guard appleService.isAvailable else {
            // Fall back to Gemini synthesis via backend
            await runGeminiSynthesis(query: query, profile: profile)
            return
        }

        guard let claudeJSON = encodeAgentResult(claudeResult),
              let geminiJSON = encodeAgentResult(geminiResult) else {
            appleResult = SynthesisResult.error(message: "Agent result encoding failed.")
            appleComplete = true
            return
        }

        do {
            let result = try await appleService.synthesizeResults(
                query: query,
                profile: profile,
                sources: [],
                claudeJSON: claudeJSON,
                geminiJSON: geminiJSON
            )
            appleResult = result
            appleComplete = true
        } catch {
            // Fall back to Gemini synthesis
            await runGeminiSynthesis(query: query, profile: profile)
        }
    }

    private func runGeminiSynthesis(query: String, profile: UserProfile) async {
        guard let claudeJSON = encodeAgentResult(claudeResult) else {
            appleResult = SynthesisResult.error(message: "Could not encode results for synthesis.")
            appleComplete = true
            return
        }
        do {
            let result = try await api.synthesizeGemini(
                query: query,
                profile: profile,
                appleResultJSON: claudeJSON
            )
            appleResult = result
            appleComplete = true
        } catch {
            appleResult = SynthesisResult.error(message: error.localizedDescription)
            appleComplete = true
        }
    }

    private func encodeAgentResult(_ result: AgentResult) -> String? {
        let dto = AgentResultDTO.from(result)
        guard let data = try? JSONEncoder().encode(dto) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Load saved recipes

    func loadSavedRecipes() async {
        do {
            savedRecipes = try await api.listRecipes()
        } catch {
            print("Failed to load recipes: \(error)")
        }
    }

    // MARK: - Delete recipe

    func deleteRecipe(_ id: String) async {
        do {
            try await api.deleteRecipe(id: id)
            savedRecipes.removeAll { $0.id == id }
        } catch {
            print("Failed to delete recipe: \(error)")
        }
    }

    // MARK: - Reset

    func reset() {
        urlText = ""
        phase = .idle
        extractResult = nil
        fullDetails = nil
        claudeResult = AgentResult.loading(for: .claude)
        geminiResult = AgentResult.loading(for: .gemini)
        appleResult = .loading
        claudeComplete = false
        geminiComplete = false
        appleComplete = false
    }
}

// MARK: - Recipe URL Input View

struct RecipeURLInputView: View {
    @ObservedObject var viewModel: RecipeViewModel
    let userProfile: UserProfile

    var body: some View {
        VStack(spacing: 16) {
            // URL input
            VStack(alignment: .leading, spacing: 8) {
                Text("Recipe URL")
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 8) {
                    Image(systemName: "link")
                        .foregroundColor(.secondary)

                    TextField("https://example.com/recipe", text: $viewModel.urlText)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textContentType(.URL)
                        .accessibilityIdentifier("recipe.urlField")

                    if !viewModel.urlText.isEmpty {
                        Button {
                            viewModel.urlText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Paste from clipboard
                Button {
                    if let clip = UIPasteboard.general.string {
                        viewModel.urlText = clip
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.caption)
                        Text("Paste from clipboard")
                            .font(.caption)
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }

            // Extract button
            Button {
                Task { await viewModel.extract() }
            } label: {
                HStack(spacing: 8) {
                    if case .extracting = viewModel.phase {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "fork.knife")
                    }
                    Text(viewModel.phase.isExtracting ? "Extracting..." : "Extract Recipe")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(viewModel.canExtract ? Color.accentColor : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canExtract || viewModel.phase.isExtracting)
            .accessibilityIdentifier("recipe.extractButton")

            // Error
            if case .failed(let msg) = viewModel.phase {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(8)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Recipe Extraction Result View

struct RecipeExtractionResultView: View {
    @ObservedObject var viewModel: RecipeViewModel
    let userProfile: UserProfile

    var body: some View {
        if let result = viewModel.extractResult {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(result.title)
                        .font(.headline)
                        .lineLimit(2)
                }

                // Extraction method badge
                HStack(spacing: 4) {
                    Image(systemName: result.extractionMethod == "schema_org" ? "doc.text" : "brain")
                        .font(.caption2)
                    Text(result.extractionMethod == "schema_org" ? "Schema.org" : "AI Extracted")
                        .font(.caption2.weight(.medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(Capsule())

                // Images
                if !result.images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(result.images) { img in
                                AsyncImage(url: URL(string: img.url)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    case .failure:
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 100, height: 100)
                                            .overlay(Image(systemName: "photo")
                                                .foregroundColor(.secondary))
                                    default:
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.1))
                                            .frame(width: 100, height: 100)
                                            .overlay(ProgressView().scaleEffect(0.6))
                                    }
                                }
                            }
                        }
                    }
                }

                // Ingredients
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ingredients (\(result.ingredients.count))")
                        .font(.subheadline.weight(.semibold))

                    ForEach(Array(result.ingredients.enumerated()), id: \.offset) { _, ingredient in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(ingredient)
                                .font(.caption)
                        }
                    }
                }

                // Save & Analyze button (replaces separate FODMAP + Save buttons)
                if case .saved = viewModel.phase {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Recipe saved — analyzing...")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.green)
                    }
                } else if case .savingFull = viewModel.phase {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                        Text("Saving full recipe...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if case .analyzing = viewModel.phase {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.7)
                            Text("Running FODMAP analysis...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        // Show agent progress
                        HStack(spacing: 12) {
                            agentStatusDot("Claude", done: viewModel.claudeComplete)
                            agentStatusDot("Gemini", done: viewModel.geminiComplete)
                            agentStatusDot("Synthesis", done: viewModel.appleComplete)
                        }
                    }
                } else if case .analysisComplete = viewModel.phase {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Analysis complete — see results below")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.green)
                    }
                } else {
                    Button {
                        Task { await viewModel.saveAndAnalyze(profile: userProfile) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save & Analyze Recipe")
                                .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundColor(.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func agentStatusDot(_ name: String, done: Bool) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(done ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Recipe Tab View (combines input + results + three-pane + list)

struct RecipeTabView: View {
    @StateObject private var viewModel = RecipeViewModel()
    @StateObject private var simulationVM = SimulationViewModel()
    let userProfile: UserProfile

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Only show input + extraction when not viewing full results
                    if viewModel.phase != .analysisComplete {
                        RecipeURLInputView(viewModel: viewModel, userProfile: userProfile)
                        RecipeExtractionResultView(viewModel: viewModel, userProfile: userProfile)
                    }

                    // Three-pane results after analysis completes
                    if viewModel.phase == .analysisComplete {
                        // New analysis button
                        Button {
                            viewModel.reset()
                            simulationVM.reset()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("New Recipe")
                                    .font(.caption.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)

                        ThreePaneResultsView(
                            query: "Recipe: \(viewModel.extractResult?.title ?? "")",
                            claudeResult: viewModel.claudeResult,
                            geminiResult: viewModel.geminiResult,
                            appleResult: viewModel.appleResult,
                            servingInfo: viewModel.fullDetails?.servings,
                            userProfile: userProfile,
                            appleService: AppleFoundationModelService.shared,
                            simulationVM: simulationVM
                        )
                    }

                    // Saved recipes section
                    if !viewModel.savedRecipes.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Saved Recipes")
                                    .font(.headline)
                                Spacer()
                                Text("\(viewModel.savedRecipes.count)")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15))
                                    .foregroundColor(.accentColor)
                                    .clipShape(Capsule())
                            }

                            ForEach(viewModel.savedRecipes) { recipe in
                                NavigationLink(value: recipe.id) {
                                    SavedRecipeRow(recipe: recipe)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: String.self) { recipeId in
                if let recipe = viewModel.savedRecipes.first(where: { $0.id == recipeId }) {
                    SavedRecipeDetailView(recipe: recipe, viewModel: viewModel)
                }
            }
            .task {
                await viewModel.loadSavedRecipes()
            }
            .refreshable {
                await viewModel.loadSavedRecipes()
            }
        }
    }
}

// MARK: - Saved Recipe Row

struct SavedRecipeRow: View {
    let recipe: SavedRecipe

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let firstImage = recipe.images.first, let imgURL = URL(string: firstImage.url) {
                AsyncImage(url: imgURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 50, height: 50)
                            .overlay(Image(systemName: "fork.knife")
                                .font(.caption)
                                .foregroundColor(.secondary))
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .overlay(Image(systemName: "fork.knife")
                        .font(.caption)
                        .foregroundColor(.secondary))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text("\(recipe.ingredients.count) ingredients")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(recipe.savedAt, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Saved Recipe Detail View

struct SavedRecipeDetailView: View {
    let recipe: SavedRecipe
    @ObservedObject var viewModel: RecipeViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Images
                if !recipe.images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(recipe.images) { img in
                                AsyncImage(url: URL(string: img.url)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 200, height: 150)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    default:
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.15))
                                            .frame(width: 200, height: 150)
                                    }
                                }
                            }
                        }
                    }
                }

                // Meta info
                if recipe.prepTime != nil || recipe.cookTime != nil || recipe.servings != nil {
                    HStack(spacing: 16) {
                        if let prep = recipe.prepTime {
                            Label(prep, systemImage: "clock")
                                .font(.caption)
                        }
                        if let cook = recipe.cookTime {
                            Label(cook, systemImage: "flame")
                                .font(.caption)
                        }
                        if let servings = recipe.servings {
                            Label(servings, systemImage: "person.2")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.secondary)
                }

                // Ingredients
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ingredients (\(recipe.ingredients.count))")
                        .font(.subheadline.weight(.semibold))

                    ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, ingredient in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .foregroundColor(.accentColor)
                            Text(ingredient)
                                .font(.subheadline)
                        }
                    }
                }

                // Instructions
                if !recipe.instructions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instructions")
                            .font(.subheadline.weight(.semibold))

                        ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { idx, step in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(idx + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.white)
                                    .frame(width: 22, height: 22)
                                    .background(Color.accentColor)
                                    .clipShape(Circle())
                                Text(step)
                                    .font(.subheadline)
                            }
                        }
                    }
                }

                // Source URL
                if let url = URL(string: recipe.url) {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                            Text("View original recipe")
                                .font(.caption)
                        }
                        .foregroundColor(.accentColor)
                    }
                }

                // Delete button
                Button(role: .destructive) {
                    Task {
                        await viewModel.deleteRecipe(recipe.id)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Delete Recipe")
                            .font(.caption.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.08))
                    .foregroundColor(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Phase Helpers

extension RecipeViewModel.Phase {
    var isExtracting: Bool {
        if case .extracting = self { return true }
        return false
    }
}
