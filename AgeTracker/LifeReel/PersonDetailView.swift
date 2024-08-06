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

enum ActiveSheet: Identifiable {
    case settings
    case bulkImport
    case shareView
    
    var id: Int {
        hashValue
    }
}

// Main view struct
struct PersonDetailView: View {
    // State and observed properties
    @State private var person: Person
    @ObservedObject var viewModel: PersonViewModel
    @State private var showingImagePicker = false
    @State private var selectedAssets: [PHAsset] = []
    @State private var imageMeta: [String: Any]?
    @State private var showingDeleteAlert = false
    @State private var photoToDelete: Photo?
    @State private var currentPhotoIndex: Int = 0
    @State private var latestPhotoIndex = 0 // New state variable
    @State private var lastFeedbackDate: Date?
    let impact = UIImpactFeedbackGenerator(style: .light)
    @State private var selectedView = 0 // 0 for All, 1 for Years
    @State private var activeSheet: ActiveSheet?
    @State private var selectedPhoto: Photo? = nil // New state variable
    @State private var isShareSheetPresented = false
    @State private var activityItems: [Any] = []

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
                    Text("Timeline").tag(0)
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
                    Button(action: {
                        activeSheet = .settings
                    }) {
                        HStack(spacing: 4) {
                            Text(person.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 16, height: 16)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { 
                        showingImagePicker = true 
                    }) {
                        Image(systemName: "plus")
                            // .fontWeight(.bold)
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: CustomBackButton())
            // Sheet presentation for image picker
            .sheet(isPresented: $showingImagePicker, onDismiss: {
                loadImage()
            }) {
                ImagePicker(selectedAssets: $selectedAssets, isPresented: $showingImagePicker)
            }
            // Sheet presentation for bulk import
            .sheet(item: $activeSheet) { item in
                switch item {
                case .settings:
                    NavigationView {
                        PersonSettingsView(viewModel: viewModel, person: $person)
                    }
                case .bulkImport:
                    BulkImportView(viewModel: viewModel, person: $person, onImportComplete: {
                        if let updatedPerson = viewModel.people.first(where: { $0.id == person.id }) {
                            person = updatedPerson
                        }
                    })
                case .shareView:
                    NavigationView {
                        if !person.photos.isEmpty {
                            let sortedPhotos = person.photos.sorted(by: { $0.dateTaken < $1.dateTaken })
                            let safeIndex = min(max(0, currentPhotoIndex), sortedPhotos.count - 1)
                            SharePhotoView(
                                image: sortedPhotos[safeIndex].image ?? UIImage(),
                                name: person.name,
                                age: calculateAge(),
                                isShareSheetPresented: $isShareSheetPresented,
                                activityItems: $activityItems
                            )
                        } else {
                            Text("No photos available to share")
                        }
                    }
                }
            }
            .sheet(isPresented: $isShareSheetPresented) {
                ActivityViewController(activityItems: activityItems)
            }
            // Image selection handler
            .onChange(of: selectedAssets) { oldValue, newValue in
                if !newValue.isEmpty {
                    print("Assets selected: \(newValue)")
                    loadImage()
                } else {
                    print("No assets selected")
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
                print("PersonDetailView appeared with age format: \(person.ageFormat)") // Debug print
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
    
    // Timeline view
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
                                if let image = sortedPhotos[index].image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: geometry.size.height * 0.6)
                                        .frame(width: geometry.size.width)
                                        .offset(x: CGFloat(offset) * geometry.size.width)
                                } else {
                                    Color.gray
                                        .frame(width: geometry.size.width, height: geometry.size.height * 0.6)
                                        .offset(x: CGFloat(offset) * geometry.size.width)
                                }
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
                    .onChange(of: currentPhotoIndex) { oldValue, newValue in
                        withAnimation {
                            // This will trigger a UI update
                        }
                    }
                    
                    VStack {
                        Text(calculateAge())
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
                        .onChange(of: currentPhotoIndex) { oldValue, newValue in
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
                        .frame(width: 110, height: 110)
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
    
    // Image loading function
    func loadImage() {
        guard !selectedAssets.isEmpty else { 
            print("No assets to load")
            return 
        }
        
        for asset in selectedAssets {
            let newPhoto = Photo(asset: asset)
            self.viewModel.addPhoto(to: &self.person, asset: asset)
            print("Added photo with date: \(newPhoto.dateTaken) and identifier: \(newPhoto.assetIdentifier)")
        }
    }

    // Function to extract date taken from metadata
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
    private func calculateAge() -> String {
        let sortedPhotos = person.photos.sorted(by: { $0.dateTaken < $1.dateTaken })
        let safeIndex = min(max(0, currentPhotoIndex), sortedPhotos.count - 1)
        let photoDate = sortedPhotos[safeIndex].dateTaken
        return AgeCalculator.calculateAgeString(for: person, at: photoDate)
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
