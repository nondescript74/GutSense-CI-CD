//
//  GutSenseApp.swift
//  GutSense
//
//  Created by Zahirudeen Premji on 3/5/26.
//

import SwiftUI
import SwiftData

@main
struct GutSenseApp: App {
    
    @StateObject private var credentialsStore = CredentialsStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(credentialsStore)
        }
        .modelContainer(for: [
            FoodQueryRecord.self,
            UserSourceRecord.self
        ])
    }
}


