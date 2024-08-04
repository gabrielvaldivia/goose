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
import Photos
import UIKit

// Main view struct
struct PersonDetailView: View {
    // State and observed properties
    @State private var person: Person
    @ObservedObject var viewModel: PersonViewModel
    @State private var showingImagePicker = false
    @State private var selectedAssets: [PHAsset] = []
    @State private var showingDeleteAlert = false
    @State private var photoToDelete: Photo?
    @State private var currentPhotoIndex: Int = 0
    @State private var latestPhotoIndex = 0 // New state variable
    @State private var lastFeedbackDate: Date?
    let impact = UIImpactFeedbackGenerator(style: .light)
    @State private var selectedView = 0 // 0 for All, 1 for Years
    @State private var showingBulkImport = false // New state variable
    @State private var showingSettings = false // New state variable
    @State private var selectedPhoto: Photo? = nil // New state variable

    // Initializer
    init(person: Person, viewModel: PersonViewModel) {
        _person = State(initialValue: person)
        self.viewModel = viewModel
        let sortedPhotos = person.photos.sorted(by: { $0.dateTaken < $1.dateTaken })
        _latestPhotoIndex = State(initialValue: sortedPhotos.count - 1)
        _currentPhotoIndex = State(initialValue: sortedPhotos.count - 1)
    }
    
