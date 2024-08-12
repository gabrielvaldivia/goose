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
    case sharingComingSoon
    
    var id: Int {
        hashValue
    }
}

struct ImagePickerRepresentable: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let targetDate: Date
    let onPick: ([PHAsset]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0 // Allow multiple selection
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePickerRepresentable

        init(_ parent: ImagePickerRepresentable) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
            
            let identifiers = results.compactMap(\.assetIdentifier)
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            let assets = (0..<fetchResult.count).compactMap { fetchResult.object(at: $0) }
            parent.onPick(assets)
        }
    }
}

// Main view struct
struct PersonDetailView: View {
    // State and observed properties
    @ObservedObject var viewModel: PersonViewModel
    @State private var person: Person
    @State private var showingImagePicker = false
    @State private var selectedAssets: [PHAsset] = []
    @State private var showingDeleteAlert = false
    @State private var photoToDelete: Photo?
    @State private var selectedView = 2 
    @State private var activeSheet: ActiveSheet?
    @State private var selectedPhoto: Photo? = nil 
    @State private var isShareSheetPresented = false
    @State private var activityItems: [Any] = []
    @State private var showingDatePicker = false
    @State private var selectedPhotoForDateEdit: Photo?
    @State private var editedDate: Date = Date()
    @State private var stacksSortOrder: SortOrder = .latestToOldest
    @State private var timelineSortOrder: SortOrder = .latestToOldest
    @State private var showingSharingComingSoon = false
    @State private var currentScrollPosition: String?
    @State private var isImagePickerPresented = false
    @State private var currentMoment: String = ""
    @State private var isCustomImagePickerPresented = false

    // Initializer
    init(person: Person, viewModel: PersonViewModel) {
        self.person = person
        self.viewModel = viewModel
    }
    
