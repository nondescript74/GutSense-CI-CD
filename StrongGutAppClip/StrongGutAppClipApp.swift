//
//  StrongGutAppClipApp.swift
//  StrongGutAppClip
//
//  Created by Zahirudeen Premji on 3/5/26.
//

import SwiftUI

@main
struct StrongGutAppClipApp: App {
    
    @StateObject private var credentialsStore = CredentialsStore.shared
    
    var body: some Scene {
        WindowGroup {
            LaunchScreenView()
                .environmentObject(credentialsStore)
        }
    }
}
