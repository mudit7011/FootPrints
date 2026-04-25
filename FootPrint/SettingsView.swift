//
//  SettingsView.swift
//  FootPrints
//
//  Created by Mudit Chaudhary on 20/04/26.
//

import SwiftUI
import CoreLocation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var memoryViewModel: MemoryViewModel

    @State private var notificationsEnabled = true
    @State private var notificationRadius: Double = 200
    @State private var showUnpairAlert = false
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var exportItem: ExportItem?
    @State private var isExporting = false
    @State private var showCopiedToast = false
    @State private var showEnterCode = false
    @State private var partnerCode = ""
    @State private var isPairing = false
    @State private var pairingError: String?

    var body: some View {
        NavigationStack {
            List {
                // ── Profile + Partner sections ──────────────────────────────
                // Case A: actually paired (both users linked)
                if case .paired(let user, let couple) = authViewModel.authState, !couple.user2Id.isEmpty {
                    Section {
                        profileRow(name: user.name, email: user.email)

                        HStack {
                            Text("Couple Code")
                            Spacer()
                            Text(couple.coupleCode)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                            Button { copyCode(couple.coupleCode) } label: {
                                Image(systemName: showCopiedToast ? "checkmark" : "doc.on.doc")
                                    .foregroundColor(showCopiedToast ? .green : AppTheme.secondary)
                                    .animation(.easeInOut, value: showCopiedToast)
                            }
                        }

                        if let relationshipStart = couple.relationshipStart {
                            HStack {
                                Text("Together Since")
                                Spacer()
                                Text(relationshipStart.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text("Days Together")
                                Spacer()
                                let days = Calendar.current.dateComponents([.day], from: relationshipStart, to: Date()).day ?? 0
                                Text("\(days) days")
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Text("Total Memories")
                            Spacer()
                            Text("\(memoryViewModel.memories.count)")
                                .foregroundColor(.secondary)
                        }
                    } header: { Text("Profile") }

                    Section {
                        Button(role: .destructive) { showUnpairAlert = true } label: {
                            Label("Disconnect from Partner", systemImage: "person.2.slash")
                        }
                    } header: { Text("Partner") } footer: {
                        Text("Removes the connection with your partner. Shared memories will be deleted.")
                    }
                }

                // Case B: has a couple code but partner hasn't joined yet
                if case .paired(let user, let couple) = authViewModel.authState, couple.user2Id.isEmpty {
                    Section {
                        profileRow(name: user.name, email: user.email)
                    } header: { Text("Profile") }

                    Section {
                        // Your code — share this with your partner
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Couple Code")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                Text(couple.coupleCode)
                                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppTheme.primary)
                                    .tracking(4)
                                Spacer()
                                Button {
                                    copyCode(couple.coupleCode)
                                } label: {
                                    Label(showCopiedToast ? "Copied!" : "Copy", systemImage: showCopiedToast ? "checkmark" : "doc.on.doc")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(showCopiedToast ? .green : AppTheme.secondary)
                                        .animation(.easeInOut, value: showCopiedToast)
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        Button {
                            showEnterCode = true
                        } label: {
                            Label("Enter Partner's Code", systemImage: "link.circle.fill")
                        }

                        if let pairingError = pairingError {
                            Text(pairingError).font(.caption).foregroundColor(.red)
                        }
                    } header: { Text("Connect with Partner") } footer: {
                        Text("Share your code above with your partner, or enter their code to connect.")
                    }
                }

                // Case C: authenticated (couple doc unreadable, but user doc loaded fine)
                if case .authenticated(let user) = authViewModel.authState {
                    Section {
                        profileRow(name: user.name, email: user.email)
                    } header: { Text("Profile") }

                    Section {
                        // Show cached couple code from user doc if available
                        if let code = user.coupleCode {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your Couple Code")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Text(code)
                                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                                        .foregroundColor(AppTheme.primary)
                                        .tracking(4)
                                    Spacer()
                                    Button {
                                        copyCode(code)
                                    } label: {
                                        Label(showCopiedToast ? "Copied!" : "Copy",
                                              systemImage: showCopiedToast ? "checkmark" : "doc.on.doc")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(showCopiedToast ? .green : AppTheme.secondary)
                                            .animation(.easeInOut, value: showCopiedToast)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        Button {
                            showEnterCode = true
                        } label: {
                            Label("Enter Partner's Code", systemImage: "link.circle.fill")
                        }

                        if let pairingError = pairingError {
                            Text(pairingError).font(.caption).foregroundColor(.red)
                        }
                    } header: { Text("Connect with Partner") } footer: {
                        Text(user.coupleCode != nil
                             ? "Share your code above with your partner, or enter their code to connect."
                             : "Sign out and sign back in to refresh your couple code.")
                    }
                }

                // Notifications — always visible when logged in
                Section {
                    HStack {
                        Label("Location Access", systemImage: locationIconName)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(locationStatusText)
                            .font(.caption)
                            .foregroundColor(locationStatusColor)
                    }

                    Toggle("Proximity Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, _ in
                            applyAndSaveSettings()
                        }

                    if notificationsEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Notification Radius")
                                Spacer()
                                Text("\(Int(notificationRadius)) m")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $notificationRadius, in: 50...1000, step: 50)
                                .tint(AppTheme.primary)
                                .onChange(of: notificationRadius) { _, _ in
                                    applyAndSaveSettings()
                                }
                            Text("Notified when within \(Int(notificationRadius)) m of a memory")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Receive a notification when you walk near a memory location.")
                }

                // Privacy & Data — always visible when logged in
                Section {
                    Button {
                        exportMemories()
                    } label: {
                        HStack {
                            Label("Export My Data", systemImage: "arrow.down.doc")
                            Spacer()
                            if isExporting { ProgressView() }
                        }
                    }
                    .disabled(isExporting)

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }

                    NavigationLink {
                        TermsOfServiceView()
                    } label: {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                } header: {
                    Text("Privacy & Data")
                }

                // Account Section
                Section {
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } header: {
                    Text("Account")
                }

                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(appBuild)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.primary)
                }
            }
            .onAppear {
                loadSavedSettings()
            }
            .sheet(item: $exportItem) { item in
                ShareSheet(items: [item.url])
            }
            .sheet(isPresented: $showEnterCode) {
                EnterCodeSheet(
                    partnerCode: $partnerCode,
                    isLoading: $isPairing,
                    errorMessage: $pairingError,
                    onSubmit: {
                        Task {
                            isPairing = true
                            pairingError = nil
                            do {
                                try await authViewModel.pairWithPartner(code: partnerCode)
                                showEnterCode = false
                            } catch {
                                pairingError = error.localizedDescription
                            }
                            isPairing = false
                        }
                    }
                )
            }
            .alert("Disconnect from Partner?", isPresented: $showUnpairAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Disconnect", role: .destructive) {
                    Task { try? await authViewModel.unpair() }
                }
            } message: {
                Text("This will remove your connection and delete all shared memories. This cannot be undone.")
            }
            .alert("Sign Out?", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    try? authViewModel.signOut()
                }
            } message: {
                Text("You can sign back in at any time.")
            }
        }
    }

    // MARK: - Location status helpers
    private var locationIconName: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways: return "location.fill"
        case .authorizedWhenInUse: return "location"
        case .denied, .restricted: return "location.slash"
        default: return "location"
        }
    }

    private var locationStatusText: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "While Using"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        default: return "Not Set"
        }
    }

    private var locationStatusColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedAlways: return .green
        case .authorizedWhenInUse: return .orange
        default: return .red
        }
    }

    // MARK: - App version helpers
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // MARK: - Settings persistence
    private func loadSavedSettings() {
        let savedEnabled = UserDefaults.standard.object(forKey: "notifications_enabled") as? Bool ?? true
        let savedRadius = UserDefaults.standard.double(forKey: "notification_radius")
        notificationsEnabled = savedEnabled
        notificationRadius = savedRadius > 0 ? savedRadius : 200
    }

    private func applyAndSaveSettings() {
        UserDefaults.standard.set(notificationsEnabled, forKey: "notifications_enabled")
        UserDefaults.standard.set(notificationRadius, forKey: "notification_radius")

        let settings = NotificationSettings(enabled: notificationsEnabled, radius: notificationRadius)
        locationManager.setupGeofences(for: memoryViewModel.memories, settings: settings)
    }

    // MARK: - Profile row helper
    @ViewBuilder
    private func profileRow(name: String, email: String) -> some View {
        HStack(spacing: 16) {
            Circle()
                .fill(LinearGradient(
                    colors: [AppTheme.primary, AppTheme.secondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 60, height: 60)
                .overlay {
                    Text(String(name.prefix(1)).uppercased())
                        .font(.title.bold())
                        .foregroundColor(.white)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.headline)
                Text(email).font(.subheadline).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Copy couple code
    private func copyCode(_ code: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = code
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #endif
        showCopiedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedToast = false
        }
    }

    // MARK: - Export memories
    private func exportMemories() {
        isExporting = true
        Task {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let exportData = memoryViewModel.memories.map { memory in
                [
                    "title": memory.title,
                    "emoji": memory.emoji,
                    "description": memory.description ?? "",
                    "date": ISO8601DateFormatter().string(from: memory.date),
                    "address": memory.location.address ?? "",
                    "latitude": "\(memory.location.latitude)",
                    "longitude": "\(memory.location.longitude)",
                    "photos": memory.photoURLs.count,
                    "private": memory.isPrivate
                ] as [String: Any]
            }

            guard let jsonData = try? JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys]),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                isExporting = false
                return
            }

            let fileName = "footprints_export_\(Date().formatted(.iso8601)).json"
                .replacingOccurrences(of: ":", with: "-")
                .replacingOccurrences(of: " ", with: "_")
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            try? jsonData.write(to: tempURL)
            exportItem = ExportItem(url: tempURL)
            isExporting = false
        }
    }
}

