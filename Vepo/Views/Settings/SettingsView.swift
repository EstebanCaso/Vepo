import SwiftUI

/// User preferences screen.
/// Controls reminder timing, notification type, and quiet hours.
struct SettingsView: View {
    @Environment(SettingsViewModel.self) private var viewModel

    var body: some View {
        NavigationStack {
            List {
                reminderSection
                notificationTypeSection
                quietHoursSection
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
                        .font(VepoTheme.Typography.title3)
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
            sectionHeader("Reminders")
        } footer: {
            Text("How long to wait after your last drink before sending a reminder.")
                .font(VepoTheme.Typography.footnote)
        }
    }

    // MARK: - Notification Type

    private var notificationTypeSection: some View {
        Section {
            ForEach(NotificationType.allCases, id: \.self) { type in
                Button {
                    withAnimation(VepoTheme.Motion.standard) {
                        viewModel.notificationType = type
                    }
                    Task { await viewModel.save() }
                } label: {
                    HStack(spacing: VepoTheme.Spacing.sm) {
                        // Radio indicator
                        ZStack {
                            Circle()
                                .strokeBorder(
                                    viewModel.notificationType == type
                                        ? VepoTheme.Colors.accent
                                        : VepoTheme.Colors.disabled,
                                    lineWidth: 2
                                )
                                .frame(width: 22, height: 22)

                            if viewModel.notificationType == type {
                                Circle()
                                    .fill(VepoTheme.Colors.accent)
                                    .frame(width: 12, height: 12)
                            }
                        }

                        Label(type.displayName, systemImage: type.icon)
                            .foregroundStyle(VepoTheme.Colors.textPrimary)

                        Spacer()
                    }
                }
                .accessibilityLabel(type.displayName)
                .accessibilityAddTraits(
                    viewModel.notificationType == type ? .isSelected : []
                )
            }
        } header: {
            sectionHeader("Notification Style")
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
                .tint(VepoTheme.Colors.accent)
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
                .tint(VepoTheme.Colors.accent)
            }
        } header: {
            sectionHeader("Active Hours")
        } footer: {
            Text("Reminders will only be sent during these hours.")
                .font(VepoTheme.Typography.footnote)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: "1.0.0")
            LabeledContent("Notifications") {
                HStack(spacing: VepoTheme.Spacing.xxs) {
                    Circle()
                        .fill(
                            viewModel.hasNotificationPermission
                                ? VepoTheme.Colors.success
                                : VepoTheme.Colors.alert
                        )
                        .frame(width: 8, height: 8)
                    Text(viewModel.hasNotificationPermission ? "Enabled" : "Disabled")
                        .foregroundStyle(
                            viewModel.hasNotificationPermission
                                ? VepoTheme.Colors.success
                                : VepoTheme.Colors.alert
                        )
                }
            }
        } header: {
            sectionHeader("About")
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(VepoTheme.Colors.accent)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    private func formatHour(_ hour: Int) -> String {
        let date = Calendar.current.date(
            bySettingHour: hour, minute: 0, second: 0, of: .now
        ) ?? .now
        return Date.hourFormatter.string(from: date)
    }
}
