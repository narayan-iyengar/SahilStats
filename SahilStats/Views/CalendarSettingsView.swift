//
//  CalendarSettingsView.swift
//  SahilStats
//
//  Calendar selection and settings for multi-team support
//

import SwiftUI
import EventKit

struct CalendarSettingsView: View {
    @ObservedObject private var calendarManager = GameCalendarManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var availableCalendars: [EKCalendar] = []
    @State private var selectedCalendarIds: Set<String>
    @State private var showingPermissionAlert = false

    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    init() {
        _selectedCalendarIds = State(initialValue: Set(GameCalendarManager.shared.selectedCalendars))
    }

    var body: some View {
        Group {
            if !calendarManager.hasCalendarAccess {
                permissionView
            } else {
                calendarSelectionView
            }
        }
        .navigationTitle("Calendar Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if calendarManager.hasCalendarAccess {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        loadCalendars()
                    }
                }
            }
        }
        .onAppear {
            loadCalendars()
        }
        .onDisappear {
            saveSelections()
        }
    }

    // MARK: - Permission View

    private var permissionView: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)

                Text("Calendar Access Required")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("To automatically fill game details from your calendar, we need permission to access your calendars.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Grant Calendar Access") {
                Task {
                    let granted = await calendarManager.requestCalendarAccess()
                    if granted {
                        loadCalendars()
                    }
                }
            }
            .buttonStyle(UnifiedPrimaryButtonStyle(isIPad: isIPad))
            .padding(.horizontal, 40)
        }
        .padding()
    }

    // MARK: - Calendar Selection View

    private var calendarSelectionView: some View {
        List {
            Section {
                Text("Select which calendars contain basketball games. You can choose multiple calendars if Sahil plays for different teams.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .listRowBackground(Color.clear)

            // Weekends-only filter toggle
            Section {
                Toggle(isOn: Binding(
                    get: { calendarManager.weekendsOnly },
                    set: { calendarManager.saveWeekendsOnlySetting($0) }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weekends Only")
                            .font(.body)
                        Text("Show only Saturday and Sunday events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.orange)
            } header: {
                Text("Filters")
            } footer: {
                Text("Most games are on weekends. Turn this off to see all calendar events, including weekday practices and tournaments.")
                    .font(.caption)
            }

            if availableCalendars.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Loading calendars...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                }
            } else {
                Section("Available Calendars") {
                    ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                        CalendarRow(
                            calendar: calendar,
                            isSelected: selectedCalendarIds.contains(calendar.calendarIdentifier),
                            onToggle: {
                                toggleCalendar(calendar)
                            }
                        )
                    }
                }
            }

            if !selectedCalendarIds.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("\(selectedCalendarIds.count) calendar(s) selected")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Text("Games from these calendars will appear in 'Upcoming Games'")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Button("Clear All Selections") {
                    selectedCalendarIds.removeAll()
                }
                .foregroundColor(.red)
                .disabled(selectedCalendarIds.isEmpty)
            }

            Section("Calendar Examples") {
                VStack(alignment: .leading, spacing: 12) {
                    ExampleRow(
                        icon: "checkmark.circle.fill",
                        title: "Sahil - Cavaliers",
                        subtitle: "Main team calendar",
                        color: .blue
                    )

                    ExampleRow(
                        icon: "checkmark.circle.fill",
                        title: "Sahil - Summer League",
                        subtitle: "Summer season calendar",
                        color: .orange
                    )

                    ExampleRow(
                        icon: "checkmark.circle.fill",
                        title: "Basketball - All Games",
                        subtitle: "Combined calendar",
                        color: .green
                    )
                }
                .font(.caption)
            }
            .listRowBackground(Color(.systemGray6))
        }
    }

    // MARK: - Actions

    private func loadCalendars() {
        guard calendarManager.hasCalendarAccess else { return }

        availableCalendars = calendarManager.getAvailableCalendars()
            .sorted { $0.title < $1.title }

        debugPrint("📅 Loaded \(availableCalendars.count) calendars")
        for calendar in availableCalendars {
            debugPrint("   - \(calendar.title) (\(calendar.source.title))")
        }
    }

    private func toggleCalendar(_ calendar: EKCalendar) {
        if selectedCalendarIds.contains(calendar.calendarIdentifier) {
            selectedCalendarIds.remove(calendar.calendarIdentifier)
            forcePrint("❌ Deselected calendar: \(calendar.title)")
        } else {
            selectedCalendarIds.insert(calendar.calendarIdentifier)
            debugPrint("✅ Selected calendar: \(calendar.title)")
        }
    }

    private func saveSelections() {
        let selectedIds = Array(selectedCalendarIds)
        calendarManager.saveSelectedCalendars(selectedIds)
        debugPrint("💾 Saved \(selectedIds.count) selected calendar(s)")
    }
}

// MARK: - Calendar Row

struct CalendarRow: View {
    let calendar: EKCalendar
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Calendar color indicator
                Circle()
                    .fill(Color(calendar.cgColor))
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.title)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text(calendar.source.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Example Row

struct ExampleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    CalendarSettingsView()
}
