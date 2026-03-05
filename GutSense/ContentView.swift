//
//  ContentView.swift
//  GutSense
//
//  Created by Zahirudeen Premji on 3/5/26.
//

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
