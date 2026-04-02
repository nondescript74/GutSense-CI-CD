//
//  SettingsView.swift
//  GutSense
//
//  Created by Zahirudeen Premji on 3/5/26.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Credentials") {
                    NavigationLink("API Keys & Passwords", destination: APIKeysView())
                }
                Section("Providers") {
                    NavigationLink("Primary Provider", destination: APIKeysView())
                }
                Section("Profile") {
                    NavigationLink("IBS Profile & Triggers", destination: IBSProfileView())
                }
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "Multi-Agent FODMAP")
                    NavigationLink("Security & Privacy", destination: SecurityInfoSheet())
                }
            }
            .navigationTitle("Settings")
        }
    }
}
