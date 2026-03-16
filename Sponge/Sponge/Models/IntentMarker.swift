import Foundation
import SwiftUI

/// Types of intent markers that students can add during recording
enum IntentMarkerType: String, Codable, CaseIterable, Identifiable {
    case confused
    case important
    case examRelevant
    case reviewLater

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .confused:
            return "questionmark.circle.fill"
        case .important:
            return "exclamationmark.circle.fill"
        case .examRelevant:
            return "star.fill"
        case .reviewLater:
            return "bookmark.fill"
        }
    }

    var displayName: String {
        switch self {
        case .confused:
            return "Confused"
        case .important:
            return "Important"
        case .examRelevant:
            return "Exam"
        case .reviewLater:
            return "Review"
        }
    }

    var shortLabel: String {
        switch self {
        case .confused:
            return "?"
        case .important:
            return "!"
        case .examRelevant:
            return "★"
        case .reviewLater:
            return "▸"
        }
    }

    var color: String {
        switch self {
        case .confused:
            return "orange"
        case .important:
            return "red"
        case .examRelevant:
            return "yellow"
        case .reviewLater:
            return "blue"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .confused:
            return .orange
        case .important:
            return .red
        case .examRelevant:
            return .yellow
        case .reviewLater:
            return .blue
        }
    }
}

/// A marker placed by the student during recording to signal intent
struct IntentMarker: Identifiable, Codable {
    let id: UUID
    let type: IntentMarkerType
    let timestamp: TimeInterval        // From currentDuration (0.1s precision)
    let transcriptSnapshot: String?    // Last ~30 words for context

    init(id: UUID = UUID(), type: IntentMarkerType, timestamp: TimeInterval, transcriptSnapshot: String? = nil) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.transcriptSnapshot = transcriptSnapshot
    }

    /// Formats the timestamp as MM:SS
    var formattedTimestamp: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
