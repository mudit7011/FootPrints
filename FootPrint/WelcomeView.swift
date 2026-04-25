//
//  WelcomeView.swift
//  FootPrints
//
//  Created by Mudit Chaudhary on 20/04/26.
//

import SwiftUI

struct WelcomeView: View {
    @State private var showSignIn = false
    @State private var showSignUp = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Background gradient — adapts to dark mode
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(.systemBackground), Color(.secondarySystemBackground)]
                    : [AppTheme.veryLightPink, AppTheme.lightPink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Logo
                VStack(spacing: 16) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.deepMaroon, AppTheme.roseCoralDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("FootPrints")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.primary)
                    
                    Text("Where love leaves its mark")
                        .font(.title3)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Buttons
                VStack(spacing: 16) {
                    Button("Get Started") {
                        showSignUp = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    Button("I Already Have an Account") {
                        showSignIn = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
        }
    }
}

#Preview {
    WelcomeView()
}
