import SwiftUI

struct ClassManagementView: View {
    @EnvironmentObject var classViewModel: ClassViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddClass = false
    @State private var classToEdit: SDClass?

    var body: some View {
        NavigationStack {
            Group {
                if classViewModel.classes.isEmpty {
                    emptyStateView
                } else {
                    classList
                }
            }
            .background(SpongeTheme.coralPale.opacity(0.4))
            .navigationTitle("Manage Classes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddClass = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddClass) {
                ClassEditorView(classToEdit: nil)
                    .environmentObject(classViewModel)
            }
            .sheet(item: $classToEdit) { classModel in
                ClassEditorView(classToEdit: classModel)
                    .environmentObject(classViewModel)
            }
        }
        .frame(minWidth: 450, minHeight: 350)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No Classes")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)

            Text("Add your first class to start\nrecording and transcribing lectures")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingAddClass = true
            } label: {
                Label("Add Class", systemImage: "plus")
                    .font(.headline)
            }
            .buttonStyle(PrimaryButtonStyle(color: SpongeTheme.coral))
            .padding(.top, 8)

            Spacer()
        }
        .padding()
    }

    // MARK: - Class List

    private var classList: some View {
        List {
            ForEach(classViewModel.classes) { classModel in
                ClassRowView(classModel: classModel) {
                    classToEdit = classModel
                }
            }
            .onDelete(perform: deleteClasses)
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }

    private func deleteClasses(at offsets: IndexSet) {
        for index in offsets {
            classViewModel.deleteClass(classViewModel.classes[index])
        }
    }
}

// MARK: - Class Row View

struct ClassRowView: View {
    let classModel: SDClass
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Class icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "folder.fill")
                    .font(.system(size: 18))
                    .foregroundColor(statusColor)
            }

            // Class info
            VStack(alignment: .leading, spacing: 4) {
                Text(classModel.name)
                    .font(.body.weight(.medium))

                HStack(spacing: 8) {
                    Label(classModel.saveDestination.displayName, systemImage: "folder")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if classModel.isConfigurationValid {
                        Label("Configured", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Label("Setup needed", systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Edit button
            Button {
                onEdit()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }

    private var statusColor: Color {
        classModel.isConfigurationValid ? SpongeTheme.coral : .orange
    }
}

#Preview {
    ClassManagementView()
        .environmentObject(ClassViewModel())
}
