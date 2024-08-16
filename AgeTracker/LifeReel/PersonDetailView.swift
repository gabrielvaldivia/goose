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

enum ActiveSheet: Identifiable, Hashable {
    case settings
    case shareView
    case sharingComingSoon
    case customImagePicker(moment: String, dateRange: (start: Date, end: Date))
    
    var id: Self { self }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .settings:
            hasher.combine(0)
        case .shareView:
            hasher.combine(1)
        case .sharingComingSoon:
            hasher.combine(2)
        case .customImagePicker(let moment, let dateRange):
            hasher.combine(3)
            hasher.combine(moment)
            hasher.combine(dateRange.start)
            hasher.combine(dateRange.end)
        }
    }
    
    static func == (lhs: ActiveSheet, rhs: ActiveSheet) -> Bool {
        switch (lhs, rhs) {
        case (.settings, .settings),
             (.shareView, .shareView),
             (.sharingComingSoon, .sharingComingSoon):
            return true
        case let (.customImagePicker(lMoment, lDateRange), .customImagePicker(rMoment, rDateRange)):
            return lMoment == rMoment && lDateRange.start == rDateRange.start && lDateRange.end == rDateRange.end
        default:
            return false
        }
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
    @Binding var person: Person
    @State private var showingImagePicker = false
    @State private var selectedAssets: [PHAsset] = []
    @State private var showingDeleteAlert = false
    @State private var photoToDelete: Photo?
    @State private var selectedTab = 1 // Changed from 0 to 1 for Timeline
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
    @State private var animationDirection: UIPageViewController.NavigationDirection = .forward
    @State private var currentSection: String?
    @State private var forceUpdate: Bool = false

    // Initializer
    init(person: Binding<Person>, viewModel: PersonViewModel) {
        self._person = person
        self.viewModel = viewModel
        self._birthMonthsDisplay = State(initialValue: person.wrappedValue.birthMonthsDisplay)
    }
    
    // Main body of the view
    var body: some View {
        ZStack(alignment: .bottom) {
            PageViewController(
                pages: [
                    AnyView(StacksGridView(viewModel: viewModel, person: $person, selectedPhoto: $selectedPhoto, openImagePickerForMoment: openImagePickerForMoment, forceUpdate: forceUpdate)
                        .ignoresSafeArea(edges: .bottom)),
                    AnyView(SharedTimelineView(viewModel: viewModel, person: $person, selectedPhoto: $selectedPhoto, photos: person.photos, forceUpdate: forceUpdate)
                        .ignoresSafeArea(edges: .bottom))
                ],
                currentPage: $selectedTab,
                animationDirection: $animationDirection
            )
            .ignoresSafeArea(edges: .bottom)

            bottomControls
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(person.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                settingsButton
            }
        }
        .sheet(isPresented: $showingImagePicker, onDismiss: loadImage) {
            ImagePicker(selectedAssets: $selectedAssets, isPresented: $showingImagePicker)
                .edgesIgnoringSafeArea(.all)
                .presentationDetents([.large])
        }
        .sheet(item: $activeSheet, content: sheetContent)
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
            if let section = currentSection {
                CustomImagePicker(
                    viewModel: viewModel,
                    person: $person,
                    sectionTitle: section,
                    isPresented: $isImagePickerPresented,
                    onPhotosAdded: { newPhotos in
                        viewModel.updatePerson(person)
                    }
                )
            }
        }
        .sheet(isPresented: $isCustomImagePickerPresented) {
            CustomImagePicker(
                viewModel: viewModel,
                person: $person,
                sectionTitle: currentMoment,
                isPresented: $isCustomImagePickerPresented,
                onPhotosAdded: { newPhotos in
                    // Handle newly added photos
                    viewModel.updatePerson(person)
                }
            )
        }
        .onChange(of: person.birthMonthsDisplay) { oldValue, newValue in
            birthMonthsDisplay = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            // Force view update on orientation change
            viewModel.objectWillChange.send()
        }
    }

    // Bottom controls
    private var bottomControls: some View {
        BottomControls(
            shareAction: {
                if !person.photos.isEmpty {
                    activeSheet = .shareView
                } else {
                    print("No photos available to share")
                }
            },
            addPhotoAction: {
                showingImagePicker = true
            },
            selectedTab: $selectedTab,
            animationDirection: $animationDirection
        )
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
    private func openImagePickerForMoment(_ section: String, _ dateRange: (Date, Date)) {
        currentSection = section
        currentMoment = section
        isImagePickerPresented = true
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
            if let newPhoto = Photo(asset: asset) {
                self.viewModel.addPhoto(to: &self.person, asset: asset)
                print("Added photo with date: \(newPhoto.dateTaken) and identifier: \(newPhoto.assetIdentifier)")
            }
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
        return PhotoUtils.groupAndSortPhotos(for: person)
    }

    private func bigMoments() -> [(String, [Photo])] {
        var moments: [(String, [Photo])] = []
        let calendar = Calendar.current
        let sortedPhotos = person.photos.sorted { $0.dateTaken < $1.dateTaken }
        
        // Birth
        let birthPhotos = sortedPhotos.filter { calendar.isDate($0.dateTaken, inSameDayAs: person.dateOfBirth) }
        moments.append(("Birth", birthPhotos))
        
        // First 24 months
        for month in 1...24 {
            let startDate = calendar.date(byAdding: .month, value: month - 1, to: person.dateOfBirth)!
            let endDate = calendar.date(byAdding: .month, value: month, to: person.dateOfBirth)!
            let monthPhotos = sortedPhotos.filter { $0.dateTaken >= startDate && $0.dateTaken < endDate }
            let exactAge = AgeCalculator.calculate(for: person, at: startDate)
            moments.append((exactAge.toString(), monthPhotos))
        }
        
        // Years
        let currentDate = Date()
        let ageComponents = calendar.dateComponents([.year], from: person.dateOfBirth, to: currentDate)
        let age = ageComponents.year ?? 0
        
        for year in 3...max(age, 3) {
            let startDate = calendar.date(byAdding: .year, value: year - 1, to: person.dateOfBirth)!
            let endDate = calendar.date(byAdding: .year, value: year, to: person.dateOfBirth)!
            let yearPhotos = sortedPhotos.filter { $0.dateTaken >= startDate && $0.dateTaken < endDate }
            let exactAge = AgeCalculator.calculate(for: person, at: startDate)
            moments.append((exactAge.toString(), yearPhotos))
        }
        
        return moments
    }

    private func getDateRangeForSection(_ section: String) -> (start: Date, end: Date) {
        do {
            return try PhotoUtils.getDateRangeForSection(section, person: person)
        } catch {
            print("Error getting date range for section \(section): \(error)")
            // Return a default date range or handle the error as appropriate for your app
            return (Date(), Date())
        }
    }

    private var settingsButton: some View {
        Button(action: {
            activeSheet = .settings
        }) {
            Image(systemName: "gearshape.fill")
                .foregroundColor(.blue)
        }
    }

    @ViewBuilder
    private func sheetContent(_ item: ActiveSheet) -> some View {
        switch item {
        case .settings:
            NavigationView {
                PersonSettingsView(viewModel: viewModel, person: $person)
            }
        case .shareView:
            ShareSlideshowView(
                photos: person.photos,
                person: person,
                sectionTitle: "All Photos"
            )
        case .sharingComingSoon:
            SharingComingSoonView()
        case .customImagePicker(let moment, let dateRange):
            NavigationView {
                CustomImagePicker(
                    viewModel: viewModel,
                    person: $person,
                    sectionTitle: moment,
                    isPresented: Binding(
                        get: { self.activeSheet != nil },
                        set: { if !$0 { self.activeSheet = nil } }
                    ),
                    onPhotosAdded: { newPhotos in
                        // Handle newly added photos
                        viewModel.updatePerson(person)
                    }
                )
            }
        }
    }

    private func imagePickerContent() -> some View {
        CustomImagePicker(
            viewModel: viewModel,
            person: $person,
            sectionTitle: currentMoment,
            isPresented: $isImagePickerPresented,
            onPhotosAdded: { newPhotos in
                // Handle newly added photos
                viewModel.updatePerson(person)
            }
        )
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

struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView { UIVisualEffectView() }
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) { uiView.effect = effect }
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

// Custom PageViewController
struct PageViewController: UIViewControllerRepresentable {
    var pages: [AnyView]
    @Binding var currentPage: Int
    @Binding var animationDirection: UIPageViewController.NavigationDirection

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal)
        pageViewController.dataSource = context.coordinator
        pageViewController.delegate = context.coordinator
        return pageViewController
    }

    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
        pageViewController.setViewControllers(
            [context.coordinator.controllers[currentPage]], 
            direction: animationDirection,
            animated: true)
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PageViewController
        var controllers = [UIViewController]()

        init(_ pageViewController: PageViewController) {
            parent = pageViewController
            controllers = parent.pages.map { UIHostingController(rootView: $0) }
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController) else { return nil }
            if index == 0 {
                return nil // Return nil instead of the last controller
            }
            return controllers[index - 1]
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let index = controllers.firstIndex(of: viewController) else { return nil }
            if index + 1 == controllers.count {
                return nil // Return nil instead of the first controller
            }
            return controllers[index + 1]
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            if completed,
               let visibleViewController = pageViewController.viewControllers?.first,
               let index = controllers.firstIndex(of: visibleViewController) {
                parent.currentPage = index
            }
        }
    }
}
