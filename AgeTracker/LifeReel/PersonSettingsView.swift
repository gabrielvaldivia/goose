//
//  PersonSettingsView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/2/24.
//

import Foundation
import SwiftUI
import Photos

struct PersonSettingsView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    @State private var editedName: String
    @State private var editedDateOfBirth: Date
    @State private var albums: [PHAssetCollection] = []
    @State private var selectedAlbum: PHAssetCollection?
    @Environment(\.presentationMode) var presentationMode
    @State private var showingBirthDaySheet = false
    @State private var birthMonthsDisplay: Person.BirthMonthsDisplay
    

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
                }
                Button(action: {
                    showingBirthDaySheet = true
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

            Section(header: Text("Display Options")) {
                Picker("Group by Month", selection: $birthMonthsDisplay) {
                    Text("None").tag(Person.BirthMonthsDisplay.none)
                    Text("First 12 months").tag(Person.BirthMonthsDisplay.twelveMonths)
                    Text("First 24 months").tag(Person.BirthMonthsDisplay.twentyFourMonths)
                }
                .onChange(of: birthMonthsDisplay) {
                    updatePerson { $0.birthMonthsDisplay = birthMonthsDisplay }
                }
                
                Picker("Track Pregnancy", selection: $person.pregnancyTracking) {
                    Text("None").tag(Person.PregnancyTracking.none)
                    Text("Trimesters").tag(Person.PregnancyTracking.trimesters)
                    Text("Weeks").tag(Person.PregnancyTracking.weeks)
                }
                .onChange(of: person.pregnancyTracking) {
                    updatePerson { $0.pregnancyTracking = person.pregnancyTracking }
                }
                
                Toggle("Show Empty Stacks", isOn: $person.showEmptyStacks)
                    .onChange(of: person.showEmptyStacks) {
                        updatePerson { $0.showEmptyStacks = person.showEmptyStacks }
                    }
            }

            Section {
                HStack {
                    Text("Sync Album")
                    Spacer()
                    Menu {
                        Button("No album synced") {
                            selectedAlbum = nil
                        }
                        ForEach(albums, id: \.localIdentifier) { album in
                            Button(album.localizedTitle ?? "Untitled Album") {
                                selectedAlbum = album
                            }
                        }
                    } label: {
                        HStack(spacing: 4) { 
                            Text(selectedAlbum?.localizedTitle ?? "No album synced")
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text("Danger Zone")) {
                Button(action: {
                    activeAlert = .deletePhotos
                    showingAlert = true
                }) {
                    Text("Delete All Photos")
                        .foregroundColor(.red)
                }
                
                Button(action: {
                    activeAlert = .deletePerson
                    showingAlert = true
                }) {
                    Text("Delete Person")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("\(person.name)'s Settings")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(
            leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            },
            trailing: Button("Save") {
                saveChanges()
            }
        )
        .alert(isPresented: $showingAlert) {
            switch activeAlert {
            case .deletePhotos:
                return Alert(
                    title: Text("Delete All Photos"),
                    message: Text("Are you sure you want to delete all photos for this person? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        deleteAllPhotos()
                    },
                    secondaryButton: .cancel()
                )
            case .deletePerson:
                return Alert(
                    title: Text("Delete Reel"),
                    message: Text("Are you sure you want to delete this reel? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        deletePerson()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .sheet(isPresented: $showingBirthDaySheet) {
            BirthDaySheet(dateOfBirth: $editedDateOfBirth, isPresented: $showingBirthDaySheet)
                .presentationDetents([.height(300)]) 
        }
        .onAppear {
            fetchAlbums()
            fetchSelectedAlbum()
        }
    }

    private func updatePerson(_ update: (inout Person) -> Void) {
        var updatedPerson = person
        update(&updatedPerson)
        person = updatedPerson
        viewModel.updatePerson(updatedPerson)
        viewModel.savePeople()
    }

    private func saveChanges() {
        updatePerson { person in
            person.name = editedName
            person.dateOfBirth = editedDateOfBirth
            person.syncedAlbumIdentifier = selectedAlbum?.localIdentifier
            person.birthMonthsDisplay = birthMonthsDisplay
            person.showEmptyStacks = person.showEmptyStacks
            // Keep the user's choice for pregnancyTracking
            person.pregnancyTracking = person.pregnancyTracking
        }
        
        viewModel.savePeople()
        presentationMode.wrappedValue.dismiss()
    }

    private func fetchAlbums() {
        viewModel.fetchAlbums { result in
            switch result {
            case .success(let fetchedAlbums):
                self.albums = fetchedAlbums
            case .failure(let error):
                print("Failed to fetch albums: \(error.localizedDescription)")
            }
        }
    }

    private func fetchSelectedAlbum() {
        if let albumIdentifier = person.syncedAlbumIdentifier {
            viewModel.fetchAlbum(withIdentifier: albumIdentifier) { result in
                switch result {
                case .success(let album):
                    self.selectedAlbum = album
                case .failure(let error):
                    print("Failed to fetch selected album: \(error.localizedDescription)")
                }
            }
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
        presentationMode.wrappedValue.dismiss()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}