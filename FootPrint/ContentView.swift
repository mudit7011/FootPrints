//
//  ContentView.swift
//  FootPrint
//
//  Created by Mudit Chaudhary on 20/04/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var memoryViewModel = MemoryViewModel()
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        Group {
            switch authViewModel.authState {
            case .loading:
                LoadingView()
                
            case .unauthenticated:
                WelcomeView()
                
            case .authenticated(let user):
                // If the user doc has a cached coupleId, the couple doc read likely
                // failed due to Firestore rules lag. Reconstruct a minimal Couple so
                // the user can still create memories without being stuck.
                let fallbackCouple: Couple? = user.coupleId.map { cid in
                    Couple(
                        id: cid,
                        user1Id: user.id ?? "",
                        user2Id: "",
                        coupleCode: user.coupleCode ?? cid,
                        relationshipStart: nil,
                        createdAt: Date()
                    )
                }
                MapView(couple: fallbackCouple)
                    .onAppear {
                        locationManager.requestPermissions()
                        if let cid = user.coupleId {
                            memoryViewModel.loadMemories(for: cid)
                        }
                    }

            case .paired(_, let couple):
                MapView(couple: couple)
                    .onAppear {
                        memoryViewModel.loadMemories(for: couple.id ?? "")
                        locationManager.requestPermissions()
                        locationManager.setupGeofences(
                            for: memoryViewModel.memories,
                            settings: .default
                        )
                    }
                    .onChange(of: memoryViewModel.memories) { oldValue, newValue in
                        locationManager.setupGeofences(
                            for: newValue,
                            settings: .default
                        )
                    }
            }
        }
        .environmentObject(authViewModel)
        .environmentObject(memoryViewModel)
        .environmentObject(locationManager)
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.veryLightPink, AppTheme.lightPink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.deepMaroon, AppTheme.roseCoralDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                ProgressView()
                    .tint(AppTheme.primary)
            }
        }
    }
}

#Preview {
    ContentView()
}
