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
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        photoThumbnail(photo)
                            .onAppear {
                                loadThumbnail(for: photo)
                            }
                            .onTapGesture {
                                selectedPhotoIndex = IdentifiableIndex(index: index)
                            }
                    }
                }
                .padding()
            }
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: CustomBackButton())
            .navigationTitle(sectionTitle)
            .onAppear {
                updateGridColumns(width: geometry.size.width)
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
                Color.gray
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
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
                }
            }
        }
    }
}

struct IdentifiableIndex: Identifiable {
    let id = UUID()
    let index: Int
}