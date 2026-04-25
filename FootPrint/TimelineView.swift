//
//  TimelineView.swift
//  FootPrints
//
//  Created by Mudit Chaudhary on 20/04/26.
//

import SwiftUI
import CoreLocation

struct TimelineView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var memoryViewModel: MemoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var searchText = ""
    @State private var selectedMemory: Memory?
    
    var filteredMemories: [Memory] {
        if searchText.isEmpty {
            return memoryViewModel.memories
        } else {
            return memoryViewModel.filteredMemories(searchText: searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(filteredMemories) { memory in
                        MemoryCard(memory: memory)
                            .onTapGesture {
                                selectedMemory = memory
                            }
                    }
                    
                    if filteredMemories.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: searchText.isEmpty ? "heart" : "magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.secondary)
                            
                            Text(searchText.isEmpty ? "No Memories Yet" : "No Results Found")
                                .font(.title3.bold())
                                .foregroundColor(AppTheme.textPrimary)
                            
                            Text(searchText.isEmpty ? "Create your first memory to get started" : "Try a different search term")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 100)
                    }
                }
                .padding()
            }
            .background(AppTheme.background)
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search memories")
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
            .sheet(item: $selectedMemory) { memory in
                MemoryDetailView(memory: memory)
            }
        }
    }
}

// MARK: - Memory Card
struct MemoryCard: View {
    @EnvironmentObject var locationManager: LocationManager
    let memory: Memory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo
            if let firstPhotoURL = memory.photoURLs.first {
                AsyncImage(url: URL(string: firstPhotoURL)) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(AppTheme.secondaryBackground)
                            .frame(height: 200)
                            .overlay {
                                ProgressView()
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(AppTheme.secondaryBackground)
                            .frame(height: 200)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(memory.emoji)
                        .font(.title2)
                    Text(memory.title)
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if memory.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondary)
                    }
                }
                
                Text(memory.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
                
                if let address = memory.location.address {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                        Text(address)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(AppTheme.textSecondary)
                }
                
                // Distance
                if let currentLocation = locationManager.location {
                    let memoryLocation = CLLocation(
                        latitude: memory.location.latitude,
                        longitude: memory.location.longitude
                    )
                    let distance = currentLocation.distance(from: memoryLocation)
                    
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.caption)
                        Text(formatDistance(distance))
                            .font(.caption)
                    }
                    .foregroundColor(AppTheme.secondary)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Format Distance
    private func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .short
        formatter.numberFormatter.maximumFractionDigits = 1
        
        if distance < 1000 {
            return formatter.string(from: Measurement(value: distance, unit: UnitLength.meters))
        } else {
            return formatter.string(from: Measurement(value: distance / 1000, unit: UnitLength.kilometers))
        }
    }
}

#Preview {
    TimelineView()
        .environmentObject(MemoryViewModel())
        .environmentObject(LocationManager())
}
