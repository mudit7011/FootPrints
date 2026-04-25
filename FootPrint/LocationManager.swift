//
//  LocationManager.swift
//  FootPrints
//
//  Created by Mudit Chaudhary on 20/04/26.
//

import Foundation
import CoreLocation
import UserNotifications
import Combine

class LocationManager: NSObject, ObservableObject {
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var nearbyMemories: [Memory] = []
    
    private let locationManager = CLLocationManager()
    private var memories: [Memory] = []
    private var notificationSettings = NotificationSettings.default
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50 // Update every 50 meters
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Get current authorization status
        authorizationStatus = locationManager.authorizationStatus
        
        // If already authorized, start tracking
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startTracking()
        }
    }
    
    // MARK: - Enable Background Location
    private func enableBackgroundLocationIfAuthorized() {
        // Only enable background location if we have "Always" authorization
        if authorizationStatus == .authorizedAlways {
            locationManager.allowsBackgroundLocationUpdates = true
        }
    }
    
    // MARK: - Request Permissions
    func requestPermissions() {
        // Request "When In Use" permission which is the standard
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    // MARK: - Start Tracking
    func startTracking() {
        enableBackgroundLocationIfAuthorized()
        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
    }
    
    // MARK: - Stop Tracking
    func stopTracking() {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
    }
    
    // MARK: - Setup Geofences
    func setupGeofences(for memories: [Memory], settings: NotificationSettings) {
        self.memories = memories
        self.notificationSettings = settings
        
        // Remove existing geofences
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        
        guard settings.enabled else { return }
        
        // Add geofences for memories (iOS has a limit of 20 regions)
        let sortedMemories = memories.sorted { mem1, mem2 in
            guard let currentLocation = location else { return true }
            let loc1 = CLLocation(latitude: mem1.location.latitude, longitude: mem1.location.longitude)
            let loc2 = CLLocation(latitude: mem2.location.latitude, longitude: mem2.location.longitude)
            return currentLocation.distance(from: loc1) < currentLocation.distance(from: loc2)
        }
        
        for memory in sortedMemories.prefix(20) {
            let region = CLCircularRegion(
                center: memory.location.coordinate,
                radius: settings.radius,
                identifier: memory.id ?? UUID().uuidString
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            
            locationManager.startMonitoring(for: region)
        }
    }
    
    // MARK: - Reverse Geocode
    func reverseGeocode(location: CLLocation) async throws -> String {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        
        guard let placemark = placemarks.first else {
            throw NSError(domain: "LocationManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No address found"])
        }
        
        var addressComponents: [String] = []
        
        if let name = placemark.name {
            addressComponents.append(name)
        }
        if let locality = placemark.locality {
            addressComponents.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            addressComponents.append(administrativeArea)
        }
        if let country = placemark.country {
            addressComponents.append(country)
        }
        
        return addressComponents.joined(separator: ", ")
    }
    
    // MARK: - Send Proximity Notification
    private func sendProximityNotification(for memory: Memory) {
        let content = UNMutableNotificationContent()
        content.title = "💕 You're near a memory!"
        content.body = "Remember when... \(memory.title)"
        content.sound = .default
        content.userInfo = ["memoryId": memory.id ?? ""]
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }
    
    // MARK: - Check Nearby Memories
    private func checkNearbyMemories() {
        guard let currentLocation = location else { return }
        
        let nearby = memories.filter { memory in
            let memoryLocation = CLLocation(
                latitude: memory.location.latitude,
                longitude: memory.location.longitude
            )
            let distance = currentLocation.distance(from: memoryLocation)
            return distance <= notificationSettings.radius
        }
        
        // Find newly nearby memories
        let newNearby = nearby.filter { memory in
            !nearbyMemories.contains { $0.id == memory.id }
        }
        
        // Send notifications for new nearby memories
        for memory in newNearby {
            sendProximityNotification(for: memory)
        }
        
        nearbyMemories = nearby
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.location = location
            print("📍 Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            self.checkNearbyMemories()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let memory = memories.first(where: { $0.id == region.identifier }) else { return }
        sendProximityNotification(for: memory)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            
            print("Location authorization changed to: \(manager.authorizationStatus.rawValue)")
            
            if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
                self.enableBackgroundLocationIfAuthorized()
                self.startTracking()
                print("Location tracking started")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error)")
    }
}
