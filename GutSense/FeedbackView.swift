// FeedbackView.swift
// Strong Gut – Anonymous Analysis Feedback
// Drop-in SwiftUI sheet component

import SwiftUI
import Combine

// MARK: - Data Model

enum AnalysisType: String, CaseIterable {
    case apple  = "Apple"
    case claude = "Claude"
    case gemini = "Gemini"
}

enum FeedbackReason: String, CaseIterable, Identifiable {
    case tooGeneral   = "Too general"
    case notAccurate  = "Not accurate"
    case veryHelpful  = "Very helpful"
    case needsDetail  = "Needs more detail"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .tooGeneral:  return "text.magnifyingglass"
        case .notAccurate: return "exclamationmark.triangle"
        case .veryHelpful: return "star"
        case .needsDetail: return "list.bullet.indent"
        }
    }
}

struct FeedbackPayload: Codable {
    let anonymousID: String
    let foodItem: String
    let selectedAnalysis: String
    let thumbsUp: Bool
    let reason: String
    let timestamp: Date
}

// MARK: - ViewModel

@MainActor
class FeedbackViewModel: ObservableObject {
    @Published var selectedAnalysis: AnalysisType = .claude
    @Published var thumbsUp: Bool? = nil
    @Published var selectedReason: FeedbackReason? = nil
    @Published var submitted = false
    @Published var isSubmitting = false

    /// Persistent anonymous device ID — never contains PII
    static let anonymousID: String = {
        let key = "gut.anonymous.id"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }()

    var canSubmit: Bool { thumbsUp != nil && selectedReason != nil }

    func submit(foodItem: String, backendURL: String) async {
        guard canSubmit, let thumbsUp, let reason = selectedReason else { return }
        isSubmitting = true

        let payload = FeedbackPayload(
            anonymousID: Self.anonymousID,
            foodItem: foodItem,
            selectedAnalysis: selectedAnalysis.rawValue,
            thumbsUp: thumbsUp,
            reason: reason.rawValue,
            timestamp: Date()
        )

        do {
            guard let url = URL(string: "\(backendURL)/feedback") else { return }
            var req = URLRequest(url: url)
            req.httpMethod  = "POST"
            req.httpBody    = try JSONEncoder().encode(payload)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            _ = try await URLSession.shared.data(for: req)
        } catch {
            // Silent fail — feedback is best-effort
            print("Feedback error: \(error.localizedDescription)")
        }

        isSubmitting = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            submitted = true
        }
    }
}

// MARK: - Main Feedback Sheet

struct FeedbackView: View {
    let foodItem: String
    let backendURL: String
    var onDismiss: () -> Void

    @StateObject private var vm = FeedbackViewModel()
    @Environment(\.colorScheme) var colorScheme

    private var cardBG: Color {
        colorScheme == .dark
            ? Color(white: 0.12)
            : Color(white: 0.97)
    }

