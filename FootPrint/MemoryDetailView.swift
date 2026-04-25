//
//  MemoryDetailView.swift
//  FootPrints
//
//  Created by Mudit Chaudhary on 20/04/26.
//

import SwiftUI
import MapKit

struct MemoryDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var locationManager: LocationManager
    let memory: Memory
    
    @State private var selectedPhotoIndex = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Photo Carousel
                    TabView(selection: $selectedPhotoIndex) {
                        ForEach(Array(memory.photoURLs.enumerated()), id: \.offset) { index, url in
                            AsyncImage(url: URL(string: url)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 300)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 300)
                                        .clipped()
                                case .failure:
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 300)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .frame(height: 300)
                    .background(AppTheme.secondaryBackground)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(memory.emoji)
                                        .font(.title)
                                    Text(memory.title)
                                        .font(.title2.bold())
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                                
                                Text(memory.date.formatted(date: .long, time: .omitted))
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            if memory.isPrivate {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(AppTheme.secondary)
                            }
                        }
                        
                        // Description
                        if let description = memory.description, !description.isEmpty {
                            Text(description)
                                .font(.body)
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        
                        Divider()
                        
                        // Location
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(AppTheme.secondary)
                                Text("Location")
                                    .font(.headline)
                            }
                            
                            if let address = memory.location.address {
                                Text(address)
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            
                            // Distance from current location
                            if let currentLocation = locationManager.location {
                                let memoryLocation = CLLocation(
                                    latitude: memory.location.latitude,
                                    longitude: memory.location.longitude
                                )
                                let distance = currentLocation.distance(from: memoryLocation)
                                
                                HStack {
                                    Image(systemName: "location.fill")
                                        .font(.caption)
                                    Text("\(formatDistance(distance)) from you")
                                        .font(.caption)
                                }
                                .foregroundColor(AppTheme.textSecondary)
                            }
                            
                            // Mini Map
                            Map(initialPosition: .camera(
                                MapCamera(
                                    centerCoordinate: memory.location.coordinate,
                                    distance: 1000
                                )
                            )) {
                                Marker(memory.emoji, coordinate: memory.location.coordinate)
                                    .tint(AppTheme.primary)
                            }
                            .frame(height: 150)
                            .cornerRadius(12)
                            .allowsHitTesting(false)
                            
                            // Get Directions Button
                            Button {
                                openMaps()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                    Text("Get Directions")
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.primary)
                                .cornerRadius(12)
                            }
                        }
                        
                        Divider()
                        
                        // Created Info
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(AppTheme.secondary)
                            Text("Created \(memory.createdAt.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .padding()
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            // TODO: Share memory
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            // TODO: Edit memory
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            // TODO: Delete memory
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(AppTheme.primary)
                    }
                }
            }
        }
    }
    
    // MARK: - Format Distance
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumFractionDigits = 1
        
        if distance < 1000 {
            return formatter.string(from: Measurement(value: distance, unit: UnitLength.meters))
        } else {
            return formatter.string(from: Measurement(value: distance / 1000, unit: UnitLength.kilometers))
        }
    }
    
    // MARK: - Open Maps
    private func openMaps() {
        let coordinate = memory.location.coordinate
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = memory.title
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

#Preview {
    MemoryDetailView(
        memory: Memory(
            id: "1",
            coupleId: "couple1",
            createdBy: "user1",
            title: "Our First Date",
            emoji: "❤️",
            description: "An amazing evening at the park where we had our first date. The sunset was beautiful!",
            location: MemoryLocation(
                latitude: 37.7749,
                longitude: -122.4194,
                address: "Golden Gate Park, San Francisco, CA"
            ),
            photoURLs: ["https://via.placeholder.com/400"],
            date: Date(),
            isPrivate: false,
            createdAt: Date()
        )
    )
    .environmentObject(LocationManager())
}
