//
//  LaunchScreenView.swift
//  GutSense
//
//  Created by Zahirudeen Premji on 3/5/26.
//

import SwiftUI

struct LaunchScreenView: View {
    
    @State private var isActive = false
    @State private var opacity = 0.0
    
    var body: some View {
        if isActive {
            ContentView()
        } else {
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
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    // App Icon
                    Image(systemName: "flask.fill")
                        .font(.system(size: 120))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor, .accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(opacity)
                    
                    Spacer()
                    
                    // Version and Website
                    VStack(spacing: 8) {
                        Text("Version \(appVersion)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Industriallystrong.com")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .opacity(opacity)
                    .padding(.bottom, 40)
                }
            }
            .onAppear {
                // Fade in animation
                withAnimation(.easeIn(duration: 0.3)) {
                    opacity = 1.0
                }
                
                // Dismiss after 1.5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isActive = true
                    }
                }
            }
        }
    }
    
    // Get version from Info.plist
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    LaunchScreenView()
}
