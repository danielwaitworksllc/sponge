import Foundation
import SwiftData

@Model
final class SDClass: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var folderBookmark: Data?

    // Schedule: days stored as a bitmask (Sun=1, Mon=2, Tue=4, Wed=8, Thu=16, Fri=32, Sat=64)
    // Times stored as minutes since midnight (e.g. 9:30 AM = 570)
    var scheduleDaysMask: Int = 0       // 0 = no schedule set
    var scheduleStartMinute: Int = 540  // default 9:00 AM
    var scheduleEndMinute: Int = 600    // default 10:00 AM

    @Relationship(deleteRule: .cascade, inverse: \SDRecording.sdClass)
    var recordings: [SDRecording] = []

    init(id: UUID = UUID(), name: String, folderBookmark: Data? = nil) {
        self.id = id
        self.name = name
        self.folderBookmark = folderBookmark
    }

    // MARK: - Schedule Helpers

    var hasSchedule: Bool { scheduleDaysMask != 0 }

    static let dayBits: [(weekday: Int, label: String)] = [
        (2, "Mon"), (4, "Tue"), (8, "Wed"), (16, "Thu"), (32, "Fri"), (64, "Sat"), (1, "Sun")
    ]

    func isScheduled(on weekday: Int) -> Bool {
        // weekday is Calendar.current.component(.weekday): Sun=1 … Sat=7
        // Our bitmask stores bit = 2^(weekday-1): Sun=1, Mon=2, Tue=4 … Sat=64
        let bit = 1 << (weekday - 1)
        return scheduleDaysMask & bit != 0
    }

    /// Returns true if the given date falls within this class's scheduled window (±15 min buffer).
    func isInSession(at date: Date = Date()) -> Bool {
        guard hasSchedule else { return false }
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        guard isScheduled(on: weekday) else { return false }
        let minuteOfDay = cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
        return minuteOfDay >= (scheduleStartMinute - 15) && minuteOfDay <= (scheduleEndMinute + 15)
    }

    var scheduleDisplayString: String {
        guard hasSchedule else { return "No schedule" }
        // dayBits entries: weekday is the raw bit value; convert back to Calendar weekday for isScheduled()
        // Calendar weekday: Sun=1, Mon=2 … Sat=7. Our bit = 2^(weekday-1).
        let days = Self.dayBits.filter { entry in
            scheduleDaysMask & entry.weekday != 0
        }.map { $0.label }
        let start = minutesToTimeString(scheduleStartMinute)
        let end = minutesToTimeString(scheduleEndMinute)
        return "\(days.joined(separator: "/"))  \(start)–\(end)"
    }

    private func minutesToTimeString(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        let ampm = h < 12 ? "AM" : "PM"
        let hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return String(format: "%d:%02d %@", hour12, m, ampm)
    }

    // MARK: - Folder Resolution

    func resolveFolder() -> URL? {
        guard let bookmarkData = folderBookmark else { return nil }

        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData,
                              options: .withSecurityScope,
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)

            if isStale { return nil }
            return url
        } catch {
            return nil
        }
    }

    static func createBookmark(for url: URL) -> Data? {
        do {
            return try url.bookmarkData(options: .withSecurityScope,
                                         includingResourceValuesForKeys: nil,
                                         relativeTo: nil)
        } catch {
            return nil
        }
    }

    var saveDestination: SaveDestination { .localOnly }

    var isConfigurationValid: Bool {
        folderBookmark != nil && resolveFolder() != nil
    }

    var hasLocalFolder: Bool {
        folderBookmark != nil && resolveFolder() != nil
    }

    /// Convert from legacy ClassModel for migration
    convenience init(from legacy: ClassModel) {
        self.init(id: legacy.id, name: legacy.name, folderBookmark: legacy.folderBookmark)
    }
}

@Model
final class SDRecording {
    @Attribute(.unique) var id: UUID
    var classId: UUID
    var date: Date
    var duration: TimeInterval
    var audioFileName: String
    var transcriptText: String
    var userNotes: String
    var classNotes: String?
    var pdfExported: Bool
    var name: String

    // Complex types stored as JSON-encoded Data
    var intentMarkersData: Data?
    var enhancedSummaryData: Data?
    var recallPromptsData: Data?
    var catchUpSummariesData: Data?
    var whisperSegmentsData: Data?

    var sdClass: SDClass?

