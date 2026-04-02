//
//  SettingsView.swift
//  GutSense
//
//  Created by Zahirudeen Premji on 3/5/26.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var backendService = BackendAPIService.shared

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
#if DEBUG
                Section("Debug") {
                    NavigationLink("Network Logs", destination: DebugNetworkLogView(logs: backendService.networkLogs))
                }
#endif
            }
            .navigationTitle("Settings")
        }
    }
}

#if DEBUG
struct DebugNetworkLogView: View {
    let logs: [BackendAPIService.NetworkLogEntry]

    var body: some View {
        List {
            if logs.isEmpty {
                Text("No network logs yet.")
                    .foregroundColor(.secondary)
            }
            ForEach(logs) { entry in
                NavigationLink(destination: DebugNetworkLogDetailView(entry: entry)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.url)
                            .font(.caption)
                            .lineLimit(2)
                        Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if let status = entry.statusCode {
                            Text("Status: \(status)")
                                .font(.caption2)
                                .foregroundColor(status >= 200 && status < 300 ? .green : .red)
                        } else if entry.errorDescription != nil {
                            Text("Error")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle("Network Logs")
    }
}

struct DebugNetworkLogDetailView: View {
    let entry: BackendAPIService.NetworkLogEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("URL")
                    .font(.caption.weight(.semibold))
                Text(entry.url)
                    .font(.caption)

                Text("Request Body")
                    .font(.caption.weight(.semibold))
                Text(entry.requestBody)
                    .font(.caption)
                    .textSelection(.enabled)

                if let status = entry.statusCode {
                    Text("Status")
                        .font(.caption.weight(.semibold))
                    Text("\(status)")
                        .font(.caption)
                }

                if let error = entry.errorDescription, !error.isEmpty {
                    Text("Error")
                        .font(.caption.weight(.semibold))
                    Text(error)
                        .font(.caption)
                        .textSelection(.enabled)
                }

                Text("Response Body")
                    .font(.caption.weight(.semibold))
                Text(entry.responseBody)
                    .font(.caption)
                    .textSelection(.enabled)
            }
            .padding()
        }
        .navigationTitle("Log Detail")
    }
}
#endif
