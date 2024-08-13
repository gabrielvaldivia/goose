//
//  FullScreenPhotoView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/2/24.
//

import Foundation
import SwiftUI
import AVKit
import UIKit

struct FullScreenPhotoView: View {
    let photo: Photo
    @State var currentIndex: Int
    let photos: [Photo]
    var onDelete: (Photo) -> Void
    let person: Person
    @Environment(\.presentationMode) var presentationMode
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showControls = true
    @State private var scale: CGFloat = 1.0
    @State private var activeSheet: ActiveSheet?
    @State private var activityItems: [Any] = []
    @State private var isShareSheetPresented = false
    @State private var lastScale: CGFloat = 1.0
    @GestureState private var magnifyBy = CGFloat(1.0)
    @GestureState private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showDeleteConfirmation = false
    @State private var dismissProgress: CGFloat = 0.0
    @State private var showActionSheet = false

    enum ActiveSheet: Identifiable {
        case shareView
        case activityView
        
        var id: Int {
            hashValue
        }
    }
    
    var body: some View {
        // Main View Layout
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .edgesIgnoringSafeArea(.all)
                    
                    .opacity(1 - dismissProgress)
                
                // Photo Display
                if let image = photos[currentIndex].image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .offset(calculateImageOffset(geometry: geometry))
                        .scaleEffect(scale * magnifyBy)
                        .offset(x: isDragging ? dragOffset.width : 0)
                        .gesture(dragGesture(geometry: geometry))
                        .gesture(magnificationGesture())
                        .gesture(
                            DragGesture()
                                .updating($dragOffset) { value, state, _ in
                                    if scale <= 1.0 {
                                        state = value.translation
                                    }
                                }
                                .onChanged { _ in
                                    if scale <= 1.0 {
                                        isDragging = true
                                    }
                                }
                                .onEnded { value in
                                    if scale <= 1.0 {
                                        let threshold: CGFloat = 50
                                        if value.translation.width > threshold {
                                            goToPreviousPhoto()
                                        } else if value.translation.width < -threshold {
                                            goToNextPhoto()
                                        }
                                        isDragging = false
                                    }
                                }
                        )
                        .gesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    showActionSheet = true
                                }
                        )
                        .onTapGesture {
                            showControls.toggle()
                        }
                } else {
                    Color.gray
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                
                // Controls Overlay
                ControlsOverlay(
                    showControls: showControls,
                    person: person,
                    photo: photos[currentIndex],
                    photos: photos,
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
                    totalPhotos: photos.count,
                    onScrub: { newIndex in
                        currentIndex = newIndex
                    }
                )
                .opacity(1 - dismissProgress)
            }
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
                        image: photos[currentIndex].image ?? UIImage(),
                        name: person.name,
                        age: calculateAge(for: person, at: photos[currentIndex].dateTaken),
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
                title: Text("Delete Photo"),
                message: Text("Are you sure you want to delete this photo?"),
                primaryButton: .destructive(Text("Delete")) {
                    onDelete(photos[currentIndex])
                    if currentIndex > 0 {
                        currentIndex -= 1
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(
                title: Text("Photo Options"),
                buttons: [
                    .destructive(Text("Delete Photo")) {
                        showDeleteConfirmation = true
                    },
                    .cancel()
                ]
            )
        }
    }
    
    // Helper Functions
    private func calculateAge(for person: Person, at date: Date) -> String {
        if date < person.dateOfBirth {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day], from: date, to: person.dateOfBirth)
            let daysUntilBirth = components.day ?? 0
            let weeksPregnant = 40 - (daysUntilBirth / 7)
            return "\(weeksPregnant) week\(weeksPregnant == 1 ? "" : "s") pregnant"
        }
        return AgeCalculator.calculateAgeString(for: person, at: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func calculateImageOffset(geometry: GeometryProxy) -> CGSize {
        let imageSize = CGSize(
            width: geometry.size.width * scale,
            height: geometry.size.height * scale
        )
        let excessWidth = max(0, imageSize.width - geometry.size.width)
        let excessHeight = max(0, imageSize.height - geometry.size.height)

        let newOffsetX = min(max(offset.width + dragOffset.width, -excessWidth / 2), excessWidth / 2)
        let newOffsetY = min(max(offset.height + dragOffset.height, -excessHeight / 2), excessHeight / 2)
        
        return CGSize(width: newOffsetX, height: newOffsetY)
    }

    private func dragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                if scale > 1.0 {
                    state = CGSize(
                        width: value.translation.width / scale,
                        height: value.translation.height / scale
                    )
                }
                // Update dismissProgress based on drag
                dismissProgress = min(abs(value.translation.height) / 200, 1.0)
            }
            .onEnded { value in
                if abs(value.translation.height) > 100 && scale <= 1.0 {
                    presentationMode.wrappedValue.dismiss()
                } else if scale > 1.0 {
                    let imageSize = CGSize(
                        width: geometry.size.width * scale,
                        height: geometry.size.height * scale
                    )
                    let excessWidth = max(0, imageSize.width - geometry.size.width)
                    let excessHeight = max(0, imageSize.height - geometry.size.height)

                    let scaledTranslation = CGSize(
                        width: value.translation.width / scale,
                        height: value.translation.height / scale
                    )

                    offset.width = min(max(offset.width + scaledTranslation.width, -excessWidth / 2), excessWidth / 2)
                    offset.height = min(max(offset.height + scaledTranslation.height, -excessHeight / 2), excessHeight / 2)
                }
                showControls = true
                // Reset dismissProgress if not dismissing
                withAnimation(.easeOut(duration: 0.2)) {
                    dismissProgress = 0.0
                }
            }
    }

    private func magnificationGesture() -> some Gesture {
        MagnificationGesture()
            .updating($magnifyBy) { currentState, gestureState, _ in
                gestureState = currentState
            }
            .onEnded { value in
                scale = min(max(scale * value, 1), 4)
                lastScale = scale
            }
    }

    private func goToPreviousPhoto() {
        if currentIndex > 0 {
            withAnimation(.spring()) {
                currentIndex -= 1
            }
        }
    }

    private func goToNextPhoto() {
        if currentIndex < photos.count - 1 {
            withAnimation(.spring()) {
                currentIndex += 1
            }
        }
    }
}