    // Main body of the view
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                mainContent(geometry)
                bottomControls
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button(action: {
                        activeSheet = .settings
                    }) {
                        HStack(spacing: 8) {
                            Text(person.name)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                                .font(.system(size: 8, weight: .bold))
                                .frame(width: 20, height: 20)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    sortButton
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: CustomBackButton())
            .sheet(isPresented: $showingImagePicker, onDismiss: loadImage) {
                ImagePicker(selectedAssets: $selectedAssets, isPresented: $showingImagePicker)
                    .edgesIgnoringSafeArea(.all)
                    .presentationDetents([.large])
            }
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
                    ShareSlideshowView(
                        photos: person.photos,
                        person: person,
                        sectionTitle: "All Photos"
                    )
                case .sharingComingSoon:
                    SharingComingSoonView()
                }
            }
            .sheet(isPresented: $isShareSheetPresented) {
                ActivityViewController(activityItems: activityItems)
            }
            .onChange(of: selectedAssets) { oldValue, newValue in
                handleSelectedAssetsChange(oldValue: oldValue, newValue: newValue)
            }
            .onAppear(perform: handleOnAppear)
            .alert(isPresented: $showingDeleteAlert, content: deletePhotoAlert)
            .fullScreenCover(item: $selectedPhoto) { photo in
                FullScreenPhotoView(
                    photo: photo,
                    currentIndex: person.photos.firstIndex(of: photo) ?? 0,
                    photos: person.photos,
                    onDelete: deletePhoto,
                    person: person
                )
            }
            .sheet(isPresented: $showingDatePicker, content: photoDatePickerSheet)
            .onAppear {
                viewModel.setLastOpenedPerson(person)
            }
            .sheet(isPresented: $isImagePickerPresented) {
                ImagePickerRepresentable(isPresented: $isImagePickerPresented, targetDate: dateForMoment(currentMoment)) { assets in
                    for asset in assets {
                        let newPhoto = Photo(asset: asset)
                        self.viewModel.addPhoto(to: &self.person, asset: asset)
                    }
                }
            }
            .sheet(isPresented: $isCustomImagePickerPresented) {
                NavigationView {
                    CustomImagePicker(isPresented: $isCustomImagePickerPresented, targetDate: dateForMoment(currentMoment)) { assets in
                        for asset in assets {
                            self.viewModel.addPhoto(to: &self.person, asset: asset)
                        }
                    }
                }
            }
        }
    }
    
    // Break down the main content into a separate function
    @ViewBuilder
    private func mainContent(_ geometry: GeometryProxy) -> some View {
        ScrollViewReader { scrollProxy in
            switch selectedView {
            case 0:
                StacksView
                    .transition(.opacity)
            case 1:
                GridView
                    .transition(.opacity)
                    .onChange(of: selectedView) { oldValue, newValue in
                        if newValue == 1 {
                            scrollToStoredPosition(proxy: scrollProxy)
                        }
                    }
            default:
                TimelineView
                    .transition(.opacity)
                    .onChange(of: selectedView) { oldValue, newValue in
                        if newValue == 2 {
                            scrollToStoredPosition(proxy: scrollProxy)
                        }
                    }
            }
        }
    }

    // Bottom controls
    private var bottomControls: some View {
        VStack {
            Spacer()
            HStack {
                shareButton

                Spacer()

                SegmentedControlView(selectedView: $selectedView)

                Spacer()

                CircularButton(systemName: "plus") {
                    showingImagePicker = true
                }
            }
            .padding(.horizontal)
        }
    }

    // Updated share button
    private var shareButton: some View {
        CircularButton(systemName: "square.and.arrow.up") {
            if !person.photos.isEmpty {
                activeSheet = .shareView
            } else {
                // Show an alert or message when there are no photos
                print("No photos available to share")
            }
        }
    }

    // Updated sort button
    private var sortButton: some View {
        Button(action: {
            toggleSortOrder()
        }) {
            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 30, height: 30)
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundColor(.blue)
                    .font(.system(size: 14, weight: .bold))
            }
        }
    }

    // New Timeline view
    private var TimelineView: some View {
        ScrollView {
            LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                ForEach(sortedGroupedPhotosForAll(), id: \.0) { section, photos in
                    Section(header: stickyHeader(for: section)) {
                        ForEach(sortPhotos(photos, order: timelineSortOrder), id: \.id) { photo in
                            TimelineItemView(photo: photo, person: person, selectedPhoto: $selectedPhoto)
                        }
                    }
                    .id(section)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 80) // Increased bottom padding
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            updateScrollPosition(value)
        }
    }

    private func stickyHeader(for section: String) -> some View {
        HStack {
            Spacer()
            Text(section)
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    VisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
                        .clipShape(Capsule())
                )
            Spacer()
        }
        .padding(.top, 8)
    }

    private struct TimelineItemView: View {
        let photo: Photo
        let person: Person
        @Binding var selectedPhoto: Photo?
        
        var body: some View {
            PhotoView(photo: photo, containerWidth: UIScreen.main.bounds.width - 40, isGridView: false, selectedPhoto: $selectedPhoto)
                .aspectRatio(contentMode: .fit)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
                .onTapGesture {
                    selectedPhoto = photo
                }
        }
    }

    private struct PhotoView: View {
        let photo: Photo
        let containerWidth: CGFloat
        let isGridView: Bool
        @Binding var selectedPhoto: Photo?
        
        var body: some View {
            Group {
                if let image = photo.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: isGridView ? .fill : .fit)
                        .frame(width: isGridView ? containerWidth : nil, height: isGridView ? containerWidth : nil)
                        .clipped()
                } else {
                    ProgressView()
                        .frame(width: isGridView ? containerWidth : nil, height: isGridView ? containerWidth : 200)
                        .background(Color.gray.opacity(0.2))
                }
            }
            .cornerRadius(isGridView ? 10 : 0)
            .onTapGesture {
                selectedPhoto = photo
            }
        }
    }

    // Grid view
    private var GridView: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 16 // Increased spacing between tiles
            let itemWidth = (geometry.size.width - 40 - spacing * 2) / 3 // Adjusted for new spacing
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3), spacing: spacing) {
                    ForEach(bigMoments(), id: \.0) { section, photos in
                        if photos.isEmpty {
                            EmptyStackView(section: section, width: itemWidth) {
                                openImagePickerForMoment(section)
                            }
                        } else {
                            NavigationLink(destination: StackDetailView(sectionTitle: section, photos: photos, onDelete: deletePhoto, person: person)) {
                                StackTileView(section: section, photos: photos, width: itemWidth)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 80)
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                updateScrollPosition(value)
            }
        }
    }

    private struct EmptyStackView: View {
        let section: String
        let width: CGFloat
        let action: () -> Void
        
        var body: some View {
            VStack(spacing: 4) {
                Button(action: action) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: width, height: width)
                
                Text(section)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: width)
            }
        }
    }

    private struct StackTileView: View {
        let section: String
        let photos: [Photo]
        let width: CGFloat
        
        var body: some View {
            VStack(spacing: 4) {
                ZStack {
                    if let firstPhoto = photos.first, let image = firstPhoto.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: width, height: width)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    }
                    
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            // Text("\(photos.count)")
                            //     .font(.caption)
                            //     .padding(6)
                            //     .background(Color.black.opacity(0.6))
                            //     .foregroundColor(.white)
                            //     .clipShape(Circle())
                        }
                    }
                    .padding(4)
                }
                .frame(width: width, height: width)
                .cornerRadius(8)
                
                Text(section)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: width)
            }
        }
    }

    // New function to open image picker for a specific moment
    private func openImagePickerForMoment(_ moment: String) {
        currentMoment = moment
        if moment == "First Year" {
            // For "First Year", set the target date to 6 months after birth
            let calendar = Calendar.current
            if let sixMonthsAfterBirth = calendar.date(byAdding: .month, value: 6, to: person.dateOfBirth) {
                isCustomImagePickerPresented = true
                currentMoment = "6 Months"
            }
        } else {
            isCustomImagePickerPresented = true
        }
    }

    // Helper function to get the date for a specific moment
    private func dateForMoment(_ moment: String) -> Date {
        let calendar = Calendar.current
        
        if moment == "Pregnancy" {
            return calendar.date(byAdding: .month, value: -9, to: person.dateOfBirth) ?? person.dateOfBirth
        } else if moment == "Birth" {
            return person.dateOfBirth
        } else if moment == "First Year" {
            // For "First Year", return the date 6 months after birth
            return calendar.date(byAdding: .month, value: 6, to: person.dateOfBirth) ?? person.dateOfBirth
        } else if moment.contains("Month") {
            let months = Int(moment.components(separatedBy: " ").first ?? "0") ?? 0
            return calendar.date(byAdding: .month, value: months, to: person.dateOfBirth) ?? person.dateOfBirth
        } else if moment.contains("Year") {
            let years = Int(moment.components(separatedBy: " ").first ?? "0") ?? 0
            return calendar.date(byAdding: .year, value: years, to: person.dateOfBirth) ?? person.dateOfBirth
        }
        
        return person.dateOfBirth
    }

    // Function to generate big moments
    private func bigMoments() -> [(String, [Photo])] {
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year, .month], from: person.dateOfBirth, to: now)
        let currentAge = ageComponents.year ?? 0
        
        var moments: [(String, [Photo])] = []
        
        // Add pregnancy moment
        let pregnancyPhotos = person.photos.filter { $0.dateTaken < person.dateOfBirth }
        moments.append(("Pregnancy", pregnancyPhotos))
        
        // Add birth month
        let birthMonthEnd = calendar.date(byAdding: .month, value: 1, to: person.dateOfBirth)!
        let birthMonthPhotos = person.photos.filter { $0.dateTaken >= person.dateOfBirth && $0.dateTaken < birthMonthEnd }
        moments.append(("Birth", birthMonthPhotos))
        
        // Add first 11 months
        for month in 1...11 {
            let monthStart = calendar.date(byAdding: .month, value: month, to: person.dateOfBirth)!
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
            let monthPhotos = person.photos.filter { $0.dateTaken >= monthStart && $0.dateTaken < monthEnd }
            moments.append(("\(month) Month\(month == 1 ? "" : "s")", monthPhotos))
        }
        
        // Add years
        for year in 1...currentAge {
            let yearStart = calendar.date(byAdding: .year, value: year, to: person.dateOfBirth)!
            let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart)!
            let yearPhotos = person.photos.filter { $0.dateTaken >= yearStart && $0.dateTaken < yearEnd }
            moments.append(("\(year) Year\(year == 1 ? "" : "s")", yearPhotos))
        }
        
        return moments.sorted { (moment1, moment2) -> Bool in
            let order1 = orderFromSectionTitle(moment1.0)
            let order2 = orderFromSectionTitle(moment2.0)
            return stacksSortOrder == .latestToOldest ? order1 > order2 : order1 < order2
        }
    }

    // Function to group photos by age
    private func groupAndSortPhotos(forYearView: Bool = false, sortOrder: SortOrder = .latestToOldest) -> [(String, [Photo])] {
        let calendar = Calendar.current
        let sortedPhotos = sortPhotos(person.photos, order: sortOrder)
        var groupedPhotos: [String: [Photo]] = [:]

        for photo in sortedPhotos {
            let components = calendar.dateComponents([.year, .month], from: person.dateOfBirth, to: photo.dateTaken)
            let years = components.year ?? 0
            let months = components.month ?? 0

            let sectionTitle: String
            if photo.dateTaken >= person.dateOfBirth {
                if years == 0 && months == 0 {
                    sectionTitle = "Birth Month"
                } else if years == 0 {
                    sectionTitle = "\(months) Month\(months == 1 ? "" : "s")"
                } else {
                    sectionTitle = "\(years) Year\(years == 1 ? "" : "s")"
                }
            } else {
                sectionTitle = forYearView ? "Pregnancy" : calculatePregnancyWeek(photo.dateTaken)
            }

            groupedPhotos[sectionTitle, default: []].append(photo)
        }

        return groupedPhotos.map { ($0.key, $0.value) }
    }

    private func calculatePregnancyWeek(_ date: Date) -> String {
        let calendar = Calendar.current
        let componentsBeforeBirth = calendar.dateComponents([.day], from: date, to: person.dateOfBirth)
        let daysBeforeBirth = componentsBeforeBirth.day ?? 0
        let weeksBeforeBirth = daysBeforeBirth / 7
        let remainingDays = daysBeforeBirth % 7
        let pregnancyWeek = max(40 - weeksBeforeBirth, 0)
        
        if pregnancyWeek == 40 {
            return "Birth Month"
        } else if pregnancyWeek > 0 {
            if remainingDays > 0 {
                return "\(pregnancyWeek) Week\(pregnancyWeek == 1 ? "" : "s") and \(remainingDays) Day\(remainingDays == 1 ? "" : "s") Pregnant"
            } else {
                return "\(pregnancyWeek) Week\(pregnancyWeek == 1 ? "" : "s") Pregnant"
            }
        } else {
            return "Before Pregnancy"
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
    
    private func updatePhotoDate(_ photo: Photo, newDate: Date) {
        if let index = person.photos.firstIndex(where: { $0.id == photo.id }) {
            person.photos[index].dateTaken = newDate
            viewModel.updatePerson(person)
        }
    }

    // New Stacks view
    private var StacksView: some View {
        GeometryReader { geometry in
            VStack {
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(sortedGroupedPhotosForAll(), id: \.0) { section, photos in
                            StackSectionView(
                                section: section,
                                photos: photos,
                                selectedPhoto: $selectedPhoto,
                                person: person,
                                cardHeight: 300,
                                maxWidth: geometry.size.width - 30
                            )
                        }
                    }
                    .padding()
                    .padding(.bottom, 80) // Increased bottom padding
                }
            }
        }
    }

    // Sort grouped photos based on stacksSortOrder
    private func sortedGroupedPhotosForAll() -> [(String, [Photo])] {
        let groupedPhotos = groupAndSortPhotos(forYearView: true, sortOrder: stacksSortOrder)
        
        let sortedGroups = groupedPhotos.sorted { (group1, group2) -> Bool in
            let order1 = orderFromSectionTitle(group1.0)
            let order2 = orderFromSectionTitle(group2.0)
            return stacksSortOrder == .latestToOldest ? order1 > order2 : order1 < order2
        }
        
        return sortedGroups
    }

    private func orderFromSectionTitle(_ title: String) -> Int {
        if title == "Pregnancy" { return -1 }
        if title == "Birth" { return 0 }
        if title.contains("Month") {
            let months = Int(title.components(separatedBy: " ").first ?? "0") ?? 0
            return months
        }
        if title.contains("Year") {
            let years = Int(title.components(separatedBy: " ").first ?? "0") ?? 0
            return years * 12 + 1000 // Add 1000 to ensure years come after months
        }
        return 0
    }

    // Circular buttonn
    struct CircularButton: View {
        let systemName: String
        let action: () -> Void
        @Environment(\.colorScheme) var colorScheme

        var body: some View {
            Button(action: action) {
                Image(systemName: systemName)
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5))
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 40, height: 40)
            }
            .background(
                ZStack {
                    VisualEffectView(effect: UIBlurEffect(style: colorScheme == .dark ? .dark : .light))
                    if colorScheme == .light {
                        Color.black.opacity(0.1)
                    }
                }
            )
            .clipShape(Circle())
        }
    }

    // Functions to handle various aspects of the view
    private func handleSelectedAssetsChange(oldValue: [PHAsset], newValue: [PHAsset]) {
        if !newValue.isEmpty {
            print("Assets selected: \(newValue)")
            loadImage()
        } else {
            print("No assets selected")
        }
    }

    private func handleOnAppear() {
        if let updatedPerson = viewModel.people.first(where: { $0.id == person.id }) {
            person = updatedPerson
        }
    }

    private func deletePhotoAlert() -> Alert {
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

    private func photoDatePickerSheet() -> some View {
        PhotoDatePickerSheet(date: $editedDate, isPresented: $showingDatePicker) {
            if let photoToUpdate = selectedPhotoForDateEdit {
                updatePhotoDate(photoToUpdate, newDate: editedDate)
            }
        }
        .presentationDetents([.height(300)])
    }

    // Add this new function to toggle sort order
    private func toggleSortOrder() {
        let newOrder = stacksSortOrder == .oldestToLatest ? SortOrder.latestToOldest : SortOrder.oldestToLatest
        stacksSortOrder = newOrder
        timelineSortOrder = newOrder
    }

    // Add this new function to sort photos
    private func sortPhotos(_ photos: [Photo], order: SortOrder) -> [Photo] {
        photos.sorted { photo1, photo2 in
            switch order {
            case .latestToOldest:
                return photo1.dateTaken > photo2.dateTaken
            case .oldestToLatest:
                return photo1.dateTaken < photo2.dateTaken
            }
        }
    }

    // New function to update scroll position
    private func updateScrollPosition(_ value: CGPoint) {
        let sections = sortedGroupedPhotosForAll().map { $0.0 }
        if let index = sections.firstIndex(where: { section in
            let sectionY = value.y + UIScreen.main.bounds.height / 2
            return sectionY >= 0 && sectionY <= UIScreen.main.bounds.height
        }) {
            currentScrollPosition = sections[index]
        }
    }

    // New function to scroll to stored position
    private func scrollToStoredPosition(proxy: ScrollViewProxy) {
        if let position = currentScrollPosition {
            withAnimation {
                proxy.scrollTo(position, anchor: .top)
            }
        }
    }
}

