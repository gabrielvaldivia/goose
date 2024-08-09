//
//  AllPhotosInSelectionView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/2/24.
//

import Foundation
import SwiftUI
import PhotosUI

struct AllPhotosInSectionView: View {
    let sectionTitle: String
    let photos: [Photo]
    var onDelete: (Photo) -> Void
    @State private var selectedPhotoIndex: IdentifiableIndex?
    let person: Person
    
    @State private var columns = [GridItem]()
    @State private var thumbnails: [String: UIImage] = [:]
    @State private var visibleRange: Range<Int>?
    @State private var isLoading = true
    @State private var selectedView = 0 // 0 for Grid, 1 for Slideshow
    
    @State private var currentPhotoIndex: Int = 0
    @State private var isPlaying = false
    @State private var playTimer: Timer?
    @State private var playbackSpeed: Double = 1.0
    @State private var scrubberPosition: Double = 0
    @State private var isManualInteraction = true
    @State private var lastUpdateTime: Date = Date()
    
    @State private var activeSheet: ActiveSheet?
    @State private var isShareSheetPresented = false
    @State private var activityItems: [Any] = []

    var body: some View {
        GeometryReader { geometry in
            VStack {
                // Segmented control for view selection
                Picker("View", selection: $selectedView) {
                    Text("Grid").tag(0)
                    Text("Slideshow").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                if selectedView == 0 {
                    GridView(geometry: geometry)
                } else {
                    SlideshowView(geometry: geometry)
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: CustomBackButton())
            .navigationTitle(sectionTitle)
            .onAppear {
                updateGridColumns(width: geometry.size.width)
                loadAllThumbnails()
            }
            .onChange(of: geometry.size) { _, newSize in
                updateGridColumns(width: newSize.width)
            }
        }
        .fullScreenCover(item: $selectedPhotoIndex) { identifiableIndex in
            FullScreenPhotoView(
                photo: photos[identifiableIndex.index],
                currentIndex: identifiableIndex.index,
                photos: photos,
                onDelete: onDelete,
                person: person
            )
        }
        .onChange(of: visibleRange) { _, _ in
            loadVisibleThumbnails()
        }
        .onDisappear {
            stopPlayback()
        }
        .sheet(item: $activeSheet) { item in
            switch item {
            case .shareView:
                NavigationView {
                    SharePhotoView(
                        image: photos[currentPhotoIndex].image ?? UIImage(),
                        name: person.name,
                        age: calculateAge(for: person, at: photos[currentPhotoIndex].dateTaken),
                        isShareSheetPresented: $isShareSheetPresented,
                        activityItems: $activityItems
                    )
                }
            @unknown default:
                EmptyView()
            }
        }
    }
    
    private func updateGridColumns(width: CGFloat) {
        let minItemWidth: CGFloat = 110
        let spacing: CGFloat = 10
        let numberOfColumns = max(1, Int(width / (minItemWidth + spacing)))
        columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: numberOfColumns)
    }
    
    private func photoThumbnail(_ photo: Photo) -> some View {
        Group {
            if let thumbnailImage = thumbnails[photo.assetIdentifier] {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: selectedView == 0 ? .fill : .fit)
                    .frame(width: selectedView == 0 ? 110 : nil, height: selectedView == 0 ? 110 : nil)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 2)
            } else {
                ProgressView()
                    .frame(width: selectedView == 0 ? 110 : nil, height: selectedView == 0 ? 110 : nil)
            }
        }
        .onTapGesture {
            if let index = photos.firstIndex(where: { $0.id == photo.id }) {
                selectedPhotoIndex = IdentifiableIndex(index: index)
            }
        }
    }
    
    private func updateVisibleRange(index: Int) {
        let bufferSize = 10 // Load 10 items before and after visible range
        let lowerBound = max(0, index - bufferSize)
        let upperBound = min(photos.count, index + bufferSize + 1)
        visibleRange = lowerBound..<upperBound
    }

    private func loadVisibleThumbnails() {
        guard let range = visibleRange else { return }
        for index in range {
            let photo = photos[index]
            loadThumbnail(for: photo)
        }
    }

    private func loadAllThumbnails() {
        for photo in photos {
            loadThumbnail(for: photo)
        }
    }

    private func loadThumbnail(for photo: Photo) {
        guard thumbnails[photo.assetIdentifier] == nil else { return }
        
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        option.deliveryMode = .opportunistic
        option.resizeMode = .exact
        option.isNetworkAccessAllowed = true
        option.version = .current
        
        let targetSize = CGSize(width: 220, height: 220) // Increased size for better quality
        
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [photo.assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else { return }
        
        manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: option
        ) { result, _ in
            if let image = result {
                DispatchQueue.main.async {
                    self.thumbnails[photo.assetIdentifier] = image
                    if self.thumbnails.count == self.photos.count {
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    private func GridView(geometry: GeometryProxy) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    photoThumbnail(photo)
                        .id(index)
                        .onAppear {
                            updateVisibleRange(index: index)
                        }
                        .onDisappear {
                            updateVisibleRange(index: index)
                        }
                }
            }
            .padding()
        }
    }
    
    private func SlideshowView(geometry: GeometryProxy) -> some View {
        let reversedPhotos = Array(photos.reversed())
        
        return VStack(spacing: 0) {
            TabView(selection: $currentPhotoIndex) {
                ForEach(Array(reversedPhotos.enumerated()), id: \.element.id) { index, photo in
                    PhotoView(photo: photo, containerWidth: geometry.size.width, selectedPhotoIndex: $selectedPhotoIndex, photos: photos)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: geometry.size.height * 0.7)
            .gesture(DragGesture().onChanged { _ in
                isManualInteraction = true
            })
            .onChange(of: currentPhotoIndex) { oldValue, newValue in
                if isManualInteraction {
                    scrubberPosition = Double(newValue)
                }
            }
            
            VStack(spacing: 4) {
                Text(calculateAge(for: person, at: reversedPhotos[currentPhotoIndex].dateTaken))
                    .font(.body)
                    .foregroundColor(.primary)
                Text(formatDate(reversedPhotos[currentPhotoIndex].dateTaken))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.top, 10)
            
            Spacer()
            
            if photos.count > 1 {
                HStack {
                    playButton
                    
                    Slider(value: Binding(
                        get: { scrubberPosition },
                        set: { 
                            isManualInteraction = true
                            scrubberPosition = $0
                            currentPhotoIndex = Int($0)
                        }
                    ), in: 0...Double(photos.count - 1), step: 0.01)
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
        }
        .onAppear {
            currentPhotoIndex = 0
            scrubberPosition = Double(currentPhotoIndex)
        }
    }
    
    private var playButton: some View {
        Button(action: {
            if currentPhotoIndex == photos.count - 1 {
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
                
                Image(systemName: currentPhotoIndex == photos.count - 1 ? "arrow.counterclockwise" : (isPlaying ? "pause.fill" : "play.fill"))
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .bold))
            }
        }
    }
    
    private var speedControlButton: some View {
        Button(action: {
            playbackSpeed = playbackSpeed >= 3 ? 1 : playbackSpeed + 1
            if isPlaying {
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
    
    private func startPlayback() {
        isManualInteraction = false
        lastUpdateTime = Date()
        playTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { timer in
            let currentTime = Date()
            let elapsedTime = currentTime.timeIntervalSince(lastUpdateTime)
            lastUpdateTime = currentTime

            scrubberPosition += elapsedTime * playbackSpeed / 2.0
            
            if scrubberPosition >= Double(photos.count - 1) {
                stopPlayback()
                scrubberPosition = Double(photos.count - 1)
            }

            currentPhotoIndex = Int(scrubberPosition)
        }
    }
    
    private func stopPlayback() {
        isPlaying = false
        playTimer?.invalidate()
        playTimer = nil
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func calculateAge(for person: Person, at date: Date) -> String {
        return AgeCalculator.calculateAgeString(for: person, at: date)
    }
}

private struct PhotoView: View {
    let photo: Photo
    let containerWidth: CGFloat
    @Binding var selectedPhotoIndex: IdentifiableIndex?
    let photos: [Photo]
    
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
            if let index = photos.firstIndex(where: { $0.id == photo.id }) {
                selectedPhotoIndex = IdentifiableIndex(index: index)
            }
        }
    }
}

struct IdentifiableIndex: Identifiable {
    let id = UUID()
    let index: Int
}