struct ControlsOverlay: View {
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
    
    var body: some View {
        VStack {
            // Top Bar with Close Button
            HStack {
                CircularIconButton(icon: "xmark", action: onClose)
                Spacer()
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Bottom Bar with Share, Age, Delete, and Scrubber
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
                            LinearGradient(gradient: Gradient(colors: [.clear, .white]), startPoint: .leading, endPoint: .trailing)
                                .frame(width: 40)
                            Rectangle().fill(Color.white)
                            LinearGradient(gradient: Gradient(colors: [.white, .clear]), startPoint: .leading, endPoint: .trailing)
                                .frame(width: 40)
                        }
                    )
                }
                
                HStack {
                    CircularIconButton(icon: "square.and.arrow.up", action: onShare)
                    Spacer()
                    VStack(spacing: 4) {
                        Text(calculateAge(for: person, at: photo.dateTaken))
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        Text(formatDate(photo.dateTaken))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    CircularIconButton(icon: "trash", action: onDelete)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .opacity(showControls ? 1 : 0)
        .animation(.easeInOut, value: showControls)
    }
    
    // Helper functions
    private func calculateAge(for person: Person, at date: Date) -> String {
        return AgeCalculator.calculateAgeString(for: person, at: date)
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
                            }
                            let newOffset = initialDragOffset + value.translation.width
                            scrollOffset = newOffset
                            updateCurrentIndex(currentOffset: newOffset, geometry: geometry)
                        }
                        .onEnded { value in
                            isDragging = false
                            let velocity = value.predictedEndLocation.x - value.location.x
                            let itemWidth = thumbnailSize + spacing
                            let additionalScroll = velocity / 3 // Adjust this factor to control momentum
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
        }
    }
    
    private func scrollToCurrentIndex(proxy: ScrollViewProxy) {
        let itemWidth = thumbnailSize + spacing
        scrollOffset = -CGFloat(currentIndex) * itemWidth
        proxy.scrollTo(currentIndex, anchor: .center)
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

struct CircularIconButton: View {
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold)) 
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
        }
        .background(
            BlurEffectView()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
        )
        .padding(8)
    }
    
    private struct BlurEffectView: UIViewRepresentable {
        func makeUIView(context: Context) -> UIVisualEffectView {
            return UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        }

        func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
    }
}

struct PillButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

        }
        .background(
            BlurEffectView()
                .clipShape(Capsule())
                .padding(.horizontal, -8)
                .padding(.vertical, -4)
        )
    }
    
    private struct BlurEffectView: UIViewRepresentable {
        func makeUIView(context: Context) -> UIVisualEffectView {
            return UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        }

        func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
    }
}