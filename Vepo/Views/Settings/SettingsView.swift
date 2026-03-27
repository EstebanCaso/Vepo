import SwiftUI

/// User preferences screen.
/// Controls reminder timing, notification type, and quiet hours.
struct SettingsView: View {
    @Environment(SettingsViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            List {
                // Reminder section
                reminderSection

                // Notification type
                notificationTypeSection

                // Quiet hours
                quietHoursSection

                // About
                aboutSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(VepoTheme.Colors.background)
            .navigationTitle("Settings")
            .task {
                await viewModel.load()
            }
        }
    }

    // MARK: - Reminder Section

    private var reminderSection: some View {
        Section {
            VStack(alignment: .leading, spacing: VepoTheme.Spacing.xs) {
                HStack {
                    Text("Remind after")
                        .font(VepoTheme.Typography.body)
                    Spacer()
                    Text("\(viewModel.reminderMinutes) min")
                        .font(VepoTheme.Typography.headline)
                        .foregroundStyle(VepoTheme.Colors.accent)
                }

                Slider(
                    value: Binding(
                        get: { Double(viewModel.reminderMinutes) },
                        set: { newValue in
                            viewModel.reminderMinutes = Int(newValue)
                            Task { await viewModel.save() }
                        }
                    ),
                    in: 15...120,
                    step: 5
                )
                .tint(VepoTheme.Colors.accent)
                .accessibilityLabel("Reminder wait time")
                .accessibilityValue("\(viewModel.reminderMinutes) minutes")
            }

            Toggle(isOn: Binding(
                get: { viewModel.isPaused },
                set: { newValue in
                    viewModel.isPaused = newValue
                    Task { await viewModel.save() }
                }
            )) {
                Label("Pause reminders", systemImage: "pause.circle")
            }
            .tint(VepoTheme.Colors.accent)
        } header: {
            Text("Reminders")
        } footer: {
            Text("How long to wait after your last drink before sending a reminder.")
                .font(VepoTheme.Typography.footnote)
        }
    }

    // MARK: - Notification Type

    private var notificationTypeSection: some View {
        Section("Notification Style") {
            ForEach(NotificationType.allCases, id: \.self) { type in
                Button {
                    viewModel.notificationType = type
                    Task { await viewModel.save() }
                } label: {
                    HStack {
                        Label(type.displayName, systemImage: type.icon)
                            .foregroundStyle(VepoTheme.Colors.textPrimary)

                        Spacer()

                        if viewModel.notificationType == type {
                            Image(systemName: "checkmark")
                                .foregroundStyle(VepoTheme.Colors.accent)
                        }
                    }
                }
                .accessibilityLabel(type.displayName)
                .accessibilityAddTraits(
                    viewModel.notificationType == type ? .isSelected : []
                )
            }
        }
    }

    // MARK: - Quiet Hours

    private var quietHoursSection: some View {
        Section {
            HStack {
                Text("Active from")
                Spacer()
                Picker("Start hour", selection: Binding(
                    get: { viewModel.activeStartHour },
                    set: { newValue in
                        viewModel.activeStartHour = newValue
                        Task { await viewModel.save() }
                    }
                )) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(formatHour(hour)).tag(hour)
                    }
                }
                .labelsHidden()
            }

            HStack {
                Text("Active until")
                Spacer()
                Picker("End hour", selection: Binding(
                    get: { viewModel.activeEndHour },
                    set: { newValue in
                        viewModel.activeEndHour = newValue
                        Task { await viewModel.save() }
                    }
                )) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(formatHour(hour)).tag(hour)
                    }
                }
                .labelsHidden()
            }
        } header: {
            Text("Active Hours")
        } footer: {
            Text("Reminders will only be sent during these hours.")
                .font(VepoTheme.Typography.footnote)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0.0")
            LabeledContent("Notifications") {
                Text(viewModel.hasNotificationPermission ? "Enabled" : "Disabled")
                    .foregroundStyle(
                        viewModel.hasNotificationPermission
                            ? VepoTheme.Colors.success
                            : VepoTheme.Colors.alert
                    )
            }
        }
    }

    // MARK: - Helpers

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let date = Calendar.current.date(
            bySettingHour: hour, minute: 0, second: 0, of: .now
        ) ?? .now
        return formatter.string(from: date)
    }
}
