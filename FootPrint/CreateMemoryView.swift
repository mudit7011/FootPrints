//
//  CreateMemoryView.swift
//  FootPrints
//
//  Created by Mudit Chaudhary on 20/04/26.
//

import SwiftUI
import PhotosUI
import CoreLocation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct CreateMemoryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var memoryViewModel: MemoryViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var authViewModel: AuthViewModel

    let couple: Couple

    @State private var title = ""
    @State private var selectedEmoji = "❤️"
    @State private var description = ""
    @State private var selectedDate = Date()
    @State private var isPrivate = false
    @State private var selectedImages: [PlatformImage] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var location: MemoryLocation?
    @State private var showEmojiPicker = false
    @State private var isSaving = false
    @State private var isLoadingLocation = false
    @State private var errorMessage: String?
    @State private var showPhotoWarning = false
    @State private var photoWarningMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    // Photos Section
                    Section {
                        PhotosPicker(
                            selection: $selectedPhotos,
                            maxSelectionCount: 10,
                            matching: .images
                        ) {
                            if selectedImages.isEmpty {
                                HStack {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.title2)
                                        .foregroundColor(AppTheme.secondary)

                                    VStack(alignment: .leading) {
                                        Text("Add Photos")
                                            .font(.headline)
                                        Text("Optional – up to 10 photos")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                            PlatformImageView(image: image)
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .overlay(alignment: .topTrailing) {
                                                    Button {
                                                        selectedImages.remove(at: index)
                                                        if index < selectedPhotos.count {
                                                            selectedPhotos.remove(at: index)
                                                        }
                                                    } label: {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundColor(.white)
                                                            .background(Circle().fill(Color.black.opacity(0.6)))
                                                    }
                                                    .offset(x: -4, y: 4)
                                                }
                                        }

                                        if selectedImages.count < 10 {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(AppTheme.secondaryBackground)
                                                .frame(width: 80, height: 80)
                                                .overlay {
                                                    Image(systemName: "plus")
                                                        .foregroundColor(AppTheme.secondary)
                                                }
                                        }
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Photos")
                    }

                    // Details Section
                    Section {
                        HStack {
                            Text("Emoji")
                                .foregroundColor(.primary)
                            Spacer()
                            Button {
                                showEmojiPicker = true
                            } label: {
                                HStack {
                                    Text(selectedEmoji)
                                        .font(.title2)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        TextField("Memory Title", text: $title)

                        DatePicker("Date", selection: $selectedDate, displayedComponents: [.date])

                        Toggle("Private (only you can see)", isOn: $isPrivate)
                    } header: {
                        Text("Details")
                    }

                    // Description Section
                    Section {
                        TextEditor(text: $description)
                            .frame(minHeight: 100)
                    } header: {
                        Text("Description (Optional)")
                    }

                    // Location Section
                    Section {
                        if let location = location {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(location.address ?? "Unknown Location")
                                        .font(.subheadline)
                                    Text("\(location.latitude, specifier: "%.4f"), \(location.longitude, specifier: "%.4f")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("Refresh") {
                                    self.location = nil
                                    loadCurrentLocation()
                                }
                                .font(.subheadline)
                                .foregroundColor(AppTheme.secondary)
                            }
                        } else {
                            Button {
                                loadCurrentLocation()
                            } label: {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(AppTheme.primary)
                                    Text(isLoadingLocation ? "Getting location…" : "Use Current Location")
                                        .foregroundColor(isLoadingLocation ? .secondary : AppTheme.primary)
                                    Spacer()
                                    if isLoadingLocation {
                                        ProgressView()
                                    }
                                }
                            }
                            .disabled(isLoadingLocation)

                            if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                                Text("Location access denied. Enable it in Settings → Privacy → Location Services.")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    } header: {
                        Text("Location")
                    } footer: {
                        if location == nil && !isLoadingLocation {
                            Text("A location is required to place this memory on the map.")
                        }
                    }

                    // Error Message
                    if let errorMessage = errorMessage {
                        Section {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)

                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(AppTheme.primary)
                        Text("Saving memory…")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }
            }
            .navigationTitle("Create Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await createMemory()
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.primary)
                    .disabled(!isValid || isSaving)
                }
            }
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPickerView(selectedEmoji: $selectedEmoji)
            }
        }
        .alert("Memory Saved", isPresented: $showPhotoWarning) {
            Button("OK") { dismiss() }
        } message: {
            Text(photoWarningMessage)
        }
        .onChange(of: selectedPhotos) { _, newValue in
            Task { await loadPhotos() }
        }
        .onChange(of: locationManager.location) { _, newLocation in
            // Auto-fill location once it becomes available
            if location == nil, !isLoadingLocation, newLocation != nil {
                loadCurrentLocation()
            }
        }
        .onAppear {
            loadCurrentLocation()
        }
    }

    // MARK: - Validation
    private var isValid: Bool {
        !title.isEmpty && location != nil
    }

    // MARK: - Load Current Location
    private func loadCurrentLocation() {
        guard locationManager.authorizationStatus != .denied,
              locationManager.authorizationStatus != .restricted else {
            errorMessage = "Location access denied. Please enable it in Settings."
            return
        }

        guard let currentLocation = locationManager.location else {
            // Location not available yet; request tracking and wait for onChange
            locationManager.startTracking()
            return
        }

        isLoadingLocation = true
        errorMessage = nil

        Task {
            do {
                let address = try await locationManager.reverseGeocode(location: currentLocation)
                location = MemoryLocation(coordinate: currentLocation.coordinate, address: address)
            } catch {
                location = MemoryLocation(coordinate: currentLocation.coordinate)
            }
            isLoadingLocation = false
        }
    }

    // MARK: - Load Photos
    private func loadPhotos() async {
        selectedImages = []
        for photo in selectedPhotos {
            if let data = try? await photo.loadTransferable(type: Data.self),
               let image = PlatformImage(data: data) {
                selectedImages.append(image)
            }
        }
    }

    // MARK: - Create Memory
    private func createMemory() async {
        // Accept both .paired and .authenticated states
        let currentUser: User?
        switch authViewModel.authState {
        case .paired(let user, _):  currentUser = user
        case .authenticated(let user): currentUser = user
        default: currentUser = nil
        }

        guard isValid,
              let user = currentUser,
              let userId = user.id,
              let location = location else {
            errorMessage = "Please fill in a title and make sure your location is set."
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            try await memoryViewModel.createMemory(
                coupleId: couple.id ?? "",
                userId: userId,
                title: title,
                emoji: selectedEmoji,
                description: description.isEmpty ? nil : description,
                location: location,
                date: selectedDate,
                isPrivate: isPrivate,
                images: selectedImages
            )
            isSaving = false
            if let warning = memoryViewModel.errorMessage {
                photoWarningMessage = warning
                memoryViewModel.errorMessage = nil
                showPhotoWarning = true
            } else {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}

// MARK: - Emoji Picker View
struct EmojiPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedEmoji: String

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(EmojiCategory.categories, id: \.name) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(category.name)
                                .font(.headline)
                                .foregroundColor(AppTheme.textSecondary)
                                .padding(.horizontal)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                                ForEach(category.emojis, id: \.self) { emoji in
                                    Button {
                                        selectedEmoji = emoji
                                        dismiss()
                                    } label: {
                                        Text(emoji)
                                            .font(.system(size: 40))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.5)
                                            .frame(width: 50, height: 50)
                                            .contentShape(Circle())
                                            .background(
                                                selectedEmoji == emoji ?
                                                AppTheme.secondaryBackground :
                                                Color.clear
                                            )
                                            .clipShape(Circle())
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Choose Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppTheme.primary)
                }
            }
        }
    }
}

// MARK: - Platform Image View
struct PlatformImageView: View {
    let image: PlatformImage

    var body: some View {
        #if canImport(UIKit)
        Image(uiImage: image).resizable()
        #elseif canImport(AppKit)
        Image(nsImage: image).resizable()
        #else
        Image(systemName: "photo").resizable()
        #endif
    }
}

#Preview {
    CreateMemoryView(
        couple: Couple(
            id: "1",
            user1Id: "user1",
            user2Id: "user2",
            coupleCode: "ABC123",
            relationshipStart: Date(),
            createdAt: Date()
        )
    )
    .environmentObject(MemoryViewModel())
    .environmentObject(LocationManager())
    .environmentObject(AuthViewModel())
}
