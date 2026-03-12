import Foundation
import SwiftUI
import SwiftData
import os

@MainActor
class ClassViewModel: ObservableObject {
    @Published var classes: [SDClass] = []
    @Published var recordings: [SDRecording] = []
    @Published var selectedClass: SDClass?
    @Published var lastError: String?
    @Published var suggestedClassBanner: String? // non-nil shows the auto-select banner

    private let logger = Logger(subsystem: "com.sponge.app", category: "ClassViewModel")
    private let persistence = PersistenceService.shared

    init() {
        // Migrate legacy data on first launch
        persistence.migrateFromUserDefaultsIfNeeded()
        loadClasses()
        loadRecordings()
    }

    // MARK: - Class Management

    func addClass(name: String, folderURL: URL?,
                  scheduleDaysMask: Int = 0,
                  scheduleStartMinute: Int = 540,
                  scheduleEndMinute: Int = 600) {
        let newClass = persistence.addClass(name: name, folderURL: folderURL)
        newClass.scheduleDaysMask = scheduleDaysMask
        newClass.scheduleStartMinute = scheduleStartMinute
        newClass.scheduleEndMinute = scheduleEndMinute
        persistence.saveContext()
        classes.append(newClass)

        if selectedClass == nil {
            selectedClass = newClass
        }

        NotificationService.shared.rescheduleAll(for: classes)
    }

    func updateClass(_ classModel: SDClass, name: String, folderURL: URL?) {
        persistence.updateClass(classModel, name: name, folderURL: folderURL)

        // Refresh the list
        loadClasses()

        if selectedClass?.id == classModel.id {
            selectedClass = classModel
        }

        NotificationService.shared.rescheduleAll(for: classes)
    }

    func deleteClass(_ classModel: SDClass) {
        // Also delete associated recordings
        let classRecordings = recordings.filter { $0.classId == classModel.id }
        for recording in classRecordings {
            persistence.deleteRecording(recording)
        }

        persistence.deleteClass(classModel)

        classes.removeAll { $0.id == classModel.id }
        recordings.removeAll { $0.classId == classModel.id }

        if selectedClass?.id == classModel.id {
            selectedClass = classes.first
        }

        NotificationService.shared.rescheduleAll(for: classes)
    }

    // MARK: - Recording Management

    func addRecording(_ recording: SDRecording) {
        persistence.addRecording(recording)
        recordings.append(recording)
    }

    func updateRecording(_ recording: SDRecording) {
        persistence.saveContext()
        // Refresh
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index] = recording
        }
    }

    func deleteRecording(_ recording: SDRecording) {
        persistence.deleteRecording(recording)
        recordings.removeAll { $0.id == recording.id }
    }

    func recordingsForSelectedClass() -> [SDRecording] {
        guard let selectedClass = selectedClass else { return [] }
        return recordings.filter { $0.classId == selectedClass.id }.sorted { $0.date > $1.date }
    }

    func className(for classId: UUID) -> String {
        return classes.first { $0.id == classId }?.name ?? "Unknown Class"
    }

    // MARK: - Data Loading

    private func loadClasses() {
        classes = persistence.fetchClasses()

        // Auto-select: prefer a class currently in session; fall back to first class
        if let inSession = suggestedClass() {
            selectedClass = inSession
            suggestedClassBanner = "Suggested: \(inSession.name) is on your schedule right now"
        } else if selectedClass == nil {
            selectedClass = classes.first
        }
    }

    /// Returns the class currently scheduled at the given time, if any.
    func suggestedClass(at date: Date = Date()) -> SDClass? {
        classes.first { $0.isInSession(at: date) }
    }

    private func loadRecordings() {
        recordings = persistence.fetchAllRecordings()
    }
}
