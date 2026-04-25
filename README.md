# FootPrints 💕

An iOS app for couples to pin shared memories on a map — every date, trip, and moment saved at the exact location it happened.

## Features

- **Memory Map** — drop pins anywhere on a real 3D map, each tagged with a custom emoji
- **Photo Upload** — attach up to 10 photos per memory
- **Timeline** — scroll through all memories chronologically with search
- **Couple Pairing** — connect with your partner using a 6-character code; memories are shared in real time
- **Location Awareness** — get notified when you revisit a place where a memory was made
- **Private Memories** — mark any memory visible only to yourself
- **Relationship Stats** — see days together and total memories on the map

## Tech Stack

| Layer | Technology |
|---|---|
| Platform | iOS 17+ (SwiftUI) |
| Auth | Firebase Authentication |
| Database | Cloud Firestore |
| Storage | Firebase Storage |
| Location | CoreLocation + MapKit |
| Notifications | UserNotifications |

## Project Structure

```
FootPrint/
├── FootPrintsApp.swift       # App entry point, Firebase init
├── ContentView.swift         # Root auth state router
├── Models.swift              # User, Couple, Memory, MemoryLocation
├── AuthViewModel.swift       # Sign up, sign in, pairing logic
├── MemoryViewModel.swift     # CRUD for memories + photo upload
├── LocationManager.swift     # GPS tracking, geofencing, reverse geocode
├── MapView.swift             # Main map screen
├── CreateMemoryView.swift    # New memory form
├── MemoryDetailView.swift    # View/edit a single memory
├── TimelineView.swift        # Chronological memory list
├── PairingView.swift         # Partner pairing flow
├── SettingsView.swift        # Account + notification settings
├── SignInView.swift           # Login screen
├── SignUpView.swift           # Registration screen
├── WelcomeView.swift          # Onboarding / landing screen
└── Theme.swift               # Colors, fonts, shared styles
```

## Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication** (Email/Password)
3. Enable **Cloud Firestore**
4. Enable **Firebase Storage** (Blaze plan required)
5. Download `GoogleService-Info.plist` and add it to the Xcode project

### Firestore Rules

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null &&
        request.auth.uid == userId;
    }
    match /couples/{coupleId} {
      allow read: if request.auth != null && (
        request.auth.uid == resource.data.user1_id ||
        request.auth.uid == resource.data.user2_id ||
        resource.data.user2_id == ""
      );
      allow update: if request.auth != null && (
        request.auth.uid == resource.data.user1_id ||
        resource.data.user2_id == ""
      );
      allow create: if request.auth != null;
      allow delete: if request.auth != null && (
        request.auth.uid == resource.data.user1_id ||
        request.auth.uid == resource.data.user2_id
      );
    }
    match /memories/{memoryId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Storage Rules

```js
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Getting Started

1. Clone the repo
2. Open `FootPrint.xcodeproj` in Xcode
3. Add your own `GoogleService-Info.plist` (not included — contains API keys)
4. Build and run on an iOS 17+ simulator or device

## Author

Built by [Mudit Chaudhary](https://github.com/mudit7011)