    var body: some View {
        ZStack {
            // Frosted backdrop
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    if vm.submitted {
                        ThanksView(onDismiss: onDismiss)
                    } else {
                        feedbackContent
                    }
                }
                .padding(28)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(cardBG)
                        .shadow(color: .black.opacity(0.25), radius: 30, y: -6)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: Feedback Content

    private var feedbackContent: some View {
        VStack(spacing: 22) {

            // Header
            VStack(spacing: 6) {
                Text("How was this analysis?")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text(foodItem)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Step 1 — Which analysis
            VStack(alignment: .leading, spacing: 12) {
                Label("Which analysis?", systemImage: "brain.head.profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ForEach(AnalysisType.allCases, id: \.self) { type in
                        AnalysisPill(
                            label: type.rawValue,
                            isSelected: vm.selectedAnalysis == type
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                vm.selectedAnalysis = type
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Step 2 — Thumbs
            VStack(alignment: .leading, spacing: 12) {
                Label("Your verdict", systemImage: "hand.raised")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    ThumbButton(isUp: true,  selected: vm.thumbsUp == true)  { withAnimation(.spring(response: 0.3)) { vm.thumbsUp = true  } }
                    ThumbButton(isUp: false, selected: vm.thumbsUp == false) { withAnimation(.spring(response: 0.3)) { vm.thumbsUp = false } }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Step 3 — Reason chips
            VStack(alignment: .leading, spacing: 12) {
                Label("Tell us more", systemImage: "bubble.left.and.bubble.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(FeedbackReason.allCases) { reason in
                        ReasonChip(
                            reason: reason,
                            isSelected: vm.selectedReason == reason
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                vm.selectedReason = reason
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Submit
            Button {
                Task { await vm.submit(foodItem: foodItem, backendURL: backendURL) }
            } label: {
                ZStack {
                    if vm.isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Send Feedback")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(vm.canSubmit ? Color.green : Color.gray.opacity(0.35))
                )
            }
            .disabled(!vm.canSubmit || vm.isSubmitting)
            .animation(.easeInOut(duration: 0.2), value: vm.canSubmit)

            // No-account notice
            HStack(spacing: 5) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 11))
                Text("Anonymous · No account required")
                    .font(.system(size: 11))
            }
            .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Sub-components

struct AnalysisPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.green : Color.gray.opacity(0.15))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct ThumbButton: View {
    let isUp: Bool
    let selected: Bool
    let action: () -> Void

    private var icon: String  { isUp ? "hand.thumbsup.fill"   : "hand.thumbsdown.fill" }
    private var label: String { isUp ? "Helpful"               : "Not helpful" }
    private var accent: Color { isUp ? .green                  : .orange }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? accent.opacity(0.18) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(selected ? accent : Color.clear, lineWidth: 1.5)
                    )
            )
            .foregroundStyle(selected ? accent : .secondary)
            .scaleEffect(selected ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

struct ReasonChip: View {
    let reason: FeedbackReason
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: reason.icon)
                    .font(.system(size: 13))
                Text(reason.rawValue)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.green.opacity(0.15) : Color.gray.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(isSelected ? Color.green : Color.clear, lineWidth: 1.5)
                    )
            )
            .foregroundStyle(isSelected ? Color.green : .secondary)
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

struct ThanksView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: true)

            VStack(spacing: 6) {
                Text("Thanks for the feedback!")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("It helps us make Strong Gut better\nfor everyone.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Done") { onDismiss() }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.green)
                )
                .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - FastAPI Backend Endpoint (reference)
/*
 POST /feedback
 Body: FeedbackPayload (JSON)

 In your Railway FastAPI main.py, add:

 from pydantic import BaseModel
 from datetime import datetime

 class FeedbackPayload(BaseModel):
     anonymousID: str
     foodItem: str
     selectedAnalysis: str
     thumbsUp: bool
     reason: str
     timestamp: datetime

 @app.post("/feedback")
 async def submit_feedback(payload: FeedbackPayload):
     # Log to DB or append to a JSONL file
     print(payload.model_dump_json())
     return {"status": "ok"}
*/

// MARK: - Usage Example
/*
 In your AnalysisResultView:

 @State private var showFeedback = false

 // Attach to any result card:
 .overlay(alignment: .bottomTrailing) {
     Button {
         showFeedback = true
     } label: {
         Label("Feedback", systemImage: "hand.thumbsup")
             .font(.caption)
             .padding(8)
             .background(.ultraThinMaterial, in: Capsule())
     }
     .padding(12)
 }
 .fullScreenCover(isPresented: $showFeedback) {
     FeedbackView(
         foodItem: analysisResult.foodName,
         backendURL: "https://web-production-825a4.up.railway.app",
         onDismiss: { showFeedback = false }
     )
     .background(ClearBackgroundView()) // pass-through for frosted effect
 }
*/


#Preview {
    FeedbackView(
        foodItem: "Garlic bread with olive oil",
        backendURL: "https://web-production-825a4.up.railway.app",
        onDismiss: {}
    )
}
