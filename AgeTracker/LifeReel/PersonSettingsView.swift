//
//  PersonSettingsView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/2/24.
//

import Foundation
import Photos
import SwiftUI
import UserNotifications

enum ReminderFrequency: String, CaseIterable {
    case none = "None"
    case daily = "Daily"
    case monthly = "Monthly"
    case yearly = "Yearly"
}

struct PersonSettingsView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    @State private var localReminderFrequency: Person.ReminderFrequency
    @State private var editedName: String
    @State private var editedDateOfBirth: Date
    @State private var albums: [PHAssetCollection] = []
    @State private var showingBirthDaySheet = false
    @State private var birthMonthsDisplay: Person.BirthMonthsDisplay
    @State private var nextReminderDate: Date?
    @State private var showingDatePicker = false
    @State private var showOnboarding = false

    // Alert handling
    @State private var showingAlert = false
    @State private var activeAlert: AlertType = .deletePhotos

    // Define the AlertType enum
    enum AlertType {
        case deletePhotos, deletePerson
    }

    init(viewModel: PersonViewModel, person: Binding<Person>) {
        self.viewModel = viewModel
        self._person = person
        self._localReminderFrequency = State(initialValue: person.wrappedValue.reminderFrequency)
        self._editedName = State(initialValue: person.wrappedValue.name)
        self._editedDateOfBirth = State(initialValue: person.wrappedValue.dateOfBirth)
        self._birthMonthsDisplay = State(initialValue: person.wrappedValue.birthMonthsDisplay)
    }

    var body: some View {
        Form {
            Section(header: Text("Personal Information")) {
                HStack {
                    Text("Name")
                    Spacer()
                    TextField("", text: $editedName)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.secondary)
                        .onChange(of: editedName) { _, newValue in
                            updatePerson { $0.name = newValue }
                        }
                }
                Button(action: {
                    showingDatePicker = true
                }) {
                    HStack {
                        Text("Date of Birth")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(formatDate(editedDateOfBirth))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text("Milestones")) {
                Picker("Group by Month", selection: $birthMonthsDisplay) {
                    Text("None").tag(Person.BirthMonthsDisplay.none)
                    Text("First 12 months").tag(Person.BirthMonthsDisplay.twelveMonths)
                    Text("First 24 months").tag(Person.BirthMonthsDisplay.twentyFourMonths)
                }
                .onChange(of: birthMonthsDisplay) { _, newValue in
                    updatePerson { $0.birthMonthsDisplay = newValue }
                }

                Picker("Track Pregnancy", selection: $person.pregnancyTracking) {
                    Text("None").tag(Person.PregnancyTracking.none)
                    Text("Trimesters").tag(Person.PregnancyTracking.trimesters)
                    Text("Weeks").tag(Person.PregnancyTracking.weeks)
                }
                .onChange(of: person.pregnancyTracking) { _, newValue in
                    updatePerson { $0.pregnancyTracking = newValue }
                }

                Toggle("Show Empty Milestones", isOn: $person.showEmptyStacks)
                    .onChange(of: person.showEmptyStacks) { _, newValue in
                        updatePerson { $0.showEmptyStacks = newValue }
                    }
            }

            Section {
                Picker("Upload Reminder", selection: $localReminderFrequency) {
                    ForEach(Person.ReminderFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.rawValue).tag(frequency)
                    }
                }
                .onChange(of: localReminderFrequency) { _, newValue in
                    if newValue != .none {
                        viewModel.requestNotificationPermissions { granted in
                            if granted {
                                updatePerson { $0.reminderFrequency = newValue }
                                scheduleReminder()
                                DispatchQueue.main.async {
                                    viewModel.objectWillChange.send()
                                }
                            } else {
                                // Handle the case where permission is not granted
                                // For example, show an alert to the user
                                localReminderFrequency = .none
                            }
                        }
                    } else {
                        updatePerson { $0.reminderFrequency = newValue }
                        scheduleReminder()
                        DispatchQueue.main.async {
                            viewModel.objectWillChange.send()
                        }
                    }
                }
            } header: {
                Text("Reminders")
            } footer: {
                if localReminderFrequency != .none, let nextReminder = nextReminderDate {
                    Text("Next reminder: \(formatDateTime(nextReminder))")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Internal")) {
                Button("Replay Onboarding") {
                    showOnboarding = true
                }
            }

            Section(header: Text("Danger Zone")) {
                Button("Delete All Photos") {
                    activeAlert = .deletePhotos
                    showingAlert = true
                }
                .foregroundColor(.red)

                Button("Delete Person") {
                    activeAlert = .deletePerson
                    showingAlert = true
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("\(person.name)'s Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showingAlert) {
            switch activeAlert {
            case .deletePhotos:
                Alert(
                    title: Text("Delete All Photos"),
                    message: Text(
                        "Are you sure you want to delete all photos for this person? This action cannot be undone."
                    ),
                    primaryButton: .destructive(Text("Delete"), action: deleteAllPhotos),
                    secondaryButton: .cancel()
                )
            case .deletePerson:
                Alert(
                    title: Text("Delete Reel"),
                    message: Text(
                        "Are you sure you want to delete this reel? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete"), action: deletePerson),
                    secondaryButton: .cancel()
                )
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(
                date: $editedDateOfBirth,
                isPresented: $showingDatePicker,
                onSave: { newDate in
                    updatePerson { $0.dateOfBirth = newDate }
                }
            )
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(showOnboarding: $showOnboarding, viewModel: viewModel)
        }
        .onAppear {
            scheduleReminder()
        }
    }

    private func updatePerson(_ update: (inout Person) -> Void) {
        var updatedPerson = person
        update(&updatedPerson)
        person = updatedPerson
        viewModel.updatePerson(updatedPerson)
        viewModel.savePeople()
        DispatchQueue.main.async {
            self.viewModel.objectWillChange.send()
        }
    }

    private func deleteAllPhotos() {
        viewModel.deleteAllPhotos(for: person) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.person.photos.removeAll()
                    self.viewModel.updatePerson(self.person)
                case .failure(let error):
                    print("Failed to delete photos: \(error.localizedDescription)")
                }
            }
        }
    }

    private func deletePerson() {
        viewModel.deletePerson(person)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func scheduleReminder() {
        // First, remove any existing reminders for this person
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            person.id.uuidString
        ])

        guard person.reminderFrequency != .none else {
            nextReminderDate = nil
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Photo Upload Reminder"
        content.body = "Don't forget to upload new photos of \(person.name)!"
        content.sound = .default

        let calendar = Calendar.current
        let now = Date()
        var dateComponents = calendar.dateComponents(
            [.year, .month, .day], from: person.dateOfBirth)
        dateComponents.hour = 10  // Set reminder time to 10 AM
        dateComponents.minute = 0

        switch person.reminderFrequency {
        case .daily:
            dateComponents = calendar.dateComponents([.hour, .minute], from: now)
            dateComponents.hour = 10
            dateComponents.minute = 0
            nextReminderDate = calendar.nextDate(
                after: now, matching: dateComponents, matchingPolicy: .nextTime)
        case .monthly:
            let currentYear = calendar.component(.year, from: now)
            let currentMonth = calendar.component(.month, from: now)
            let birthDay = dateComponents.day!

            dateComponents.year = currentYear
            dateComponents.month = currentMonth
            dateComponents.day = birthDay

            if let nextDate = calendar.nextDate(
                after: now, matching: dateComponents, matchingPolicy: .nextTime)
            {
                nextReminderDate = nextDate
            } else {
                // If we couldn't find a valid date this month, move to the next month
                dateComponents.month = (currentMonth % 12) + 1
                if dateComponents.month == 1 {
                    dateComponents.year = currentYear + 1
                }
                nextReminderDate = calendar.date(from: dateComponents)
            }
        case .yearly:
            dateComponents.year = calendar.component(.year, from: now)
            if let nextDate = calendar.date(from: dateComponents),
                nextDate > now
            {
                nextReminderDate = nextDate
            } else {
                dateComponents.year! += 1
                nextReminderDate = calendar.date(from: dateComponents)
            }
        case .none:
            nextReminderDate = nil
            return
        }

        if let nextReminderDate = nextReminderDate {
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: nextReminderDate), repeats: true)
            let request = UNNotificationRequest(
                identifier: person.id.uuidString, content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling reminder: \(error.localizedDescription)")
                }
            }
        }

        DispatchQueue.main.async {
            self.viewModel.objectWillChange.send()
        }
    }
}
