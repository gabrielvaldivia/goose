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
    @State private var showingDeletePhotosAlert = false
    @State private var showingDeletePersonAlert = false
    @State private var albums: [PHAssetCollection] = []
    @State private var selectedAlbum: PHAssetCollection?
    @Environment(\.presentationMode) var presentationMode
    @State private var onBulkImportComplete: ((String?) -> Void)?
    @State private var showingBirthDaySheet = false
    @State private var showingBulkImport = false
    @State private var selectedAgeFormat: AgeFormat

    // Add this enum at the top of your struct
    enum AlertType {
        case deletePhotos, deletePerson
    }

    // Add these state variables
    @State private var showingAlert = false
    @State private var activeAlert: AlertType = .deletePhotos

    init(viewModel: PersonViewModel, person: Binding<Person>) {
        self.viewModel = viewModel
        self._person = person
        self._editedName = State(initialValue: person.wrappedValue.name)
        self._editedDateOfBirth = State(initialValue: person.wrappedValue.dateOfBirth)
        self._selectedAgeFormat = State(initialValue: person.wrappedValue.ageFormat)
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

            Section {
                Picker("Sync Album", selection: $selectedAlbum) {
                    Text("No album synced").tag(nil as PHAssetCollection?)
                    ForEach(albums, id: \.localIdentifier) { album in
                        Text(album.localizedTitle ?? "Untitled Album").tag(album as PHAssetCollection?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Button(action: {
                    showingBulkImport = true
                }) {
                    Text("Bulk Import")
                }
            }

            Section(header: Text("Age Display")) {
                Picker("Age Format", selection: $selectedAgeFormat) {
                    ForEach(AgeFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(DefaultPickerStyle())
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
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: Button("Save") {
            saveChanges()
        })
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
                    title: Text("Delete Person"),
                    message: Text("Are you sure you want to delete this person? This action cannot be undone."),
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
        .sheet(isPresented: $showingBulkImport) {
            BulkImportView(viewModel: viewModel, person: $person, onImportComplete: {
                if let updatedPerson = viewModel.people.first(where: { $0.id == person.id }) {
                    person = updatedPerson
                }
            })
        }
        .onAppear {
            fetchAlbums()
            fetchSelectedAlbum()
            onBulkImportComplete = { albumIdentifier in
                self.person.syncedAlbumIdentifier = albumIdentifier
                self.fetchSelectedAlbum()
            }
        }
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

    private func saveChanges() {
        person.name = editedName
        person.dateOfBirth = editedDateOfBirth
        person.syncedAlbumIdentifier = selectedAlbum?.localIdentifier
        person.ageFormat = selectedAgeFormat
        viewModel.updatePerson(person)
        print("Saving age format: \(selectedAgeFormat)") // Debug print
        presentationMode.wrappedValue.dismiss()
    }

    private func deleteAllPhotos() {
        viewModel.deleteAllPhotos(for: person) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Update the local person object
                    self.person.photos.removeAll()
                    // Notify the view model of the change
                    self.viewModel.objectWillChange.send()
                case .failure(let error):
                    print("Failed to delete photos: \(error.localizedDescription)")
                    // Optionally, show an alert to the user about the failure
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