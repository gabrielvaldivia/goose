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
    @State private var selectedView = 0 // 0 for Slideshow, 1 for Grid, 2 for Stacks
    @State private var activeSheet: ActiveSheet?
    @State private var selectedPhoto: Photo? = nil // New state variable
    @State private var isShareSheetPresented = false
    @State private var activityItems: [Any] = []
    @State private var isPlaying = false
    @State private var playTimer: Timer?
    @State private var playbackSpeed: Double = 1.0 // New state variable for playback speed
    @State private var showingDatePicker = false
    @State private var selectedPhotoForDateEdit: Photo?
    @State private var editedDate: Date = Date()
    @State private var isManualInteraction = true
    @State private var scrubberPosition: Double = 0
    @State private var lastUpdateTime: Date = Date()

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
                    Text("Slideshow").tag(0)
                    Text("Grid").tag(1)
                    Text("Stacks").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                // Conditional view based on selection
                if selectedView == 0 {
                    SlideshowView
                } else if selectedView == 1 {
                    GridView
                } else {
                    StacksView
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
                            .foregroundColor(.blue)
                            .font(.system(size: 16, weight: .bold))
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
                    .edgesIgnoringSafeArea(.all)
                    .presentationDetents([.large])
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
            .onDisappear {
                stopPlayback()
            }
            .sheet(isPresented: $showingDatePicker) {
                PhotoDatePickerSheet(date: $editedDate, isPresented: $showingDatePicker) {
                    if let photoToUpdate = selectedPhotoForDateEdit {
                        updatePhotoDate(photoToUpdate, newDate: editedDate)
                    }
                }
                .presentationDetents([.height(300)])
            }
        }
    }
    
    // Slideshow view
    private var SlideshowView: some View {
        GeometryReader { geometry in
            VStack {
                if !person.photos.isEmpty {
                    let sortedPhotos = person.photos.sorted(by: { $0.dateTaken < $1.dateTaken })
                    
                    TabView(selection: $currentPhotoIndex) {
                        ForEach(Array(sortedPhotos.enumerated()), id: \.element.id) { index, photo in
                            PhotoView(photo: photo, containerWidth: geometry.size.width, selectedPhoto: $selectedPhoto)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: 500) 
                    .gesture(DragGesture().onChanged { _ in
                        isManualInteraction = true
                    })
                    .onChange(of: currentPhotoIndex) { oldValue, newValue in
                        if isManualInteraction {
                            scrubberPosition = Double(newValue)
                        }
                    }
                    
                    VStack {
                        Text(calculateAge())
                            .font(.body)
                        Text(formatDate(sortedPhotos[currentPhotoIndex].dateTaken))
                            .font(.caption)
                            .foregroundColor(.gray)
                            .onTapGesture {
                                selectedPhotoForDateEdit = sortedPhotos[currentPhotoIndex]
                                editedDate = sortedPhotos[currentPhotoIndex].dateTaken
                                showingDatePicker = true
                            }
                    }
                    // .padding(.horizontal)
                    
                    Spacer()
                    
                    if sortedPhotos.count > 1 {
                        HStack {
                            playButton
                            
                            Slider(value: Binding(
                                get: { scrubberPosition },
                                set: { 
                                    isManualInteraction = true
                                    scrubberPosition = $0
                                    currentPhotoIndex = Int($0)
                                    latestPhotoIndex = currentPhotoIndex
                                }
                            ), in: 0...Double(sortedPhotos.count - 1), step: 0.01)
                            .accentColor(.blue)
                            
                            if isPlaying {
                                speedControlButton
                            } else {
                                shareButton
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
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
            scrubberPosition = Double(currentPhotoIndex)
        }
    }

    private struct PhotoView: View {
        let photo: Photo
        let containerWidth: CGFloat
        @Binding var selectedPhoto: Photo?
        
        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.clear)
                if let image = photo.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(10)
                        .padding(20)
                } else {
                    ProgressView()
                }
            }
            .frame(width: containerWidth) 
            .onTapGesture {
                selectedPhoto = photo
            }
        }
    }

    // Grid view
    private var GridView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(groupPhotosByAgeForYearView(), id: \.0) { section, photos in
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
                    ProgressView()
                        .frame(width: 110, height: 110)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .matchedGeometryEffect(id: photo.id, in: namespace)
                        .padding(.bottom, 2)
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
            let components = calendar.dateComponents([.year, .month, .day], from: person.dateOfBirth, to: photo.dateTaken)
            let years = components.year ?? 0
            let months = components.month ?? 0
            let days = components.day ?? 0

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
                let componentsBeforeBirth = calendar.dateComponents([.day], from: photo.dateTaken, to: person.dateOfBirth)
                let daysBeforeBirth = componentsBeforeBirth.day ?? 0
                let weeksBeforeBirth = daysBeforeBirth / 7
                let remainingDays = daysBeforeBirth % 7
                let pregnancyWeek = max(40 - weeksBeforeBirth, 0)
                
                if pregnancyWeek == 40 {
                    sectionTitle = "Birth Month"
                } else if pregnancyWeek > 0 {
                    if remainingDays > 0 {
                        sectionTitle = "\(pregnancyWeek) Week\(pregnancyWeek == 1 ? "" : "s") and \(remainingDays) Day\(remainingDays == 1 ? "" : "s") Pregnant"
                    } else {
                        sectionTitle = "\(pregnancyWeek) Week\(pregnancyWeek == 1 ? "" : "s") Pregnant"
                    }
                } else {
                    sectionTitle = "Before Pregnancy"
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
    
    // New function for grouping photos in the year view
    private func groupPhotosByAgeForYearView() -> [(String, [Photo])] {
        let calendar = Calendar.current
        let sortedPhotos = person.photos.sorted(by: { $0.dateTaken > $1.dateTaken })
        var groupedPhotos: [(String, [Photo])] = []

        for photo in sortedPhotos {
            let components = calendar.dateComponents([.year, .month, .day], from: person.dateOfBirth, to: photo.dateTaken)
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
                let componentsBeforeBirth = calendar.dateComponents([.day], from: photo.dateTaken, to: person.dateOfBirth)
                let daysBeforeBirth = componentsBeforeBirth.day ?? 0
                let weeksBeforeBirth = daysBeforeBirth / 7
                let pregnancyWeek = max(40 - weeksBeforeBirth, 0)
                
                if pregnancyWeek == 40 {
                    sectionTitle = "Birth Month"
                } else if pregnancyWeek > 0 {
                    sectionTitle = "\(pregnancyWeek) Week\(pregnancyWeek == 1 ? "" : "s") Pregnant"
                } else {
                    sectionTitle = "Before Pregnancy"
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

    // Play button
    private var playButton: some View {
        Button(action: {
            if currentPhotoIndex == person.photos.count - 1 {
                // Move scrubber to the beginning
                currentPhotoIndex = 0
                scrubberPosition = 0
                isManualInteraction = true
            } else {
                isPlaying.toggle()
                if isPlaying {
                    startPlayback()
                } else {
                    stopPlayback()
                }
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 36, height: 36)
                
                Image(systemName: currentPhotoIndex == person.photos.count - 1 ? "arrow.counterclockwise" : (isPlaying ? "pause.fill" : "play.fill"))
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .bold))
            }
        }
    }

    private func startPlayback() {
        isManualInteraction = false
        lastUpdateTime = Date()
        playTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { timer in
            let currentTime = Date()
            let elapsedTime = currentTime.timeIntervalSince(lastUpdateTime)
            lastUpdateTime = currentTime

            scrubberPosition += elapsedTime * playbackSpeed / 2.0
            
            if scrubberPosition >= Double(person.photos.count - 1) {
                stopPlayback()
                scrubberPosition = Double(person.photos.count - 1)
            }

            currentPhotoIndex = Int(scrubberPosition)
        }
    }

    private func stopPlayback() {
        playTimer?.invalidate()
        playTimer = nil
        isPlaying = false
        scrubberPosition = Double(currentPhotoIndex)
    }

    // Speed control button
    private var speedControlButton: some View {
        Button(action: {
            playbackSpeed = playbackSpeed >= 3 ? 1 : playbackSpeed + 1
            if isPlaying {
                // Instead of stopping and starting, just update the timer interval
                playTimer?.invalidate()
                startPlayback()
            }
        }) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 36, height: 36)
                
                Text("\(Int(playbackSpeed))x")
                    .foregroundColor(.blue)
                    .font(.system(size: 14, weight: .bold))
            }
        }
    }

    // New share button
    private var shareButton: some View {
        Button(action: {
            activeSheet = .shareView
        }) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 36, height: 36)
                
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .bold))
            }
        }
    }

    private func updatePhotoDate(_ photo: Photo, newDate: Date) {
        if let index = person.photos.firstIndex(where: { $0.id == photo.id }) {
            person.photos[index].dateTaken = newDate
            viewModel.updatePerson(person)
        }
    }

    // New Stacks view
    private var StacksView: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 15) {
                    ForEach(groupPhotosByAgeForYearView(), id: \.0) { section, photos in
                        StackSectionView(
                            section: section,
                            photos: photos,
                            selectedPhoto: $selectedPhoto,
                            person: person,
                            cardHeight: 200,
                            maxWidth: geometry.size.width - 30
                        )
                    }
                }
                .padding()
            }
        }
    }
}