// MARK: - Export item wrapper (Identifiable for .sheet)
struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    policySection(
                        title: "Information We Collect",
                        body: "FootPrints collects your email address, name, and location data to provide the core memory-sharing experience. Location is used only while you're using the app or when you grant background access to enable proximity notifications."
                    )
                    policySection(
                        title: "How We Use Your Data",
                        body: "Your data is used solely to power FootPrints features: storing memories, pairing with your partner, and delivering proximity notifications. We do not sell or share your data with third parties."
                    )
                    policySection(
                        title: "Data Storage",
                        body: "Your memories and profile information are stored securely in Firebase (Google Cloud). Photos are stored in Firebase Storage. All data is encrypted in transit and at rest."
                    )
                    policySection(
                        title: "Data Deletion",
                        body: "You can delete all your data at any time by disconnecting from your partner (which removes shared memories) and then deleting your account. Contact support for complete data removal."
                    )
                    policySection(
                        title: "Contact",
                        body: "For privacy questions, email support@footprints.app."
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.large)
    }

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Terms of Service View
struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    tosSection(
                        title: "Acceptance",
                        body: "By using FootPrints you agree to these terms. If you do not agree, please discontinue use."
                    )
                    tosSection(
                        title: "Use of the App",
                        body: "FootPrints is for personal, non-commercial use. You may not use the app to upload illegal, harmful, or offensive content."
                    )
                    tosSection(
                        title: "Your Content",
                        body: "You retain ownership of all photos and memories you create. By uploading content you grant FootPrints a limited licence to store and display it to your paired partner."
                    )
                    tosSection(
                        title: "Account Termination",
                        body: "We reserve the right to suspend accounts that violate these terms. You may delete your account at any time."
                    )
                    tosSection(
                        title: "Limitation of Liability",
                        body: "FootPrints is provided 'as is'. We are not liable for any loss of data or damages arising from use of the app."
                    )
                    tosSection(
                        title: "Changes",
                        body: "We may update these terms. Continued use of the app after changes constitutes acceptance of the new terms."
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.large)
    }

    private func tosSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
        .environmentObject(LocationManager())
        .environmentObject(MemoryViewModel())
}
