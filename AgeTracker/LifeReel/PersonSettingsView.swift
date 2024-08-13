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
    @State private var onBulkImportComplete: ((String?) -> Void)?
    @State private var showingBirthDaySheet = false
    @State private var showingBulkImport = false
    @State private var localSortOrder: Person.SortOrder
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
        self._localSortOrder = State(initialValue: viewModel.sortOrder)
        self._birthMonthsDisplay = State(initialValue: person.wrappedValue.birthMonthsDisplay)
    }

    var body: some View {
        Form {
            Section(header: Text("Personal Information")) {
                TextField("Name", text: $editedName)
                DatePicker("Date of Birth", selection: $editedDateOfBirth, displayedComponents: .date)
            }

            Section(header: Text("Display Options")) {
                Picker("Sort Order", selection: $localSortOrder) {
                    Text("Latest to Oldest").tag(Person.SortOrder.latestToOldest)
                    Text("Oldest to Latest").tag(Person.SortOrder.oldestToLatest)
                }
                
                Picker("Birth Months", selection: $birthMonthsDisplay) {
                    ForEach(Person.BirthMonthsDisplay.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            }

            Section(header: Text("Sync Options")) {
                Picker("Sync Album", selection: $selectedAlbum) {
                    Text("No album synced").tag(nil as PHAssetCollection?)
                    ForEach(albums, id: \.localIdentifier) { album in
                        Text(album.localizedTitle ?? "Untitled Album").tag(album as PHAssetCollection?)
                    }
                }
                
                Button("Bulk Import") {
                    showingBulkImport = true
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
        }
    }

    private func updatePerson(_ update: (inout Person) -> Void) {
        var updatedPerson = person
        update(&updatedPerson)
        person = updatedPerson
        viewModel.updatePerson(updatedPerson)
    }

    private func saveChanges() {
        var updatedPerson = Person(id: person.id,
                                   name: editedName,
                                   dateOfBirth: editedDateOfBirth,
                                   photos: person.photos,
                                   syncedAlbumIdentifier: selectedAlbum?.localIdentifier,
                                   birthMonthsDisplay: birthMonthsDisplay)
        
        viewModel.updatePersonProperties(updatedPerson)
        viewModel.setSortOrder(localSortOrder)
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
                    // Optionally, show an alert to the user about the failure
                }
            }
        }
    }

    private func deletePerson() {
        viewModel.deletePerson(person)
        presentationMode.wrappedValue.dismiss()
    }
}