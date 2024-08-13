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
    @State private var showingSharingComingSoon = false
    @State private var currentScrollPosition: String?
    @State private var isImagePickerPresented = false
    @State private var currentMoment: String = ""
    @State private var isCustomImagePickerPresented = false
    @State private var customImagePickerTargetDate = Date()
    @State private var birthMonthsDisplay: Person.BirthMonthsDisplay

    // Initializer
    init(person: Person, viewModel: PersonViewModel) {
        self._person = State(initialValue: person)
        self.viewModel = viewModel
        self._birthMonthsDisplay = State(initialValue: person.birthMonthsDisplay)
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
                    Text(person.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        activeSheet = .settings
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.blue)
                    }
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
                        _ = Photo(asset: asset)
                        self.viewModel.addPhoto(to: &self.person, asset: asset)
                    }
                }
            }
            .sheet(isPresented: $isCustomImagePickerPresented) {
                NavigationView {
                    CustomImagePicker(
                        isPresented: $isCustomImagePickerPresented,
                        targetDate: customImagePickerTargetDate,
                        person: person,
                        onPick: { assets in
                            for asset in assets {
                                self.viewModel.addPhoto(to: &self.person, asset: asset)
                            }
                        }
                    )
                }
            }
            .onChange(of: person.birthMonthsDisplay) { oldValue, newValue in
                birthMonthsDisplay = newValue
            }
        }
    }
    
    @ViewBuilder
    private func mainContent(_ geometry: GeometryProxy) -> some View {
        ScrollViewReader { scrollProxy in
            switch selectedView {
            case 0:
                StacksView(
                    viewModel: viewModel,
                    person: $person,
                    selectedPhoto: $selectedPhoto
                )
                .transition(.opacity)
            case 1:
                GridView(
                    viewModel: viewModel,
                    person: $person,
                    selectedPhoto: $selectedPhoto,
                    currentScrollPosition: $currentScrollPosition,
                    openImagePickerForMoment: openImagePickerForMoment,
                    deletePhoto: deletePhoto,
                    scrollToSection: { section in
                        scrollToStoredPosition(proxy: scrollProxy, section: section)
                    }
                )
                .transition(.opacity)
                .onChange(of: selectedView) { oldValue, newValue in
                    if newValue == 1 {
                        scrollToStoredPosition(proxy: scrollProxy)
                    }
                }
            default:
                TimelineView(viewModel: viewModel, person: $person, selectedPhoto: $selectedPhoto)
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
                print("No photos available to share")
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

    // New function to open image picker for a specific moment
    private func openImagePickerForMoment(_ moment: String) {
        currentMoment = moment
        let calendar = Calendar.current
        var targetDate = person.dateOfBirth

        if moment == "Pregnancy" {
            targetDate = calendar.date(byAdding: .month, value: -4, to: person.dateOfBirth) ?? person.dateOfBirth
        } else if moment.contains("Month") {
            if let monthNumber = Int(moment.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                targetDate = calendar.date(byAdding: .month, value: monthNumber, to: person.dateOfBirth) ?? person.dateOfBirth
            }
        } else if moment.contains("Year") {
            if let yearNumber = Int(moment.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                targetDate = calendar.date(byAdding: .year, value: yearNumber, to: person.dateOfBirth) ?? person.dateOfBirth
            }
        }

        isCustomImagePickerPresented = true
        customImagePickerTargetDate = targetDate
    }

    // Helper function to get the date for a specific moment
    private func dateForMoment(_ moment: String) -> Date {
        let calendar = Calendar.current
        
        if moment == "Pregnancy" {
            return calendar.date(byAdding: .month, value: -9, to: person.dateOfBirth) ?? person.dateOfBirth
        } else if moment == "Birth Month" {
            return person.dateOfBirth
        } else if moment.contains("Month") {
            let months = Int(moment.components(separatedBy: " ").first ?? "0") ?? 0
            return calendar.date(byAdding: .month, value: months, to: person.dateOfBirth) ?? person.dateOfBirth
        } else if moment.contains("Year") {
            let years = Int(moment.components(separatedBy: " ").first ?? "0") ?? 0
            return calendar.date(byAdding: .year, value: years, to: person.dateOfBirth) ?? person.dateOfBirth
        }
        
        return person.dateOfBirth
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

    // Circular button
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
    private func scrollToStoredPosition(proxy: ScrollViewProxy, section: String? = nil) {
        let positionToScroll = section ?? currentScrollPosition
        if let position = positionToScroll {
            withAnimation {
                proxy.scrollTo(position, anchor: .top)
            }
        }
    }

    private func sortedGroupedPhotosForAll() -> [(String, [Photo])] {
        return PhotoUtils.sortedGroupedPhotosForAll(person: person, viewModel: viewModel)
    }

    private func groupAndSortPhotos(forYearView: Bool) -> [(String, [Photo])] {
        return PhotoUtils.groupAndSortPhotos(
            for: person,
            sortOrder: viewModel.sortOrder
        )
    }

    private func bigMoments() -> [(String, [Photo])] {
        var moments: [(String, [Photo])] = []
        let calendar = Calendar.current
        let sortedPhotos = person.photos.sorted { $0.dateTaken < $1.dateTaken }
        
        // Birth
        let birthPhotos = sortedPhotos.filter { calendar.isDate($0.dateTaken, inSameDayAs: person.dateOfBirth) }
        moments.append(("Birth", birthPhotos))
        
        // First 12 months
        for month in 1...12 {
            let startDate = calendar.date(byAdding: .month, value: month - 1, to: person.dateOfBirth)!
            let endDate = calendar.date(byAdding: .month, value: month, to: person.dateOfBirth)!
            let monthPhotos = sortedPhotos.filter { $0.dateTaken >= startDate && $0.dateTaken < endDate }
            moments.append(("\(month) Month\(month == 1 ? "" : "s")", monthPhotos))
        }
        
        // Years
        let currentDate = Date()
        let ageComponents = calendar.dateComponents([.year], from: person.dateOfBirth, to: currentDate)
        let age = ageComponents.year ?? 0
        
        for year in 1...max(age, 1) {
            let startDate = calendar.date(byAdding: .year, value: year - 1, to: person.dateOfBirth)!
            let endDate = calendar.date(byAdding: .year, value: year, to: person.dateOfBirth)!
            let yearPhotos = sortedPhotos.filter { $0.dateTaken >= startDate && $0.dateTaken < endDate }
            moments.append(("\(year) Year\(year == 1 ? "" : "s")", yearPhotos))
        }
        
        return moments
    }
}

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
