//
//  SignUpView.swift
//  FootPrints
//
//  Created by Mudit Chaudhary on 20/04/26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#else
public enum UIKeyboardType {
    case `default`, emailAddress, asciiCapable
}
public enum UITextContentType {
    case emailAddress, newPassword
}
public enum UITextAutocapitalizationType {
    case none, allCharacters
}
extension View {
    func keyboardType(_ type: UIKeyboardType) -> some View { self }
    func textContentType(_ type: UITextContentType?) -> some View { self }
    func autocapitalization(_ type: UITextAutocapitalizationType) -> some View { self }
}
#endif

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "heart.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.primary)
                            
                            Text("Create Your Account")
                                .font(.title2.bold())
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text("Start preserving your memories together")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                        
                        // Form
                        VStack(spacing: 16) {
                            CustomTextField(
                                icon: "person.fill",
                                placeholder: "Your Name",
                                text: $name
                            )
                            
                            CustomTextField(
                                icon: "envelope.fill",
                                placeholder: "Email",
                                text: $email,
                                keyboardType: .emailAddress,
                                textContentType: .emailAddress
                            )
                            
                            CustomTextField(
                                icon: "lock.fill",
                                placeholder: "Password",
                                text: $password,
                                isSecure: true,
                                textContentType: .newPassword
                            )
                            
                            CustomTextField(
                                icon: "lock.fill",
                                placeholder: "Confirm Password",
                                text: $confirmPassword,
                                isSecure: true,
                                textContentType: .newPassword
                            )
                        }
                        .padding(.horizontal, 24)
                        
                        // Error Message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 24)
                        }
                        
                        // Sign Up Button
                        Button {
                            Task {
                                await signUp()
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Text("Create Account")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .background(AppTheme.primary)
                        .cornerRadius(12)
                        .disabled(isLoading || !isValid)
                        .opacity(isValid ? 1.0 : 0.6)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                            Text("OR")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 24)
                        
                        // Apple Sign In
                        Button {
                            // TODO: Implement Apple Sign In
                        } label: {
                            HStack {
                                Image(systemName: "applelogo")
                                Text("Continue with Apple")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)
                    }
                }
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
    
    // MARK: - Validation
    private var isValid: Bool {
        !name.isEmpty &&
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 6 &&
        password == confirmPassword
    }
    
    // MARK: - Sign Up
    private func signUp() async {
        guard isValid else {
            errorMessage = "Please fill all fields correctly"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await authViewModel.signUp(email: email, password: password, name: name)
            // Wait a moment for auth state to update
            try await Task.sleep(nanoseconds: 1_000_000_000)
            dismiss()
        } catch let error as NSError {
            if error.code == 12501 || error.localizedDescription.contains("PERMISSION_DENIED") {
                errorMessage = "Cloud Firestore is not set up. Please check Firebase Console."
            } else {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Custom Text Field
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.secondary)
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textContentType(textContentType)
                    .foregroundColor(AppTheme.textPrimary)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .autocapitalization(.none)
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .padding()
        .background(AppTheme.secondaryBackground)
        .cornerRadius(12)
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthViewModel())
}
