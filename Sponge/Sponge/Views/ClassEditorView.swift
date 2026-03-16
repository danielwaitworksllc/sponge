import SwiftUI
import AppKit

struct ClassEditorView: View {
    @EnvironmentObject var classViewModel: ClassViewModel
    @Environment(\.dismiss) private var dismiss

    let classToEdit: SDClass?

    @State private var className: String = ""
    @State private var selectedFolderURL: URL?

    // Schedule state (mirrors SDClass fields)
    @State private var scheduleDaysMask: Int = 0
    @State private var scheduleStart: Date = ClassEditorView.minutesToDate(540) // 9:00 AM
    @State private var scheduleEnd: Date = ClassEditorView.minutesToDate(600)   // 10:00 AM

    var isEditing: Bool { classToEdit != nil }

    var body: some View {
        NavigationStack {
            Form {                // Class Name Section
                Section {
                    TextField("e.g., Biology 101", text: $className)
                        .font(.body)
                } header: {
                    Label("Class Name", systemImage: "textformat")
                }

                // Schedule Section
                Section {
                    scheduleRow
                } header: {
                    Label("Class Schedule", systemImage: "calendar.badge.clock")
                } footer: {
                    Text("Sponge will auto-suggest this class when you open the app during its scheduled time (±15 min).")
                }

                // Local Folder Section
                Section {
                    localFolderRow
                } header: {
                    Label("Save Location", systemImage: "folder")
                } footer: {
                    Text("PDF transcripts will be saved to this folder on your device.")
                }

                if selectedFolderURL == nil && !className.isEmpty {
                    Section {
                        Label("Please select a local folder", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(SpongeTheme.surfaceSecondary)
            .navigationTitle(isEditing ? "Edit Class" : "New Class")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { saveClass() }
                        .fontWeight(.semibold)
                        .disabled(className.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let c = classToEdit {
                    className = c.name
                    selectedFolderURL = c.resolveFolder()
                    scheduleDaysMask = c.scheduleDaysMask
                    scheduleStart = ClassEditorView.minutesToDate(c.scheduleStartMinute)
                    scheduleEnd = ClassEditorView.minutesToDate(c.scheduleEndMinute)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 360)
    }

    // MARK: - Schedule Row

    private var scheduleRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Day picker
            HStack(spacing: 6) {
                ForEach(SDClass.dayBits, id: \.weekday) { day in
                    let bit = day.weekday
                    let isOn = scheduleDaysMask & bit != 0
                    Button {
                        if isOn { scheduleDaysMask &= ~bit } else { scheduleDaysMask |= bit }
                    } label: {
                        Text(day.label)
                            .font(.caption)
                            .fontWeight(isOn ? .semibold : .regular)
                            .frame(width: 40, height: SpongeTheme.controlSizeS)
                            .background(isOn ? SpongeTheme.coral : SpongeTheme.cream)
                            .foregroundColor(isOn ? .white : .primary)
                            .cornerRadius(SpongeTheme.cornerRadiusXS)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Time pickers (only shown when at least one day is selected)
            if scheduleDaysMask != 0 {
                HStack(spacing: 16) {
                    LabeledContent("Start") {
                        DatePicker("", selection: $scheduleStart, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    LabeledContent("End") {
                        DatePicker("", selection: $scheduleEnd, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Local Folder Row

    private var localFolderRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let url = selectedFolderURL {
                    Text(url.lastPathComponent).font(.body)
                    Text(url.path)
                        .font(.caption).foregroundColor(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                        .help(url.path)
                } else {
                    Text("No folder selected").font(.body).foregroundColor(.secondary)
                }
            }
            Spacer()
            if selectedFolderURL != nil {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            }
            Button("Choose") { selectFolder() }
                .buttonStyle(.bordered).controlSize(.small)
        }
    }

    // MARK: - Actions

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Choose a folder to save PDF transcripts"
        if panel.runModal() == .OK { selectedFolderURL = panel.url }
    }

    private func saveClass() {
        let trimmedName = className.trimmingCharacters(in: .whitespaces)
        let startMinute = ClassEditorView.dateToMinutes(scheduleStart)
        let endMinute = ClassEditorView.dateToMinutes(scheduleEnd)

        if let c = classToEdit {
            c.scheduleDaysMask = scheduleDaysMask
            c.scheduleStartMinute = startMinute
            c.scheduleEndMinute = endMinute
            classViewModel.updateClass(c, name: trimmedName, folderURL: selectedFolderURL)
        } else {
            classViewModel.addClass(name: trimmedName, folderURL: selectedFolderURL,
                                    scheduleDaysMask: scheduleDaysMask,
                                    scheduleStartMinute: startMinute,
                                    scheduleEndMinute: endMinute)
        }
        dismiss()
    }

    // MARK: - Time Helpers

    static func minutesToDate(_ minutes: Int) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = minutes / 60
        comps.minute = minutes % 60
        return cal.date(from: comps) ?? Date()
    }

    static func dateToMinutes(_ date: Date) -> Int {
        let cal = Calendar.current
        return cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
    }
}

#Preview {
    ClassEditorView(classToEdit: nil)
        .environmentObject(ClassViewModel())
}