// New StackSectionView
private struct StackSectionView: View {
    let section: String
    let photos: [Photo]
    @Binding var selectedPhoto: Photo?
    let person: Person
    let cardHeight: CGFloat
    let maxWidth: CGFloat
    
    var body: some View {
        NavigationLink(destination: AllPhotosInSectionView(sectionTitle: section, photos: photos, onDelete: { _ in }, person: person)) {
            if let randomPhoto = photos.randomElement() {
                ZStack(alignment: .bottom) {
                    if let image = randomPhoto.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: cardHeight)
                            .frame(maxWidth: maxWidth)
                            .clipped()
                            .cornerRadius(10)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: cardHeight)
                            .frame(maxWidth: maxWidth)
                            .cornerRadius(10)
                    }
                    
                    // Add the gradient overlay
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: cardHeight / 3)
                    .frame(maxWidth: maxWidth)
                    .cornerRadius(10)
                    
                    HStack {
                        Text(section)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(8)
                        
                        Spacer()
                        
                        Text("\(photos.count) photo\(photos.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(5)
                    }
                    .padding(8)
                }
            } else {
                Text("No photos available")
                    .italic()
                    .foregroundColor(.gray)
                    .frame(height: cardHeight)
                    .frame(maxWidth: maxWidth)
            }
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
                .font(.system(size: 16, weight: .bold))
        }
    }
}
