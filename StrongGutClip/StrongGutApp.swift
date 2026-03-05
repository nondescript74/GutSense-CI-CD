//
//  StrongGutApp.swift
//  StrongGut App Clip
//
//  Created by Zahirudeen Premji on 3/5/26.
//

import SwiftUI

@main
struct StrongGutApp: App {
    
    @StateObject private var credentialsStore = CredentialsStore.shared
    
    var body: some Scene {
        WindowGroup {
            StrongGutClipView()
                .environmentObject(credentialsStore)
        }
    }
}