    init(
        id: UUID = UUID(),
        classId: UUID,
        date: Date = Date(),
        duration: TimeInterval = 0,
        audioFileName: String,
        transcriptText: String = "",
        userNotes: String = "",
        classNotes: String? = nil,
        pdfExported: Bool = false,
        name: String = "",
        intentMarkers: [IntentMarker] = [],
        enhancedSummary: EnhancedSummary? = nil,
        recallPrompts: RecallPrompts? = nil,
        catchUpSummaries: [CatchUpSummary] = []
    ) {
        self.id = id
        self.classId = classId
        self.date = date
        self.duration = duration
        self.audioFileName = audioFileName
        self.transcriptText = transcriptText
        self.userNotes = userNotes
        self.classNotes = classNotes
        self.pdfExported = pdfExported
        self.name = name
        self.intentMarkers = intentMarkers
        self.enhancedSummary = enhancedSummary
        self.recallPrompts = recallPrompts
        self.catchUpSummaries = catchUpSummaries
    }

    // MARK: - Computed accessors for complex types

    var intentMarkers: [IntentMarker] {
        get {
            guard let data = intentMarkersData else { return [] }
            return (try? JSONDecoder().decode([IntentMarker].self, from: data)) ?? []
        }
        set {
            intentMarkersData = try? JSONEncoder().encode(newValue)
        }
    }

    var enhancedSummary: EnhancedSummary? {
        get {
            guard let data = enhancedSummaryData else { return nil }
            return try? JSONDecoder().decode(EnhancedSummary.self, from: data)
        }
        set {
            enhancedSummaryData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }

    var recallPrompts: RecallPrompts? {
        get {
            guard let data = recallPromptsData else { return nil }
            return try? JSONDecoder().decode(RecallPrompts.self, from: data)
        }
        set {
            recallPromptsData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }

    var catchUpSummaries: [CatchUpSummary] {
        get {
            guard let data = catchUpSummariesData else { return [] }
            return (try? JSONDecoder().decode([CatchUpSummary].self, from: data)) ?? []
        }
        set {
            catchUpSummariesData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Whisper segment-level timestamps stored for future playback sync / timestamped transcript UI.
    var whisperSegments: [WhisperSegment] {
        get {
            guard let data = whisperSegmentsData else { return [] }
            return (try? JSONDecoder().decode([WhisperSegment].self, from: data)) ?? []
        }
        set {
            whisperSegmentsData = try? JSONEncoder().encode(newValue)
        }
    }

    // MARK: - Audio File

    func audioFileURL() -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsPath?.appendingPathComponent("Recordings").appendingPathComponent(audioFileName)
    }

    // MARK: - Formatting

    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var formattedDate: String {
        Self.displayDateFormatter.string(from: date)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var hasConfusionMarkers: Bool {
        intentMarkers.contains { $0.type == .confused }
    }

    var hasExamMarkers: Bool {
        intentMarkers.contains { $0.type == .examRelevant || $0.type == .important }
    }

    var markerCounts: [IntentMarkerType: Int] {
        Dictionary(grouping: intentMarkers, by: { $0.type }).mapValues { $0.count }
    }

    // MARK: - Name Generation

    private static let nameDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    private static let nameTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        f.amSymbol = "am"
        f.pmSymbol = "pm"
        return f
    }()

    static func generateDefaultName(className: String? = nil, date: Date) -> String {
        let datePart = nameDateFormatter.string(from: date)
        let timePart = nameTimeFormatter.string(from: date)

        if let className = className {
            return "\(className), \(datePart), \(timePart)"
        } else {
            return "\(datePart), \(timePart)"
        }
    }

    /// Convert from legacy RecordingModel for migration
    convenience init(from legacy: RecordingModel) {
        self.init(
            id: legacy.id,
            classId: legacy.classId,
            date: legacy.date,
            duration: legacy.duration,
            audioFileName: legacy.audioFileName,
            transcriptText: legacy.transcriptText,
            userNotes: legacy.userNotes,
            classNotes: legacy.classNotes,
            pdfExported: legacy.pdfExported,
            name: legacy.name,
            intentMarkers: legacy.intentMarkers,
            enhancedSummary: legacy.enhancedSummary,
            recallPrompts: legacy.recallPrompts,
            catchUpSummaries: legacy.catchUpSummaries
        )
    }
}
