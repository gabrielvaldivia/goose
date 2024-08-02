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
    @State private var currentPhotoIndex = 0
    @State private var lastFeedbackDate: Date?
    let impact = UIImpactFeedbackGenerator(style: .light)
    @State private var selectedView = 0 // 0 for All, 1 for Years

    init(person: Person, viewModel: PersonViewModel) {
        _person = State(initialValue: person)
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack {
            Picker("View", selection: $selectedView) {
                Text("All").tag(0)
                Text("Years").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            if selectedView == 0 {
                allPhotosView
            } else {
                yearsView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(person.name).font(.headline)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { 
                    showingImagePicker = true 
                }) {
                    Image(systemName: "camera")
                }
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
    
    private var allPhotosView: some View {
        GeometryReader { geometry in
            VStack {
                if !person.photos.isEmpty {
                    let sortedPhotos = person.photos.sorted(by: { $0.dateTaken > $1.dateTaken })
                    if let image = sortedPhotos[currentPhotoIndex].image {
                        Spacer()
                        
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: geometry.size.height * 0.6)
                            .onTapGesture {
                                photoToDelete = sortedPhotos[currentPhotoIndex]
                                showingDeleteAlert = true
                            }
                        
                        VStack {
                            let age = viewModel.calculateAge(for: person, at: sortedPhotos[currentPhotoIndex].dateTaken)
                            Text(formatAge(years: age.years, months: age.months, days: age.days))
                                .font(.title3)
                            Text(formatDate(sortedPhotos[currentPhotoIndex].dateTaken))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        
                        Spacer()
                        
                        Slider(value: Binding(
                            get: { Double(sortedPhotos.count - 1 - currentPhotoIndex) },
                            set: { currentPhotoIndex = sortedPhotos.count - 1 - Int($0) }
                        ), in: 0...Double(sortedPhotos.count - 1), step: 1)
                        .padding()
                        .onChange(of: currentPhotoIndex) { newValue in
                            if let lastFeedbackDate = lastFeedbackDate, Date().timeIntervalSince(lastFeedbackDate) < 0.5 {
                                return
                            }
                            lastFeedbackDate = Date()
                            impact.prepare()
                            impact.impactOccurred()
                        }
                    } else {
                        Text("Failed to load image")
                    }
                } else {
                    Text("No photos available")
                }
            }
        }
    }

    private var yearsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(groupPhotosByAge(), id: \.0) { section, photos in
                    VStack(alignment: .leading) {
                        Text(section)
                            .font(.headline)
                            .padding(.leading)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                            ForEach(Array(photos.prefix(6).enumerated()), id: \.element.id) { index, photo in
                                if index < 5 || photos.count == 6 {
                                    photoThumbnail(photo)
                                } else {
                                    remainingPhotosCount(photos.count - 5)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    private func photoThumbnail(_ photo: Photo) -> some View {
        Group {
            if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Color.gray
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func remainingPhotosCount(_ count: Int) -> some View {
        ZStack {
            Color.gray.opacity(0.3)
            Text("+\(count)")
                .font(.title2)
                .foregroundColor(.white)
        }
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func groupPhotosByAge() -> [(String, [Photo])] {
        let calendar = Calendar.current
        let sortedPhotos = person.photos.sorted(by: { $0.dateTaken > $1.dateTaken })
        let grouped = Dictionary(grouping: sortedPhotos) { photo in
            let age = calendar.dateComponents([.year], from: person.dateOfBirth, to: photo.dateTaken).year ?? 0
            return age
        }
        
        return grouped.map { age, photos in
            let sectionTitle: String
            if age == 0 {
                sectionTitle = "Birth Year"
            } else {
                sectionTitle = "\(age) Year\(age == 1 ? "" : "s") Old"
            }
            return (sectionTitle, photos)
        }.sorted { $1.0 > $0.0 }
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
    
    private func formatAge(years: Int, months: Int, days: Int) -> String {
        var components: [String] = []
        
        if years > 0 {
            components.append("\(years) year\(years == 1 ? "" : "s")")
        }
        if months > 0 {
            components.append("\(months) month\(months == 1 ? "" : "s")")
        }
        components.append("\(days) day\(days == 1 ? "" : "s")")
        
        return components.joined(separator: ", ")
    }
}