//
//  PersonDetailView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/1/24.
//

import Foundation
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct PersonDetailView: View {
    @State private var person: Person
    @ObservedObject var viewModel: PersonViewModel
    @State private var showingImagePicker = false
    @State private var inputImage: UIImage?
    @State private var imageMeta: [String: Any]?
    @State private var showingDeleteAlert = false
    @State private var photoToDelete: Photo?

    init(person: Person, viewModel: PersonViewModel) {
        _person = State(initialValue: person)
        self.viewModel = viewModel
    }
    
    var body: some View {
        ScrollView {
            VStack {
                ForEach(person.photos.sorted(by: { $0.dateTaken > $1.dateTaken })) { photo in
                    if let image = photo.image {
                        VStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .onTapGesture {
                                    photoToDelete = photo
                                    showingDeleteAlert = true
                                }
                            Text("\(viewModel.calculateAge(for: person, at: photo.dateTaken).years) years, \(viewModel.calculateAge(for: person, at: photo.dateTaken).months) months, \(viewModel.calculateAge(for: person, at: photo.dateTaken).days) days")
                            Text("Photo taken on: \(formatDate(photo.dateTaken))")
                        }
                        .padding()
                    } else {
                        Text("Failed to load image")
                    }
                }
            }
        }
        .navigationTitle(person.name)
        .toolbar {
            Button(action: { 
                showingImagePicker = true 
            }) {
                Image(systemName: "camera")
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $inputImage, imageMeta: $imageMeta, isPresented: $showingImagePicker)
        }
        .onChange(of: inputImage) { newImage in
            if let newImage = newImage {
                print("Image selected: \(newImage)")
                loadImage()
            } else {
                print("No image selected")
            }
        }
        .onAppear {
            // Ensure we have the latest data
            if let updatedPerson = viewModel.people.first(where: { $0.id == person.id }) {
                person = updatedPerson
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Photo"),
                message: Text("Are you sure you want to delete this photo?"),
                primaryButton: .destructive(Text("Delete")) {
                    if let photoToDelete = photoToDelete {
                        deletePhoto(photoToDelete)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    func loadImage() {
        guard let inputImage = inputImage else { 
            print("No image to load")
            return 
        }
        print("Full metadata: \(String(describing: imageMeta))")
        let dateTaken = extractDateTaken(from: imageMeta) ?? Date()
        print("Extracted date taken: \(dateTaken)")
        print("Adding photo with date: \(dateTaken)")
        viewModel.addPhoto(to: person, image: inputImage, dateTaken: dateTaken)
        // Update the local person state
        if let updatedPerson = viewModel.people.first(where: { $0.id == person.id }) {
            person = updatedPerson
        }
    }

    func extractDateTaken(from metadata: [String: Any]?) -> Date? {
        print("Full metadata: \(String(describing: metadata))")
        if let dateTimeOriginal = metadata?["DateTimeOriginal"] as? String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            if let date = dateFormatter.date(from: dateTimeOriginal) {
                print("Extracted date: \(date)")
                return date
            }
        }
        print("Failed to extract date, using current date")
        return Date()
    }

    func deletePhoto(_ photo: Photo) {
        if let index = person.photos.firstIndex(where: { $0.id == photo.id }) {
            person.photos.remove(at: index)
            viewModel.updatePerson(person)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}