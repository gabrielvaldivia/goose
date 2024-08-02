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
    @State private var albums: [PHAssetCollection] = []
    @State private var selectedAlbum: PHAssetCollection?
    @Environment(\.presentationMode) var presentationMode

    init(viewModel: PersonViewModel, person: Binding<Person>) {
        self.viewModel = viewModel
        self._person = person
        self._editedName = State(initialValue: person.wrappedValue.name)
        self._editedDateOfBirth = State(initialValue: person.wrappedValue.dateOfBirth)
    }

    var body: some View {
        Form {
            Section(header: Text("Personal Information")) {
                TextField("Name", text: $editedName)
                DatePicker("Date of Birth", selection: $editedDateOfBirth, displayedComponents: .date)
            }

            Section {
                Picker("Sync Album", selection: $selectedAlbum) {
                    Text("No album synced").tag(nil as PHAssetCollection?)
                    ForEach(albums, id: \.localIdentifier) { album in
                        Text(album.localizedTitle ?? "Untitled Album").tag(album as PHAssetCollection?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }

            Section(header: Text("Danger Zone")) {
                Button(action: {
                    showingDeletePhotosAlert = true
                }) {
                    Text("Delete All Photos")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: Button("Save") {
            saveChanges()
        })
        .alert(isPresented: $showingDeletePhotosAlert) {
            Alert(
                title: Text("Delete All Photos"),
                message: Text("Are you sure you want to delete all photos for this person? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteAllPhotos()
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            fetchAlbums()
            fetchSelectedAlbum()
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
        viewModel.updatePerson(person)
        presentationMode.wrappedValue.dismiss()
    }

    private func deleteAllPhotos() {
        person.photos.removeAll()
        viewModel.updatePerson(person)
    }
}