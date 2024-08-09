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
    @State private var isShowingShareSheet = false
    
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
                GridView(geometry: geometry)
            }
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(
                leading: CustomBackButton(),
                trailing: shareButton
            )
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(person.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(sectionTitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear {
                updateGridColumns(width: geometry.size.width)
                loadAllThumbnails()
            }
            .onChange(of: geometry.size) { _, newSize in
                updateGridColumns(width: newSize.width)
            }
            .sheet(isPresented: $isShowingShareSheet) {
                ShareSlideshowView(photos: photos, person: person)
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
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 2)
            } else {
                ProgressView()
                    .frame(width: 110, height: 110)
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
    
    private var shareButton: some View {
        Button(action: {
            isShowingShareSheet = true
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

struct IdentifiableIndex: Identifiable {
    let id = UUID()
    let index: Int
}