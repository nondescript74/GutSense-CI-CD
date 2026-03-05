//
//  StrongGutClipView.swift
//  StrongGut App Clip
//
//  Created by Zahirudeen Premji on 3/5/26.
//

import SwiftUI

/// Simplified App Clip experience for quick FODMAP analysis
/// Shows the core "analyze food" flow without full app features
struct StrongGutClipView: View {
    @EnvironmentObject var credentialsStore: CredentialsStore
    @StateObject private var queryViewModel = QueryViewModel()
    @State private var textQuery: String = ""
    @State private var showResults = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color.accentColor.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Hero section
                        VStack(spacing: 12) {
                            Image(systemName: "flask.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.accentColor, .accentColor.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .padding(.top, 20)
                            
                            Text("Know what's safe. Before you eat.")
                                .font(.title2.weight(.bold))
                                .multilineTextAlignment(.center)
                            
                            Text("FODMAP food safety analysis for IBS patients")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)
                        
                        // Input section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What are you eating?")
                                .font(.headline)
                            
                            TextEditor(text: $textQuery)
                                .font(.body)
                                .frame(minHeight: 100, maxHeight: 160)
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            
                            if textQuery.isEmpty {
                                Text("Example: \"Garlic bread with olive oil\"")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Analyze button
                        Button {
                            Task {
                                queryViewModel.textQuery = textQuery
                                await queryViewModel.analyze()
                                showResults = true
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if queryViewModel.phase.isRunning {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                        .scaleEffect(0.85)
                                } else {
                                    Image(systemName: "flask.fill")
                                        .font(.subheadline.weight(.semibold))
                                }
                                Text(queryViewModel.phase.isRunning ? "Analyzing…" : "Analyze Food")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                canAnalyze
                                    ? Color.accentColor
                                    : Color.gray.opacity(0.3)
                            )
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!canAnalyze)
                        .padding(.horizontal)
                        
                        // API keys warning if not configured
                        if !credentialsStore.isReadyForAnalysis {
                            VStack(spacing: 8) {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("API keys required to analyze")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(Color.orange.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                
                                Text("Download the full GutSense app to configure your API keys")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal)
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // App Store CTA
                        VStack(spacing: 12) {
                            Text("Get the full experience")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                FeatureRow(icon: "clock.fill", text: "Query history tracking")
                                FeatureRow(icon: "books.vertical.fill", text: "Custom source library")
                                FeatureRow(icon: "camera.fill", text: "Photo & barcode scanning")
                                FeatureRow(icon: "gearshape.fill", text: "Personalized settings")
                            }
                            .padding(.horizontal)
                            
                            Button {
                                // Open App Store or deep link to full app
                                if let url = URL(string: "https://apps.apple.com/app/gutsense") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Download GutSense")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Strong Gut")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showResults) {
                if let appleResult = queryViewModel.appleResult,
                   let claudeResult = queryViewModel.claudeResult,
                   let geminiResult = queryViewModel.geminiResult {
                    ThreePaneResultsView(
                        query: textQuery,
                        appleResult: appleResult,
                        claudeResult: claudeResult,
                        geminiResult: geminiResult,
                        servingInfo: queryViewModel.servingViewModel.summaryLabel,
                        appleService: AppleFoundationModelService.shared
                    )
                } else {
                    Text("Loading results...")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var canAnalyze: Bool {
        !textQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !queryViewModel.phase.isRunning &&
        credentialsStore.isReadyForAnalysis
    }
}

/// Feature list row for App Store CTA section
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

extension UserProfile {
    static let `default` = UserProfile()
}
