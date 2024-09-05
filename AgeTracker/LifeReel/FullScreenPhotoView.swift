//
//  FullScreenPhotoView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/2/24.
//

import AVKit
import Foundation
import SwiftUI
import UIKit

struct FullScreenPhotoView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var photo: Photo
    @State var currentIndex: Int
    @Binding var photos: [Photo]
    var onDelete: (Photo) -> Void
    @Binding var person: Person
    @Environment(\.presentationMode) var presentationMode
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showControls = true
    @State private var scale: CGFloat = 1.0
    @State private var activeSheet: ActiveSheet?
    @State private var activityItems: [Any] = []
    @State private var isShareSheetPresented = false
    @State private var lastScale: CGFloat = 1.0
    @State private var minScale: CGFloat = 0.01
    @GestureState private var magnifyBy = CGFloat(1.0)
    @GestureState private var dragState = CGSize.zero
    @State private var isDragging = false
    @State private var showDeleteConfirmation = false
    @State private var dismissProgress: CGFloat = 0.0
    @State private var dragOffset: CGSize = .zero
    @State private var isDismissing = false
    @State private var showAgePicker = false
    @State private var selectedAge: ExactAge
    @State private var showDatePicker = false
    @State private var selectedDate: Date
    @State private var photosUpdateTrigger = UUID()

    enum ActiveSheet: Identifiable {
        case shareView
        case activityView

        var id: Int {
            hashValue
        }
    }

    private var filteredPhotos: [Photo] {
        return photos.filter { photo in
            if person.pregnancyTracking == .none {
                let age = AgeCalculator.calculate(for: person, at: photo.dateTaken)
                return !age.isPregnancy
            }
            return true
        }
    }

    init(
        viewModel: PersonViewModel,
        photo: Photo, currentIndex: Int, photos: Binding<[Photo]>,
        onDelete: @escaping (Photo) -> Void, person: Binding<Person>
    ) {
        self.viewModel = viewModel
        self._photo = Binding(get: { photo }, set: { _ in })
        self._photos = photos
        self.onDelete = onDelete
        self._person = person

        // Find the correct index in filteredPhotos
        let filteredPhotos = photos.wrappedValue.filter { p in
            if person.wrappedValue.pregnancyTracking == .none {
                let age = AgeCalculator.calculate(for: person.wrappedValue, at: p.dateTaken)
                return !age.isPregnancy
            }
            return true
        }
        self._currentIndex = State(
            initialValue: filteredPhotos.firstIndex(where: { $0.id == photo.id }) ?? 0)

        self._selectedAge = State(
            initialValue: AgeCalculator.calculate(for: person.wrappedValue, at: photo.dateTaken))
        self._selectedDate = State(initialValue: photo.dateTaken)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)

                if !filteredPhotos.isEmpty,
                    let currentPhoto = filteredPhotos.indices.contains(currentIndex)
                        ? filteredPhotos[currentIndex] : nil
                {
                    // Photo Display
                    GeometryReader { imageGeometry in
                        if let image = currentPhoto.image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(
                                    width: imageGeometry.size.width,
                                    height: imageGeometry.size.height
                                )
                                .scaleEffect(scale)
                                .offset(dragOffset)
                                .gesture(
                                    DragGesture()
                                        .updating($dragState) { value, state, _ in
                                            state = value.translation
                                        }
                                        .onChanged { value in
                                            if scale <= 1.0 {
                                                dragOffset = value.translation
                                                dismissProgress = min(
                                                    1, abs(value.translation.height) / 200)
                                            } else {
                                                let newOffset = CGSize(
                                                    width: offset.width + value.translation.width,
                                                    height: offset.height + value.translation.height
                                                )
                                                dragOffset = limitOffset(
                                                    newOffset, geometry: imageGeometry)
                                            }
                                        }
                                        .onEnded { value in
                                            if scale <= 1.0 {
                                                let threshold = geometry.size.height * 0.25
                                                if abs(value.translation.height) > threshold {
                                                    isDismissing = true
                                                    withAnimation(.easeOut(duration: 0.2)) {
                                                        dragOffset.height =
                                                            value.translation.height > 0
                                                            ? geometry.size.height
                                                            : -geometry.size.height
                                                        dismissProgress = 1
                                                    }
                                                    DispatchQueue.main.asyncAfter(
                                                        deadline: .now() + 0.2
                                                    ) {
                                                        presentationMode.wrappedValue.dismiss()
                                                    }
                                                } else {
                                                    withAnimation(.spring()) {
                                                        dragOffset = .zero
                                                        dismissProgress = 0
                                                    }
                                                }
                                            } else {
                                                offset = dragOffset
                                            }
                                        }
                                )
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let delta = value / self.lastScale
                                            self.lastScale = value

                                            // Adjust scale with new minimum
                                            let newScale = min(max(self.scale * delta, minScale), 4)

                                            // Adjust offset to keep the zoom centered
                                            let newOffset = CGSize(
                                                width: self.offset.width * delta,
                                                height: self.offset.height * delta
                                            )
                                            self.scale = newScale
                                            self.offset = limitOffset(
                                                newOffset, geometry: imageGeometry)
                                            self.dragOffset = self.offset
                                        }
                                        .onEnded { _ in
                                            self.lastScale = 1.0
                                            resetZoomIfNeeded()
                                        }
                                )
                                .onTapGesture(count: 2) {
                                    withAnimation(.spring()) {
                                        if scale > 1 {
                                            scale = 1
                                            offset = .zero
                                        } else {
                                            scale = min(scale * 2, 4)
                                        }
                                    }
                                }
                                .onTapGesture {
                                    showControls.toggle()
                                }
                        } else {
                            Text("No image available")
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    Text("No photos available")
                        .foregroundColor(.white)
                }

                // Controls Overlay
                if !filteredPhotos.isEmpty,
                    let currentPhoto = filteredPhotos.indices.contains(currentIndex)
                        ? filteredPhotos[currentIndex] : nil
                {
                    ControlsOverlay(
                        showControls: showControls,
                        person: person,
                        photo: currentPhoto,
                        photos: filteredPhotos,
                        onClose: {
                            presentationMode.wrappedValue.dismiss()
                        },
                        onShare: {
                            activeSheet = .shareView
                        },
                        onDelete: {
                            showDeleteConfirmation = true
                        },
                        currentIndex: $currentIndex,
                        totalPhotos: filteredPhotos.count,
                        onScrub: { newIndex in
                            currentIndex = newIndex
                            resetZoomAndPan()
                        },
                        onUpdateAge: updatePhotoAge,
                        onUpdateDate: updatePhotoDate
                    )
                    .opacity(1 - dismissProgress)
                }
            }
            .background(Color.black.opacity(1 - dismissProgress))
        }
        .id(photosUpdateTrigger)
        .onReceive(NotificationCenter.default.publisher(for: .photosUpdated)) { _ in
            photosUpdateTrigger = UUID()
            print("Photos updated notification received, triggering view refresh")
        }
        .onChange(of: photos) { oldValue, newValue in
            updateCurrentIndexAfterPhotoChange(oldPhotos: oldValue, newPhotos: newValue)
        }
        // Animation on Appear
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                scale = 1.0
            }
        }
        // Share Sheet Presentation
        .sheet(item: $activeSheet) { item in
            switch item {
            case .shareView:
                NavigationView {
                    SharePhotoView(
                        image: filteredPhotos[currentIndex].image ?? UIImage(),
                        name: person.name,
                        age: calculateAge(for: person, at: filteredPhotos[currentIndex].dateTaken),
                        isShareSheetPresented: $isShareSheetPresented,
                        activityItems: $activityItems
                    )
                }
            case .activityView:
                ActivityViewController(activityItems: activityItems)
                    .onDisappear {
                        self.activeSheet = nil
                    }
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Remove Photo"),
                message: Text("Are you sure you want to remove this photo?"),
                primaryButton: .destructive(Text("Remove")) {
                    viewModel.deletePhoto(filteredPhotos[currentIndex], from: $person)
                    if currentIndex > 0 {
                        currentIndex -= 1
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    // Helper Functions
    private func calculateAge(for person: Person, at date: Date) -> String {
        return AgeCalculator.calculate(for: person, at: date).toString()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func limitOffset(_ offset: CGSize, geometry: GeometryProxy) -> CGSize {
        guard let image = filteredPhotos[currentIndex].image else { return .zero }

        let imageSize = image.size
        let viewSize = geometry.size

        let widthRatio = viewSize.width / imageSize.width
        let heightRatio = viewSize.height / imageSize.height
        let aspectRatio = min(widthRatio, heightRatio)

        let scaledWidth = imageSize.width * aspectRatio * scale
        let scaledHeight = imageSize.height * aspectRatio * scale

        let horizontalLimit = max(0, (scaledWidth - viewSize.width) / 2)
        let verticalLimit = max(0, (scaledHeight - viewSize.height) / 2)

        return CGSize(
            width: min(max(offset.width, -horizontalLimit), horizontalLimit),
            height: min(max(offset.height, -verticalLimit), verticalLimit)
        )
    }

    private func goToPreviousPhoto() {
        withAnimation(.spring()) {
            if currentIndex > 0 {
                currentIndex -= 1
            }
        }
    }

    private func goToNextPhoto() {
        withAnimation(.spring()) {
            if currentIndex < filteredPhotos.count - 1 {
                currentIndex += 1
            }
        }
    }

    private func resetZoomAndPan() {
        scale = 1.0
        offset = .zero
        dragOffset = .zero
    }

    private func resetZoomIfNeeded() {
        if scale < 1 {
            withAnimation(.spring()) {
                scale = 1
                offset = .zero
                dragOffset = .zero
            }
        }
    }

    private func updatePhotoAge(_ newAge: ExactAge) {
        let calendar = Calendar.current
        let newDate = calendar.date(byAdding: .year, value: newAge.years, to: person.dateOfBirth)!
        let newDate2 = calendar.date(byAdding: .month, value: newAge.months, to: newDate)!
        let finalDate = calendar.date(byAdding: .day, value: newAge.days, to: newDate2)!
        updatePhotoDate(finalDate)
    }

    private func updatePhotoDate(_ newDate: Date) {
        let updatedPerson = viewModel.updatePhotoDate(
            person: person, photo: filteredPhotos[currentIndex], newDate: newDate)
        person = updatedPerson
        photos = person.photos  // Update the photos array to reflect the new order
        if let newIndex = photos.firstIndex(where: { $0.id == filteredPhotos[currentIndex].id }) {
            currentIndex = newIndex
        }
        print(
            "Photo date updated. New photos count: \(photos.count), Current index: \(currentIndex)")
    }

    private func updateCurrentIndexAfterPhotoChange(oldPhotos: [Photo], newPhotos: [Photo]) {
        let oldFilteredPhotos = oldPhotos.filter { photo in
            if person.pregnancyTracking == .none {
                let age = AgeCalculator.calculate(for: person, at: photo.dateTaken)
                return !age.isPregnancy
            }
            return true
        }

        let newFilteredPhotos = newPhotos.filter { photo in
            if person.pregnancyTracking == .none {
                let age = AgeCalculator.calculate(for: person, at: photo.dateTaken)
                return !age.isPregnancy
            }
            return true
        }

        if currentIndex >= newFilteredPhotos.count {
            currentIndex = newFilteredPhotos.count - 1
        } else if currentIndex < oldFilteredPhotos.count {
            let currentPhotoId = oldFilteredPhotos[currentIndex].id
            if let newIndex = newFilteredPhotos.firstIndex(where: { $0.id == currentPhotoId }) {
                currentIndex = newIndex
            }
        }
    }
}

private struct ControlsOverlay: View {
    let showControls: Bool
    let person: Person
    let photo: Photo
    let photos: [Photo]
    let onClose: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void
    @Binding var currentIndex: Int
    let totalPhotos: Int
    let onScrub: (Int) -> Void
    let onUpdateAge: (ExactAge) -> Void
    let onUpdateDate: (Date) -> Void
    @State private var showAgePicker = false
    @State private var showDatePicker = false
    @State private var selectedAge: ExactAge
    @State private var selectedDate: Date

    init(
        showControls: Bool, person: Person, photo: Photo, photos: [Photo],
        onClose: @escaping () -> Void, onShare: @escaping () -> Void,
        onDelete: @escaping () -> Void, currentIndex: Binding<Int>, totalPhotos: Int,
        onScrub: @escaping (Int) -> Void, onUpdateAge: @escaping (ExactAge) -> Void,
        onUpdateDate: @escaping (Date) -> Void
    ) {
        self.showControls = showControls
        self.person = person
        self.photo = photo
        self.photos = photos
        self.onClose = onClose
        self.onShare = onShare
        self.onDelete = onDelete
        self._currentIndex = currentIndex
        self.totalPhotos = totalPhotos
        self.onScrub = onScrub
        self.onUpdateAge = onUpdateAge
        self.onUpdateDate = onUpdateDate
        self._selectedAge = State(
            initialValue: AgeCalculator.calculate(for: person, at: photo.dateTaken))
        self._selectedDate = State(initialValue: photo.dateTaken)
    }

    var body: some View {
        VStack {
            // Top Bar with Close Button
            HStack {
                CircularButton(
                    systemName: "xmark",
                    action: onClose,
                    size: 40,
                    blurEffect: true
                )
                Spacer()
            }
            .padding(.horizontal)

            Spacer()

            // Bottom Bar with Share, Age, Options, and Scrubber
            VStack(spacing: 16) {
                // Only show scrubber if there are at least 2 photos
                if photos.count >= 2 {
                    // Scrubber with side fade-out effect
                    ThumbnailScrubber(
                        photos: photos,
                        currentIndex: $currentIndex,
                        onScrub: onScrub
                    )
                    .frame(height: 60)
                    .mask(
                        HStack(spacing: 0) {
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, .white]), startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 40)
                            Rectangle().fill(Color.white)
                            LinearGradient(
                                gradient: Gradient(colors: [.white, .clear]), startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 40)
                        }
                    )
                }

                HStack {
                    CircularButton(
                        systemName: "square.and.arrow.up",
                        action: onShare,
                        size: 40,
                        blurEffect: true
                    )
                    Spacer()
                    VStack(spacing: 4) {
                        Text(selectedAge.toString())
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .onTapGesture {
                                showAgePicker = true
                            }
                        Text(formatDate(selectedDate))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .onTapGesture {
                                showDatePicker = true
                            }
                    }
                    Spacer()
                    Menu {
                        Button {
                            showDatePicker = true
                        } label: {
                            Label("Edit Date", systemImage: "calendar")
                        }

                        Button {
                            showAgePicker = true
                        } label: {
                            Label("Edit Age", systemImage: "person.crop.circle")
                        }

                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Remove Photo", systemImage: "trash")
                        }
                    } label: {
                        CircularButton(
                            systemName: "ellipsis",
                            action: {},
                            size: 40,
                            blurEffect: true
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .opacity(showControls ? 1 : 0)
        .animation(.easeInOut, value: showControls)
        .sheet(isPresented: $showAgePicker) {
            AgePickerSheet(age: selectedAge, isPresented: $showAgePicker) { newAge in
                selectedAge = newAge
                onUpdateAge(newAge)
            }
            .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(date: $selectedDate, isPresented: $showDatePicker) { newDate in
                onUpdateDate(newDate)
            }
            .presentationDetents([.height(300)])
        }
        .onChange(of: currentIndex) { _, newIndex in
            updateSelectedAgeAndDate(for: newIndex)
        }
    }

    private func updateSelectedAgeAndDate(for index: Int) {
        let photo = photos[index]
        selectedAge = AgeCalculator.calculate(for: person, at: photo.dateTaken)
        selectedDate = photo.dateTaken
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct ThumbnailScrubber: View {
    let photos: [Photo]
    @Binding var currentIndex: Int
    let onScrub: (Int) -> Void

    private let thumbnailSize: CGFloat = 50
    private let spacing: CGFloat = 4

    @State private var scrollOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var viewWidth: CGFloat = 0
    @State private var initialDragOffset: CGFloat = 0
    @State private var lastFeedbackIndex: Int = -1

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: spacing) {
                        ForEach(photos.indices, id: \.self) { index in
                            ThumbnailView(photo: photos[index], isSelected: index == currentIndex)
                                .frame(width: thumbnailSize, height: thumbnailSize)
                                .id(index)
                                .onTapGesture {
                                    currentIndex = index
                                    onScrub(index)
                                    scrollToCurrentIndex(proxy: scrollProxy)
                                    generateHapticFeedback()
                                }
                        }
                    }
                    .padding(.horizontal, geometry.size.width / 2 - thumbnailSize / 2)
                }
                .content.offset(x: scrollOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                initialDragOffset = calculateCurrentOffset(geometry: geometry)
                                generateHapticFeedback()
                            }
                            let newOffset = initialDragOffset + value.translation.width
                            scrollOffset = newOffset
                            updateCurrentIndex(currentOffset: newOffset, geometry: geometry)
                            onScrub(currentIndex)
                        }
                        .onEnded { value in
                            isDragging = false
                            let velocity = value.predictedEndLocation.x - value.location.x
                            let itemWidth = thumbnailSize + spacing
                            let additionalScroll = velocity / 3
                            let targetOffset = scrollOffset + additionalScroll
                            let targetIndex = round(-targetOffset / itemWidth)
                            let finalIndex = max(0, min(Int(targetIndex), photos.count - 1))

                            currentIndex = finalIndex
                            scrollToCurrentIndex(proxy: scrollProxy)
                        }
                )
                .onAppear {
                    viewWidth = geometry.size.width
                    scrollToCurrentIndex(proxy: scrollProxy)
                }
                .onChange(of: currentIndex) { oldValue, newValue in
                    if !isDragging {
                        scrollToCurrentIndex(proxy: scrollProxy)
                    }
                }
            }
        }
        .frame(height: thumbnailSize + 10)
    }

    private func calculateCurrentOffset(geometry: GeometryProxy) -> CGFloat {
        let itemWidth = thumbnailSize + spacing
        return -CGFloat(currentIndex) * itemWidth
    }

    private func updateCurrentIndex(currentOffset: CGFloat, geometry: GeometryProxy) {
        let itemWidth = thumbnailSize + spacing
        let estimatedIndex = round(-currentOffset / itemWidth)
        let newIndex = max(0, min(Int(estimatedIndex), photos.count - 1))
        if newIndex != currentIndex {
            currentIndex = newIndex
            onScrub(newIndex)
            generateHapticFeedback()
        }
    }

    private func scrollToCurrentIndex(proxy: ScrollViewProxy) {
        let itemWidth = thumbnailSize + spacing
        scrollOffset = -CGFloat(currentIndex) * itemWidth
        proxy.scrollTo(currentIndex, anchor: .center)
    }

    private func generateHapticFeedback() {
        if currentIndex != lastFeedbackIndex {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            lastFeedbackIndex = currentIndex
        }
    }
}

struct ThumbnailView: View {
    let photo: Photo
    let isSelected: Bool

    var body: some View {
        ZStack {
            if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Color.gray
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
        )
    }
}

enum DragState {
    case inactive
    case dragging(translation: CGSize)

    var translation: CGSize {
        switch self {
        case .inactive:
            return .zero
        case .dragging(let translation):
            return translation
        }
    }
}
