//
//  Models.swift
//  FootPrints
//
//  Created by Mudit Chaudhary on 20/04/26.
//

import Foundation
import CoreLocation
import FirebaseFirestore

// MARK: - User Model
struct User: Codable, Identifiable {
    @DocumentID var id: String?
    var email: String
    var name: String
    var profilePhotoURL: String?
    var coupleId: String?
    var coupleCode: String?  // cached on user doc so it's readable without couple doc access
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case profilePhotoURL = "profile_photo"
        case coupleId = "couple_id"
        case coupleCode = "couple_code"
        case createdAt = "created_at"
    }
}

// MARK: - Couple Model
struct Couple: Codable, Identifiable {
    @DocumentID var id: String?
    var user1Id: String
    var user2Id: String
    var coupleCode: String
    var relationshipStart: Date?
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case user1Id = "user1_id"
        case user2Id = "user2_id"
        case coupleCode = "couple_code"
        case relationshipStart = "relationship_start"
        case createdAt = "created_at"
    }
}

// MARK: - Memory Location
struct MemoryLocation: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var address: String?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: Double, longitude: Double, address: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
    }
    
    init(coordinate: CLLocationCoordinate2D, address: String? = nil) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.address = address
    }
}

// MARK: - Memory Model
struct Memory: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var coupleId: String
    var createdBy: String
    var title: String
    var emoji: String
    var description: String?
    var location: MemoryLocation
    var photoURLs: [String]
    var date: Date
    var isPrivate: Bool
    var createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case coupleId = "couple_id"
        case createdBy = "created_by"
        case title
        case emoji
        case description
        case location
        case photoURLs = "photos"
        case date
        case isPrivate = "is_private"
        case createdAt = "created_at"
    }
}

// MARK: - Emoji Categories
struct EmojiCategory {
    let name: String
    let emojis: [String]
}

extension EmojiCategory {
    static let categories: [EmojiCategory] = [
        EmojiCategory(name: "Love", emojis: ["❤️", "💕", "💖", "💗", "💓", "💞", "💘", "💝", "💟", "❣️"]),
        EmojiCategory(name: "Places", emojis: ["🏠", "🏖️", "⛰️", "🏔️", "🗻", "🏕️", "🏞️", "🌅", "🌄", "🌠"]),
        EmojiCategory(name: "Food", emojis: ["🍕", "🍔", "🍣", "🍜", "🍰", "🧁", "☕️", "🍷", "🍹", "🍾"]),
        EmojiCategory(name: "Activities", emojis: ["🎬", "🎵", "🎨", "🎭", "🎪", "🎢", "🎡", "🎠", "🎰", "🎲"]),
        EmojiCategory(name: "Travel", emojis: ["✈️", "🚗", "🚢", "🚁", "🚂", "🗼", "🗽", "🗿", "🏰", "🏯"]),
        EmojiCategory(name: "Celebration", emojis: ["🎉", "🎊", "🎁", "🎈", "🎆", "🎇", "✨", "🎀", "🎂", "🍾"]),
        EmojiCategory(name: "Nature", emojis: ["🌸", "🌺", "🌻", "🌹", "🌷", "🌲", "🌳", "🍂", "🍁", "🌾"]),
        EmojiCategory(name: "Special", emojis: ["💍", "👫", "💏", "💑", "🌟", "⭐️", "💫", "🌙", "☀️", "🌈"])
    ]
}

// MARK: - App State
enum AuthState {
    case loading
    case unauthenticated
    case authenticated(User)
    case paired(User, Couple)
}

// MARK: - Notification Settings
struct NotificationSettings: Codable {
    var enabled: Bool
    var radius: Double // in meters, default 200
    
    static let `default` = NotificationSettings(enabled: true, radius: 200)
}
