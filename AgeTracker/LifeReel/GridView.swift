//
//  GridView.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 9/4/24.
//

import Foundation
import Photos
import SwiftUI
import UIKit

struct GridView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    @Binding var selectedPhoto: Photo?
    let sectionTitle: String?
    let forceUpdate: Bool
    let showAge: Bool
    let showMilestoneScroll: Bool

    @State private var orientation = UIDeviceOrientation.unknown
    @State private var showingImagePicker = false  // Add this line
    @State private var showingSlideshowSheet = false
    @State private var selectedMilestone: String?

    // Add image cache
    @State private var imageCache: [String: UIImage] = [:]

    private var filteredPhotos: [Photo] {
        guard let sectionTitle = sectionTitle else {
            return person.photos
        }

        let filteredPhotos = person.photos.filter { photo in
            let photoSection = PhotoUtils.sectionForPhoto(photo, person: person)
            let shouldInclude = photoSection == sectionTitle

            if person.pregnancyTracking == .none {
                let age = AgeCalculator.calculate(for: person, at: photo.dateTaken)
                return shouldInclude && !age.isPregnancy
            }
            return shouldInclude
        }

        return filteredPhotos
    }

    private func placeholderImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // Ensure background matches the "Add Photos" tile
            UIColor.secondarySystemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Draw photo icon with bolder weight
            let iconSize: CGFloat = min(size.width, size.height) * 0.3
            let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold)  // Bolder icon
            if let icon = UIImage(systemName: "photo", withConfiguration: config)?.withTintColor(
                .systemGray3, renderingMode: .alwaysOriginal)
            {
                let iconAspectRatio = icon.size.width / icon.size.height
                let iconWidth = iconSize
                let iconHeight = iconWidth / iconAspectRatio

                let iconRect = CGRect(
                    x: (size.width - iconWidth) / 2,
                    y: (size.height - iconHeight) / 2,
                    width: iconWidth,
                    height: iconHeight
                )
                icon.draw(in: iconRect)
            }
        }
    }

    private func loadImage(for photo: Photo) -> UIImage {
        // Check cache first
        if let cachedImage = imageCache[photo.id.uuidString] {
            return cachedImage
        }

        // If we already have the image loaded, cache and return it
        if let existingImage = photo.image {
            imageCache[photo.id.uuidString] = existingImage
            return existingImage
        }

        // Set up options to avoid iCloud download and main thread issues
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true  // Allow network access for full screen view
        options.isSynchronous = false  // Async loading
        options.deliveryMode = .opportunistic  // Start with fast image, then load better quality
        options.version = .current

        // Create placeholder with same size as target image
        let size = CGSize(width: 300, height: 300)
        let placeholder = placeholderImage(size: size)

        // Load image using asset identifier
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [photo.assetIdentifier], options: nil)
        if let asset = fetchResult.firstObject {
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                if let loadedImage = image {
                    // Check if this is the final image (not a temporary one)
                    let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                    if !isDegraded {
                        DispatchQueue.main.async {
                            self.imageCache[photo.id.uuidString] = loadedImage
                        }
                    }
                }
            }
        }

        return imageCache[photo.id.uuidString] ?? placeholder
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Show milestone scroll only when requested
                    if showMilestoneScroll {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(getMilestones(for: person), id: \.0) { milestone, photos in
                                    Button(action: {
                                        selectedPhoto = nil
                                        selectedMilestone = milestone
                                        showingSlideshowSheet = true
                                    }) {
                                        MilestoneTile(
                                            milestone: milestone,
                                            photos: photos,
                                            person: person,
                                            width: UIScreen.main.bounds.width * 0.35,
                                            isEmpty: photos.isEmpty
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                        }
                        .background(Color(.systemBackground))

                        // Add the "All photos" title here
                        Text("All photos")
                            .font(.headline)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, 20)
                            .padding(.bottom, 10)
                    }

                    // Existing grid content
                    if filteredPhotos.isEmpty {
                        EmptyStateView(
                            title: "No photos in \(sectionTitle ?? "this section")",
                            subtitle: "Add photos to create memories",
                            systemImageName: "photo.on.rectangle.angled",
                            action: {
                                showingImagePicker = true
                            }
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    } else {
                        LazyVGrid(
                            columns: GridLayoutHelper.gridItems(for: geometry.size), spacing: 2
                        ) {
                            ForEach(
                                filteredPhotos.sorted(by: { $0.dateTaken > $1.dateTaken }), id: \.id
                            ) { photo in
                                let itemWidth = max(
                                    1, GridLayoutHelper.gridItemWidth(for: geometry.size))
                                PhotoThumbnail(
                                    photo: photo,
                                    width: itemWidth,
                                    loadImage: loadImage,
                                    onTap: {
                                        selectedPhoto = photo
                                    }
                                )
                            }

                            // Add Photos tile
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.secondarySystemBackground))
                                    Image(systemName: "plus")
                                        .font(.system(size: 30))
                                        .foregroundColor(.secondary)
                                }
                                .frame(
                                    width: max(
                                        1, GridLayoutHelper.gridItemWidth(for: geometry.size)),
                                    height: max(
                                        1, GridLayoutHelper.gridItemWidth(for: geometry.size)))
                            }
                        }
                        .padding(.bottom, 80)
                    }
                }
            }
        }
        .onChange(of: UIDevice.current.orientation) { oldValue, newValue in
            orientation = newValue
        }
        .id(orientation)
        .id(forceUpdate)
        .sheet(isPresented: $showingImagePicker) {
            CustomImagePicker(
                viewModel: viewModel,
                person: $person,
                sectionTitle: sectionTitle ?? "All Photos",
                isPresented: $showingImagePicker,
                onPhotosAdded: { newPhotos in
                    // Handle newly added photos if needed
                }
            )
        }
        .sheet(isPresented: $showingSlideshowSheet) {
            if let milestone = selectedMilestone {
                let milestonePhotos = person.photos.filter { photo in
                    let photoSection = PhotoUtils.sectionForPhoto(photo, person: person)
                    let shouldInclude = photoSection == milestone
                    
                    if person.pregnancyTracking == .none {
                        let age = AgeCalculator.calculate(for: person, at: photo.dateTaken)
                        return shouldInclude && !age.isPregnancy
                    }
                    return shouldInclude
                }
                
                ShareSlideshowView(
                    photos: milestonePhotos,
                    person: person,
                    sectionTitle: milestone,
                    forceAllPhotos: true
                )
            }
        }
    }

    // Add the getMilestones function to GridView
    private func getMilestones(for person: Person) -> [(String, [Photo])] {
        let allMilestones = PhotoUtils.getAllMilestones(for: person)
        let groupedPhotos = Dictionary(grouping: person.photos) { photo in
            PhotoUtils.sectionForPhoto(photo, person: person)
        }

        return allMilestones.reversed().compactMap { milestone in
            let photos = groupedPhotos[milestone] ?? []
            if person.pregnancyTracking == .none {
                let isPregnancyMilestone =
                    milestone.lowercased().contains("pregnancy")
                    || milestone.lowercased().contains("trimester")
                    || milestone.lowercased().contains("week")
                if isPregnancyMilestone {
                    return nil
                }
            }

            if !photos.isEmpty || person.showEmptyStacks {
                return (milestone, photos)
            }
            return nil
        }
    }
}

struct GridLayoutHelper {
    static func gridItems(for size: CGSize) -> [GridItem] {
        let isLandscape = size.width > size.height
        let columnCount = isLandscape ? 6 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 2), count: columnCount)
    }

    static func gridItemWidth(for size: CGSize) -> CGFloat {
        let isLandscape = size.width > size.height
        let columnCount = CGFloat(isLandscape ? 6 : 3)
        let totalSpacing = CGFloat(2 * (Int(columnCount) - 1))
        return (size.width - totalSpacing) / columnCount
    }
}

// Photo Thumbnail View
struct PhotoThumbnail: View {
    let photo: Photo
    let width: CGFloat
    let loadImage: (Photo) -> UIImage
    let onTap: () -> Void

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color(.secondarySystemBackground)
                ProgressView()
            }
        }
        .frame(width: width, height: width)
        .clipped()
        .onAppear {
            // Load image asynchronously
            DispatchQueue.global(qos: .userInitiated).async {
                let loadedImage = loadImage(photo)
                DispatchQueue.main.async {
                    self.image = loadedImage
                }

            }
        }
        .onTapGesture(perform: onTap)
    }
}