    // Main body of the view
    var body: some View {
        GeometryReader { geometry in
            VStack {
                // Segmented control for view selection
                Picker("View", selection: $selectedView) {
                    Text("All").tag(0)
                    Text("Years").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                // Conditional view based on selection
                if selectedView == 0 {
                    allPhotosView
                } else {
                    yearsView
                }
            }
            // Navigation and toolbar setup
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(person.name).font(.headline)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gear")
                        }
                        Menu {
                            Button(action: { 
                                showingImagePicker = true 
                            }) {
                                Label("Add Photo", systemImage: "camera")
                            }
                            Button(action: {
                                showingBulkImport = true
                            }) {
                                Label("Bulk Import", systemImage: "square.and.arrow.down")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: CustomBackButton())
            // Sheet presentation for image picker
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedAssets: $selectedAssets, isPresented: $showingImagePicker)
            }
            // Sheet presentation for bulk import
            .sheet(isPresented: $showingBulkImport) {
                BulkImportView(viewModel: viewModel, person: $person, onImportComplete: {
                    if let updatedPerson = viewModel.people.first(where: { $0.id == person.id }) {
                        person = updatedPerson
                    }
                })
            }
            // Sheet presentation for settings
            .sheet(isPresented: $showingSettings) {
                NavigationView {
                    PersonSettingsView(viewModel: viewModel, person: $person)
                }
            }
            // Image selection handler
            .onChange(of: selectedAssets) { newAssets in
                if !newAssets.isEmpty {
                    loadImages(from: newAssets)
                }
            }
            // View appearance handler
            .onAppear {
                if let updatedPerson = viewModel.people.first(where: { $0.id == person.id }) {
                    person = updatedPerson
                    let sortedPhotos = person.photos.sorted(by: { $0.dateTaken < $1.dateTaken })
                    latestPhotoIndex = sortedPhotos.count - 1
                    currentPhotoIndex = latestPhotoIndex
                }
            }
            // Delete photo alert
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
            .fullScreenCover(item: $selectedPhoto) { photo in
                FullScreenPhotoView(
                    photo: photo,
                    currentIndex: person.photos.sorted(by: { $0.dateTaken < $1.dateTaken }).firstIndex(of: photo) ?? 0,
                    photos: person.photos.sorted(by: { $0.dateTaken < $1.dateTaken }),
                    onDelete: deletePhoto,
                    person: person
                )
                .transition(.asymmetric(
                    insertion: AnyTransition.opacity.combined(with: .scale),
                    removal: .opacity
                ))
            }
        }
    }
    
    // All photos view
    private var allPhotosView: some View {
        GeometryReader { geometry in
            VStack {
                if !person.photos.isEmpty {
                    let sortedPhotos = person.photos.sorted(by: { $0.dateTaken < $1.dateTaken })
                    let safeIndex = min(max(0, currentPhotoIndex), sortedPhotos.count - 1)
                    
                    Spacer()
                    
                    ZStack {
                        ForEach(-1...1, id: \.self) { offset in
                            let index = safeIndex + offset
                            if index >= 0 && index < sortedPhotos.count {
                                AsyncImage(url: URL(fileURLWithPath: Photo.getDocumentsDirectory().appendingPathComponent(sortedPhotos[index].fileName).path)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: geometry.size.height * 0.6)
                                            .frame(width: geometry.size.width)
                                    case .failure(_):
                                        Color.gray
                                    case .empty:
                                        ProgressView()
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .offset(x: CGFloat(offset) * geometry.size.width)
                            }
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.6)
                    .clipped()
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let offset = gesture.translation.width / geometry.size.width
                                if (safeIndex > 0 || offset > 0) && (safeIndex < sortedPhotos.count - 1 || offset < 0) {
                                    withAnimation(.interactiveSpring()) {
                                        currentPhotoIndex = safeIndex - Int(offset)
                                    }
                                }
                            }
                            .onEnded { gesture in
                                let predictedOffset = gesture.predictedEndTranslation.width / geometry.size.width
                                withAnimation(.spring()) {
                                    if predictedOffset > 0.5 && safeIndex > 0 {
                                        currentPhotoIndex = safeIndex - 1
                                    } else if predictedOffset < -0.5 && safeIndex < sortedPhotos.count - 1 {
                                        currentPhotoIndex = safeIndex + 1
                                    } else {
                                        currentPhotoIndex = safeIndex
                                    }
                                }
                                latestPhotoIndex = currentPhotoIndex
                            }
                    )
                    .onTapGesture {
                        selectedPhoto = sortedPhotos[safeIndex]
                    }
                    
                    VStack {
                        Text(formatAge())
                            .font(.title3)
                        Text(formatDate(sortedPhotos[safeIndex].dateTaken))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    
                    Spacer()
                    
                    if sortedPhotos.count > 1 {
                        Slider(value: Binding(
                            get: { Double(safeIndex) },
                            set: { 
                                currentPhotoIndex = Int($0)
                                latestPhotoIndex = currentPhotoIndex
                            }
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
                    }
                } else {
                    Spacer ()
                    Text("No photos available")
                    Spacer ()
                }
            }
            .frame(width: geometry.size.width)
        }
        .onAppear {
            currentPhotoIndex = min(latestPhotoIndex, person.photos.count - 1)
        }
    }

    // Years view
    private var yearsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(groupPhotosByAge(), id: \.0) { section, photos in
                    YearSectionView(section: section, photos: photos, onDelete: deletePhoto, selectedPhoto: $selectedPhoto, person: person)
                }
            }
        }
    }

    private struct YearSectionView: View {
        let section: String
        let photos: [Photo]
        let onDelete: (Photo) -> Void
        @Binding var selectedPhoto: Photo?
        let person: Person
        
        var body: some View {
            VStack(alignment: .leading) {
                Text(section)
                    .font(.headline)
                    .padding(.leading)
                
                PhotoGridView(section: section, photos: photos, onDelete: onDelete, selectedPhoto: $selectedPhoto, person: person)
            }
            .padding(.bottom, 20)
        }
    }

    private struct PhotoGridView: View {
        let section: String
        let photos: [Photo]
        let onDelete: (Photo) -> Void
        @Binding var selectedPhoto: Photo?
        @Namespace private var namespace
        let person: Person
        
        var body: some View {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                ForEach(photos.prefix(5)) { photo in
                    photoThumbnail(photo)
                        .onTapGesture {
                            selectedPhoto = photo
                        }
                }
                if photos.count > 5 {
                    NavigationLink(destination: AllPhotosInSectionView(sectionTitle: section, photos: photos, onDelete: onDelete, person: person)) {
                        remainingPhotosCount(photos.count - 5)
                    }
                }
            }
            .padding(.horizontal)
        }
        
        private func photoThumbnail(_ photo: Photo) -> some View {
            Group {
                if let image = photo.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 110, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .matchedGeometryEffect(id: photo.id, in: namespace)
                        .padding(.bottom, 2)
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
            .frame(width: 110, height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // Function to group photos by age
    private func groupPhotosByAge() -> [(String, [Photo])] {
        let calendar = Calendar.current
        let sortedPhotos = person.photos.sorted(by: { $0.dateTaken > $1.dateTaken })
        var groupedPhotos: [(String, [Photo])] = []

        for photo in sortedPhotos {
            let components = calendar.dateComponents([.year, .month, .weekOfYear], from: person.dateOfBirth, to: photo.dateTaken)
            let years = components.year ?? 0
            let months = components.month ?? 0

            let sectionTitle: String
            if photo.dateTaken >= person.dateOfBirth {
                if years == 0 {
                    switch months {
                    case 0:
                        sectionTitle = "Birth Month"
                    case 1...11:
                        sectionTitle = "\(months) Month\(months == 1 ? "" : "s")"
                    default:
                        sectionTitle = "1 Year"
                    }
                } else {
                    sectionTitle = "\(years) Year\(years == 1 ? "" : "s")"
                }
            } else {
                let weeksBeforeBirth = calendar.dateComponents([.weekOfYear], from: photo.dateTaken, to: person.dateOfBirth).weekOfYear ?? 0
                let pregnancyWeek = max(40 - weeksBeforeBirth, 0)
                if pregnancyWeek == 40 {
                    sectionTitle = "Birth Month"
                } else {
                    sectionTitle = "\(pregnancyWeek) Week\(pregnancyWeek == 1 ? "" : "s") Pregnant"
                }
            }

            if let index = groupedPhotos.firstIndex(where: { $0.0 == sectionTitle }) {
                groupedPhotos[index].1.append(photo)
            } else {
                groupedPhotos.append((sectionTitle, [photo]))
            }
        }

        // Create the order array
        let yearOrder = (1...100).reversed().map { "\($0) Year\($0 == 1 ? "" : "s")" }
        let monthOrder = (1...11).reversed().map { "\($0) Month\($0 == 1 ? "" : "s")" }
        let pregnancyOrder = (1...39).reversed().map { "\($0) Week\($0 == 1 ? "" : "s") Pregnant" }
        
        let order = yearOrder + monthOrder + ["Birth Month"] + pregnancyOrder

        // Sort the grouped photos
        return groupedPhotos.sorted { (group1, group2) -> Bool in
            let index1 = order.firstIndex(of: group1.0) ?? Int.max
            let index2 = order.firstIndex(of: group2.0) ?? Int.max
            return index1 < index2
        }
    }
    
    // Function to delete a photo
    func deletePhoto(_ photo: Photo) {
        if let index = person.photos.firstIndex(where: { $0.id == photo.id }) {
            person.photos.remove(at: index)
            viewModel.updatePerson(person)
        }
    }
    
    // Helper function to format date
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Helper function to format age
    private func formatAge() -> String {
        let calendar = Calendar.current
        let birthDate = person.dateOfBirth
        
        let sortedPhotos = person.photos.sorted(by: { $0.dateTaken < $1.dateTaken })
        guard currentPhotoIndex < sortedPhotos.count else {
            return "No photo selected"
        }
        
        let currentPhoto = sortedPhotos[currentPhotoIndex]
        
        if currentPhoto.dateTaken >= birthDate {
            let components = calendar.dateComponents([.year, .month, .day], from: birthDate, to: currentPhoto.dateTaken)
            let years = components.year ?? 0
            let months = components.month ?? 0
            let days = components.day ?? 0
            
            if years == 0 && months == 0 && days == 0 {
                return "Newborn"
            }
            
            var ageComponents: [String] = []
            if years > 0 { ageComponents.append("\(years) year\(years == 1 ? "" : "s")") }
            if months > 0 { ageComponents.append("\(months) month\(months == 1 ? "" : "s")") }
            if days > 0 || ageComponents.isEmpty { ageComponents.append("\(days) day\(days == 1 ? "" : "s")") }
            
            return ageComponents.joined(separator: ", ")
        } else {
            let weeksBeforeBirth = calendar.dateComponents([.weekOfYear], from: currentPhoto.dateTaken, to: birthDate).weekOfYear ?? 0
            let pregnancyWeek = max(40 - weeksBeforeBirth, 0)
            
            if pregnancyWeek == 40 {
                return "Newborn"
            } else if pregnancyWeek > 0 {
                return "\(pregnancyWeek) week\(pregnancyWeek == 1 ? "" : "s") pregnant"
            } else {
                return "Before pregnancy"
            }
        }
    }

    // Add this function to handle loading multiple images
    private func loadImages(from assets: [PHAsset]) {
        let group = DispatchGroup()
        for asset in assets {
            group.enter()
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            
            PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, info in
                if let image = image {
                    let dateTaken = asset.creationDate ?? Date()
                    self.viewModel.addPhoto(to: &self.person, image: image, dateTaken: dateTaken)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if let updatedPerson = self.viewModel.people.first(where: { $0.id == self.person.id }) {
                self.person = updatedPerson
            }
            self.selectedAssets.removeAll()
        }
    }
}

struct CustomBackButton: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "chevron.left")
                .foregroundColor(.blue)
        }
    }
}