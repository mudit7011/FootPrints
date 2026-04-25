//
//  PairingView.swift
//  FootPrints
//
//  Created by Mudit Chaudhary on 20/04/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct PairingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let user: User
    let couple: Couple?
    
    @State private var showEnterCode = false
    @State private var partnerCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCopiedAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppTheme.veryLightPink, AppTheme.lightPink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Icon
                    ZStack {
                        Circle()
                            .fill(AppTheme.primary.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 50))
                            .foregroundColor(AppTheme.primary)
                    }
                    
                    // Title
                    VStack(spacing: 12) {
                        Text("Connect with Your Partner")
                            .font(.title.bold())
                            .foregroundColor(AppTheme.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text("Share your code or enter your partner's code to start creating memories together")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    // Your Code
                    if let couple = couple {
                        VStack(spacing: 16) {
                            Text("Your Couple Code")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                                .textCase(.uppercase)
                                .tracking(1.2)
                            
                            HStack(spacing: 4) {
                                ForEach(Array(couple.coupleCode.enumerated()), id: \.offset) { index, char in
                                    Text(String(char))
                                        .font(.system(size: 32, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.primary)
                                        .frame(width: 40, height: 50)
                                        .background(Color.white)
                                        .cornerRadius(8)
                                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                                }
                            }
                            
                            Button {
                                #if canImport(UIKit)
                                UIPasteboard.general.string = couple.coupleCode
                                #elseif canImport(AppKit)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(couple.coupleCode, forType: .string)
                                #endif
                                showCopiedAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "doc.on.doc.fill")
                                    Text("Copy Code")
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(AppTheme.secondary)
                            }
                        }
                        .padding(24)
                        .background(AppTheme.secondaryBackground)
                        .cornerRadius(20)
                        .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 40)
                    }
                    
                    // Buttons
                    VStack(spacing: 16) {
                        Button {
                            showEnterCode = true
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Text("Enter Partner's Code")
                                    .font(.headline)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                }
            }
            .alert("Code Copied!", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Share this code with your partner")
            }
            .sheet(isPresented: $showEnterCode) {
                EnterCodeSheet(
                    partnerCode: $partnerCode,
                    isLoading: $isLoading,
                    errorMessage: $errorMessage,
                    onSubmit: {
                        Task {
                            await pairWithPartner()
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Pair with Partner
    private func pairWithPartner() async {
        guard !partnerCode.isEmpty, partnerCode.count == 6 else {
            errorMessage = "Please enter a valid 6-character code"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authViewModel.pairWithPartner(code: partnerCode)
            showEnterCode = false
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Enter Code Sheet
struct EnterCodeSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var partnerCode: String
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    let onSubmit: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(AppTheme.primary)
                    
                    Text("Enter Partner's Code")
                        .font(.title2.bold())
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text("Enter the 6-character code your partner shared with you")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 40)
                
                // Code Input
                TextField("", text: $partnerCode)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .textCase(.uppercase)
                    .keyboardType(.asciiCapable)
                    .autocapitalization(.allCharacters)
                    .frame(maxWidth: 240)
                    .padding()
                    .background(AppTheme.secondaryBackground)
                    .cornerRadius(12)
                    .onChange(of: partnerCode) { oldValue, newValue in
                        partnerCode = String(newValue.prefix(6).uppercased())
                    }
                
                // Error Message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                // Submit Button
                Button {
                    onSubmit()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Connect")
                            .font(.headline)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(partnerCode.count != 6 || isLoading)
                .opacity(partnerCode.count == 6 ? 1.0 : 0.6)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
        }
    }
}

#Preview {
    PairingView(
        user: User(
            id: "1",
            email: "test@example.com",
            name: "Test User",
            profilePhotoURL: nil,
            coupleId: "couple1",
            createdAt: Date()
        ),
        couple: Couple(
            id: "couple1",
            user1Id: "1",
            user2Id: "",
            coupleCode: "ABC123",
            relationshipStart: nil,
            createdAt: Date()
        )
    )
    .environmentObject(AuthViewModel())
}
