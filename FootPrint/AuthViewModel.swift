//
//  AuthViewModel.swift
//  FootPrints
//
//  Created by Mudit Chaudhary on 20/04/26.
//

import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var authState: AuthState = .loading
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        // Only setup auth listener if Firebase is configured
        if FirebaseApp.app() != nil {
            setupAuthListener()
        } else {
            // For previews, default to unauthenticated
            authState = .unauthenticated
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Auth Listener
    private func setupAuthListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let user = user {
                    await self.loadUserData(uid: user.uid)
                } else {
                    self.authState = .unauthenticated
                }
            }
        }
    }
    
    // MARK: - Load User Data
    func loadUserData(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()

            if let userData = try? document.data(as: User.self) {
                if let coupleId = userData.coupleId {
                    // Read couple doc in its own do/catch so a permission failure
                    // doesn't wipe out the user data we already have
                    do {
                        let coupleDoc = try await db.collection("couples").document(coupleId).getDocument()
                        if let couple = try? coupleDoc.data(as: Couple.self) {
                            authState = .paired(userData, couple)
                        } else {
                            // Couple doc gone (partner unpaired) — clean up stale reference
                            try? await db.collection("users").document(uid).updateData([
                                "couple_id": FieldValue.delete(),
                                "couple_code": FieldValue.delete()
                            ])
                            var cleaned = userData
                            cleaned.coupleId = nil
                            cleaned.coupleCode = nil
                            authState = .authenticated(cleaned)
                        }
                    } catch {
                        // Couple doc unreadable (likely permission rules not yet updated).
                        // Fall back to authenticated — user can still see their cached code
                        // from the user doc field couple_code.
                        print("Could not read couple doc (check Firestore rules): \(error)")
                        authState = .authenticated(userData)
                    }
                } else {
                    authState = .authenticated(userData)
                }
            } else {
                // User doc missing or undecodable — fall back to Firebase Auth identity
                authState = makeFallbackAuthState(uid: uid)
            }
        } catch {
            print("Error loading user data: \(error)")
            authState = makeFallbackAuthState(uid: uid)
        }
    }

    private func makeFallbackAuthState(uid: String) -> AuthState {
        guard let firebaseUser = Auth.auth().currentUser, firebaseUser.uid == uid else {
            return .unauthenticated
        }
        let fallback = User(
            id: uid,
            email: firebaseUser.email ?? "",
            name: firebaseUser.displayName ?? firebaseUser.email ?? "User",
            profilePhotoURL: nil,
            coupleId: nil,
            createdAt: Date()
        )
        return .authenticated(fallback)
    }
    
    // MARK: - Sign Up with Email
    func signUp(email: String, password: String, name: String) async throws {
        // Don't pre-query Firestore here — user is unauthenticated so rules would block it.
        // Firebase Auth throws emailAlreadyInUse if the account already exists.
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Create user document
            let user = User(
                id: result.user.uid,
                email: email.lowercased(),
                name: name,
                profilePhotoURL: nil,
                coupleId: nil,
                createdAt: Date()
            )
            
            try await db.collection("users").document(result.user.uid).setData(from: user)
            
            // Generate couple code
            await generateCoupleCode(for: result.user.uid)

            // Auth listener fires during createUser before Firestore doc exists.
            // Explicitly reload now that all writes are complete.
            await loadUserData(uid: result.user.uid)
        } catch let error as NSError {
            // Handle Firebase Auth errors
            if error.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                throw NSError(domain: "AuthViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "This account already exists. Please login with your credentials."])
            }
            throw error
        }
    }
    
    // MARK: - Sign In with Email
    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }
    
    // MARK: - Sign In with Apple
    func signInWithApple() async throws {
        // Implement Apple Sign In using AuthenticationServices
        // This requires additional setup with Apple Sign In
        throw NSError(domain: "AuthViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Apple Sign In not yet implemented"])
    }
    
    // MARK: - Sign Out
    func signOut() throws {
        try Auth.auth().signOut()
        authState = .unauthenticated
    }
    
    // MARK: - Generate Couple Code
    private func generateCoupleCode(for userId: String) async {
        let code = generateRandomCode()

        // Use the code itself as the Firestore document ID so partners can look it
        // up with a direct get() instead of a collection query (queries require
        // a broader 'list' permission which we want to avoid).
        let couple = Couple(
            id: code,
            user1Id: userId,
            user2Id: "",
            coupleCode: code,
            relationshipStart: nil,
            createdAt: Date()
        )

        do {
            try await db.collection("couples").document(code).setData(from: couple)

            // Cache couple_id and couple_code on the user doc for resilient display
            try await db.collection("users").document(userId).updateData([
                "couple_id": code,
                "couple_code": code
            ])
        } catch {
            print("Error creating couple: \(error)")
        }
    }

    // MARK: - Pair with Partner
    func pairWithPartner(code: String) async throws {
        // Allow pairing from .authenticated OR .paired-but-waiting (user2Id empty)
        let user: User
        switch authState {
        case .authenticated(let u):
            user = u
        case .paired(let u, let couple) where couple.user2Id.isEmpty:
            user = u
        default:
            throw NSError(domain: "AuthViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Already connected with a partner."])
        }

        let upperCode = code.uppercased()

        // Direct document lookup — no collection query needed, so no 'list' permission required.
        let coupleDoc = try await db.collection("couples").document(upperCode).getDocument()

        guard coupleDoc.exists else {
            throw NSError(domain: "AuthViewModel", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid couple code. Please check and try again."])
        }

        let couple = try coupleDoc.data(as: Couple.self)

        guard couple.user2Id.isEmpty else {
            throw NSError(domain: "AuthViewModel", code: 4, userInfo: [NSLocalizedDescriptionKey: "This code is already connected to another account."])
        }

        // Link user2 on the couple document
        try await coupleDoc.reference.updateData([
            "user2_id": user.id ?? ""
        ])

        // Cache on user doc for resilient display
        try await db.collection("users").document(user.id ?? "").updateData([
            "couple_id": upperCode,
            "couple_code": upperCode
        ])

        await loadUserData(uid: user.id ?? "")
    }
    
    // MARK: - Unpair
    func unpair() async throws {
        guard case .paired(let user, let couple) = authState else { return }

        // Only remove couple_id from YOUR OWN document.
        // Rules prevent writing a partner's document; their stale couple_id
        // is cleaned up automatically in loadUserData when the couple doc is gone.
        try await db.collection("users").document(user.id ?? "").updateData([
            "couple_id": FieldValue.delete()
        ])

        // Delete the couple document (allowed since you're a member)
        if let coupleId = couple.id {
            try await db.collection("couples").document(coupleId).delete()
        }

        await loadUserData(uid: user.id ?? "")
    }
    
    // MARK: - Helper: Generate Random Code
    private func generateRandomCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }
}
