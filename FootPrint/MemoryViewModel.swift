//
//  MemoryViewModel.swift
//  FootPrints
//
//  Created by Mudit Chaudhary on 20/04/26.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseStorage
import CoreLocation

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

@MainActor
class MemoryViewModel: ObservableObject {
    @Published var memories: [Memory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var listener: ListenerRegistration?
    
    // MARK: - Load Memories
    func loadMemories(for coupleId: String) {
        listener?.remove()
        
        listener = db.collection("memories")
            .whereField("couple_id", isEqualTo: coupleId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let documents = snapshot?.documents else { return }

                self.memories = documents.compactMap { doc in
                    try? doc.data(as: Memory.self)
                }.sorted { $0.createdAt > $1.createdAt }
            }
    }
    
    // MARK: - Create Memory
    func createMemory(
        coupleId: String,
        userId: String,
        title: String,
        emoji: String,
        description: String?,
        location: MemoryLocation,
        date: Date,
        isPrivate: Bool,
        images: [PlatformImage]
    ) async throws {
        isLoading = true
        defer { isLoading = false }
        
        var photoURLs: [String] = []
        var photoUploadWarning: String? = nil

        // Upload images if provided — failure is non-fatal so the memory still saves
        if !images.isEmpty {
            do {
                photoURLs = try await uploadImages(images, coupleId: coupleId)
            } catch {
                photoUploadWarning = "Photos could not be saved (\(error.localizedDescription)). Check Firebase Storage rules."
            }
        }
        
        // Create memory document — use document().setData(from:) so we can await
        let memory = Memory(
            id: nil,
            coupleId: coupleId,
            createdBy: userId,
            title: title,
            emoji: emoji,
            description: description,
            location: location,
            photoURLs: photoURLs,
            date: date,
            isPrivate: isPrivate,
            createdAt: Date()
        )

        do {
            let docRef = db.collection("memories").document()
            try await docRef.setData(from: memory)
            errorMessage = photoUploadWarning  // nil if photos uploaded OK
        } catch {
            errorMessage = "Failed to save memory: \(error.localizedDescription)"
            throw error
        }
        
        // TODO: Send push notification to partner
    }
    
    // MARK: - Update Memory
    func updateMemory(
        _ memory: Memory,
        title: String,
        emoji: String,
        description: String?,
        date: Date,
        isPrivate: Bool
    ) async throws {
        guard let memoryId = memory.id else { return }
        
        try await db.collection("memories").document(memoryId).updateData([
            "title": title,
            "emoji": emoji,
            "description": description as Any,
            "date": date,
            "is_private": isPrivate
        ])
    }
    
    // MARK: - Delete Memory
    func deleteMemory(_ memory: Memory) async throws {
        guard let memoryId = memory.id else { return }
        
        // Delete photos from storage
        for photoURL in memory.photoURLs {
            let storageRef = storage.reference(forURL: photoURL)
            try? await storageRef.delete()
        }
        
        // Delete memory document
        try await db.collection("memories").document(memoryId).delete()
    }
    
    // MARK: - Upload Images
    private func uploadImages(_ images: [PlatformImage], coupleId: String) async throws -> [String] {
        var urls: [String] = []
        
        for (index, image) in images.enumerated() {
            do {
                // Convert image to JPEG data
                #if canImport(UIKit)
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    print("Failed to convert image \(index) to JPEG")
                    continue
                }
                #elseif canImport(AppKit)
                guard let tiffData = image.tiffRepresentation,
                      let bitmapImage = NSBitmapImageRep(data: tiffData),
                      let imageData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
                    print("Failed to convert image \(index) to JPEG")
                    continue
                }
                #endif
                
                let filename = "\(Date().timeIntervalSince1970)_\(UUID().uuidString).jpg"
                let storageRef = storage.reference()
                    .child("couples")
                    .child(coupleId)
                    .child("memories")
                    .child(filename)
                
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                
                print("Uploading image \(index) to: \(storageRef.fullPath)")
                _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
                let downloadURL = try await storageRef.downloadURL()
                print("Image \(index) uploaded successfully: \(downloadURL.absoluteString)")
                urls.append(downloadURL.absoluteString)
            } catch {
                print("Failed to upload image \(index): \(error.localizedDescription)")
                errorMessage = "Failed to upload image \(index + 1): \(error.localizedDescription)"
                throw error
            }
        }
        
        return urls
    }
    
    // MARK: - Filter Memories
    func filteredMemories(searchText: String = "", dateRange: ClosedRange<Date>? = nil, emoji: String? = nil) -> [Memory] {
        var filtered = memories
        
        // Search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { memory in
                memory.title.localizedCaseInsensitiveContains(searchText) ||
                memory.description?.localizedCaseInsensitiveContains(searchText) == true ||
                memory.location.address?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Date range filter
        if let dateRange = dateRange {
            filtered = filtered.filter { memory in
                dateRange.contains(memory.date)
            }
        }
        
        // Emoji filter
        if let emoji = emoji {
            filtered = filtered.filter { $0.emoji == emoji }
        }
        
        return filtered
    }
    
    // MARK: - Get Distance
    func distance(from memory: Memory, to location: CLLocation) -> CLLocationDistance {
        let memoryLocation = CLLocation(
            latitude: memory.location.latitude,
            longitude: memory.location.longitude
        )
        return location.distance(from: memoryLocation)
    }
    
    // MARK: - Cleanup
    deinit {
        listener?.remove()
    }
}
