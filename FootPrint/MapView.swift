//
//  MapView.swift
//  FootPrints
//
//  Created by Mudit Chaudhary on 20/04/26.
//

import SwiftUI
import MapKit
import UIKit

struct MapView: View {
    @EnvironmentObject var memoryViewModel: MemoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    let couple: Couple?

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedMemory: Memory?
    @State private var showCreateMemory = false
    @State private var showTimeline = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            // Map
            Map(position: $cameraPosition) {
                UserAnnotation()

                ForEach(memoryViewModel.memories) { memory in
                    Annotation(
                        memory.title,
                        coordinate: memory.location.coordinate
                    ) {
                        MemoryPin(emoji: memory.emoji)
                            .onTapGesture {
                                selectedMemory = memory
                            }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
            }
            .ignoresSafeArea()

            // Top overlay
            VStack {
                HStack(alignment: .top) {
                    // Stats badge
                    HStack(spacing: 20) {
                        StatBadge(
                            icon: "heart.fill",
                            value: "\(memoryViewModel.memories.count)",
                            label: "Memories"
                        )

                        if let relationshipStart = couple?.relationshipStart {
                            let days = Calendar.current.dateComponents(
                                [.day],
                                from: relationshipStart,
                                to: Date()
                            ).day ?? 0

                            StatBadge(
                                icon: "calendar",
                                value: "\(days)",
                                label: "Days"
                            )
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)

                    Spacer()

                    // Settings + Location buttons stacked vertically
                    VStack(spacing: 10) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }

                        Button {
                            if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                                // Open settings if already denied
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } else if locationManager.authorizationStatus == .notDetermined {
                                // Request permissions
                                locationManager.requestPermissions()
                            } else if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                                // Permission already granted, ensure tracking is on and center
                                locationManager.startTracking()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    centerOnUserLocation()
                                }
                            } else {
                                // Permission granted, center on location
                                centerOnUserLocation()
                            }
                        } label: {
                            Image(systemName: locationManager.location != nil ? "location.fill" : "location.slash")
                                .font(.title3)
                                .foregroundColor(locationManager.location != nil ? AppTheme.primary : .secondary)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding()

                Spacer()
            }

            // Bottom buttons
            VStack {
                Spacer()

                HStack(spacing: 16) {
                    Button {
                        showTimeline = true
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("Timeline")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppTheme.secondary)
                        .cornerRadius(25)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }

                    Spacer()

                    Button {
                        showCreateMemory = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.primary, AppTheme.secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: AppTheme.primary.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
        .sheet(item: $selectedMemory) { memory in
            MemoryDetailView(memory: memory)
        }
        .sheet(isPresented: $showCreateMemory) {
            if let couple = couple {
                CreateMemoryView(couple: couple)
            } else {
                NoPairingView()
            }
        }
        .sheet(isPresented: $showTimeline) {
            TimelineView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            // Always start location tracking
            if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                locationManager.startTracking()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    centerOnUserLocation()
                }
            }
        }
        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
            if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                locationManager.startTracking()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    centerOnUserLocation()
                }
            }
        }
        .onChange(of: locationManager.location) { _, newLocation in
            if cameraPosition == .automatic, let location = newLocation {
                cameraPosition = .camera(
                    MapCamera(centerCoordinate: location.coordinate, distance: 5000)
                )
            }
        }
    }

    private func centerOnUserLocation() {
        if let location = locationManager.location {
            withAnimation {
                cameraPosition = .camera(
                    MapCamera(centerCoordinate: location.coordinate, distance: 1500)
                )
            }
        }
    }
}

// MARK: - Memory Pin
struct MemoryPin: View {
    let emoji: String

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [AppTheme.primary, AppTheme.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 40, height: 40)

            Text(emoji)
                .font(.title3)
        }
    }
}

// MARK: - No Pairing Prompt
struct NoPairingView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.2.fill")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.primary)
            Text("Connect with Your Partner First")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Go to Settings to share your couple code or enter your partner's code.")
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Button("Got it") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
        }
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.headline)
            }
            .foregroundColor(AppTheme.primary)

            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}

#Preview {
    MapView(couple: nil)
        .environmentObject(MemoryViewModel())
        .environmentObject(LocationManager())
}
