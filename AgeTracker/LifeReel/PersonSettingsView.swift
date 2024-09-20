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

    @Environment(\.presentationMode) var presentationMode
    @GestureState private var dragOffset = CGSize.zero

    init(viewModel: PersonViewModel, person: Binding<Person>) {
        self.viewModel = viewModel
        self._person = person
        self._localReminderFrequency = State(initialValue: person.wrappedValue.reminderFrequency)
        self._editedName = State(initialValue: person.wrappedValue.name)
        self._editedDateOfBirth = State(initialValue: person.wrappedValue.dateOfBirth)
        self._birthMonthsDisplay = State(initialValue: person.wrappedValue.birthMonthsDisplay)
    }

    var body: some View {
        NavigationStack {
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

                    Toggle(
                        "Track Pregnancy",
                        isOn: Binding(
                            get: { person.pregnancyTracking != .none },
                            set: { newValue in
                                updatePerson {
                                    $0.pregnancyTracking = newValue ? .trimesters : .none
                                }
                            }
                        ))

                    if person.pregnancyTracking != .none {
                        Picker("Pregnancy Tracking", selection: $person.pregnancyTracking) {
                            Text("Trimesters").tag(Person.PregnancyTracking.trimesters)
                            Text("Weeks").tag(Person.PregnancyTracking.weeks)
                        }
                        .onChange(of: person.pregnancyTracking) { _, newValue in
                            updatePerson { $0.pregnancyTracking = newValue }
                        }
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
                                        self.viewModel.objectWillChange.send()
                                        // Force update of nextReminderDate in the UI
                                        self.nextReminderDate = self.nextReminderDate
                                    }
                                } else {
                                    // Handle the case where permission is not granted
                                    DispatchQueue.main.async {
                                        self.localReminderFrequency = .none
                                    }
                                }
                            }
                        } else {
                            updatePerson { $0.reminderFrequency = newValue }
                            scheduleReminder()  // This will cancel all reminders when set to .none
                            DispatchQueue.main.async {
                                self.viewModel.objectWillChange.send()
                                // Force update of nextReminderDate in the UI
                                self.nextReminderDate = self.nextReminderDate
                            }
                        }
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Group {
                        if localReminderFrequency != .none {
                            if let nextReminder = nextReminderDate {
                                Text("Next reminder: \(formatDateTime(nextReminder))")
                            } else {
                                Text("Next reminder: Not set")
                            }
                        }
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
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
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    CircularButton(
                        systemName: "chevron.left",
                        action: {
                            presentationMode.wrappedValue.dismiss()
                        },
                        size: 32,
                        backgroundColor: Color.gray.opacity(0.2),
                        iconColor: .primary,
                        blurEffect: false
                    )
                }
            }
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
                            "Are you sure you want to delete this reel? This action cannot be undone."
                        ),
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
        .gesture(
            DragGesture().updating($dragOffset) { value, state, _ in
                if value.startLocation.x < 20 && value.translation.width > 100 {
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        )
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
        // Cancel all existing reminders for this person
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [person.id.uuidString])

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
        print("Current date: \(now)")
        print("Person's date of birth: \(person.dateOfBirth)")
        print("Reminder frequency: \(person.reminderFrequency)")

        switch person.reminderFrequency {
        case .daily:
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = 9
            components.minute = 0
            components.second = 0
            
            if let date = calendar.date(from: components), date <= now {
                components.day! += 1
            }
            
            nextReminderDate = calendar.date(from: components)
            
        case .monthly:
            let birthDay = calendar.component(.day, from: person.dateOfBirth)
            var components = DateComponents()
            components.day = birthDay
            components.hour = 9
            components.minute = 0
            
            nextReminderDate = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime)
            
        case .yearly:
            var components = calendar.dateComponents([.month, .day], from: person.dateOfBirth)
            components.year = calendar.component(.year, from: now)
            components.hour = 9
            components.minute = 0
            
            var nextDate = calendar.date(from: components)!
            if nextDate <= now {
                components.year! += 1
                nextDate = calendar.date(from: components)!
            }
            nextReminderDate = nextDate
            
        case .none:
            nextReminderDate = nil
            return
        }

        print("Calculated next reminder date: \(nextReminderDate ?? Date())")

        if let nextReminderDate = nextReminderDate {
            let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextReminderDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
            let request = UNNotificationRequest(identifier: person.id.uuidString, content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling reminder: \(error.localizedDescription)")
                } else {
                    print("Reminder scheduled successfully for \(nextReminderDate)")
                }
            }
        }

        DispatchQueue.main.async {
            self.viewModel.objectWillChange.send()
        }
    }
}