// Add this new view
struct SharingComingSoonView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Text("Sharing multiple photos is coming soon")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Dismiss") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
        }
        .presentationDetents([.large])
    }
}

// New SegmentedControlView
struct SegmentedControlView: View {
    @Binding var selectedView: Int
    @Namespace private var animation
    @Environment(\.colorScheme) var colorScheme
    
    let options = ["Stacks", "Grid", "Timeline"]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.15)) {
                        selectedView = index
                    }
                }) {
                    Text(options[index])
                        .font(.system(size: 14, weight: .bold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            ZStack {
                                if selectedView == index {
                                    Capsule()
                                        .fill(Color.primary.opacity(0.3))
                                        .matchedGeometryEffect(id: "SelectedSegment", in: animation)
                                }
                            }
                        )
                        .foregroundColor(colorScheme == .dark ? (selectedView == index ? .white : .white.opacity(0.5)) : (selectedView == index ? .white : .black.opacity(0.5)))
                }
            }
        }
        .padding(4)
        .background(
            ZStack {
                VisualEffectView(effect: UIBlurEffect(style: colorScheme == .dark ? .dark : .light))
                if colorScheme == .light {
                    Color.black.opacity(0.1)
                }
            }
        )
        .clipShape(Capsule())
    }
}

// Circular Button
struct CircularButton: View {
    let systemName: String
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.5))
                .font(.system(size: 14, weight: .bold))
                .frame(width: 40, height: 40)
        }
        .background(
            ZStack {
                VisualEffectView(effect: UIBlurEffect(style: colorScheme == .dark ? .dark : .light))
                if colorScheme == .light {
                    Color.black.opacity(0.1)
                }
            }
        )
        .clipShape(Circle())
    }
}

struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView { UIVisualEffectView() }
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) { uiView.effect = effect }
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
        NavigationLink(destination: StackDetailView(sectionTitle: section, photos: photos, onDelete: { _ in }, person: person)) {
            if let randomPhoto = photos.randomElement() {
                ZStack(alignment: .bottom) {
                    if let image = randomPhoto.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: cardHeight)
                            .frame(maxWidth: maxWidth)
                            .clipped()
                            .cornerRadius(20)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: cardHeight)
                            .frame(maxWidth: maxWidth)
                            .cornerRadius(20)
                    }
                    
                    // Gradient overlay
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: cardHeight / 3)
                    .frame(maxWidth: maxWidth)
                    .cornerRadius(20)
                    
                    HStack {
                        HStack(spacing: 8) {
                            Text(section)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.system(size: 18, weight: .bold))
                        }
                        
                        Spacer()
                        
                        Text("\(photos.count) photo\(photos.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                    .padding()
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
    @EnvironmentObject var viewModel: PersonViewModel

    var body: some View {
        Button(action: {
            // This will pop to the root view (ContentView)
            self.presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "chevron.left")
                .foregroundColor(.blue)
                .font(.system(size: 14, weight: .bold))
        }
    }
}

// Add this enum outside the PersonDetailView struct
enum SortOrder {
    case oldestToLatest
    case latestToOldest
}

// New preference key for scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {}
}

// New view modifier to track scroll position
struct ScrollOffsetModifier: ViewModifier {
    let coordinateSpace: String
    @Binding var offset: CGPoint

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named(coordinateSpace)).origin)
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                offset = value
            }
    }
}

// Extension to make the modifier easier to use
extension View {
    func trackScrollOffset(coordinateSpace: String, offset: Binding<CGPoint>) -> some View {
        modifier(ScrollOffsetModifier(coordinateSpace: coordinateSpace, offset: offset))
    }
}
