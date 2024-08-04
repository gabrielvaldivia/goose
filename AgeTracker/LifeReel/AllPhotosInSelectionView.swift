//
//  AllPhotosInSelectionView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/2/24.
//

import Foundation
import SwiftUI

struct AllPhotosInSectionView: View {
    let sectionTitle: String
    let photos: [Photo]
    var onDelete: (Photo) -> Void
    @State private var selectedPhotoIndex: IdentifiableIndex?
    let person: Person
    
    let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 3)
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    photoThumbnail(photo)
                        .onTapGesture {
                            selectedPhotoIndex = IdentifiableIndex(index: index)
                        }
                }
            }
            .padding()
        }
        .navigationTitle(sectionTitle)
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
    
    private func photoThumbnail(_ photo: Photo) -> some View {
        Group {
            if let image = photo.image {
                Image(uiImage: image)
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
}

struct IdentifiableIndex: Identifiable {
    let id = UUID()
    let index: Int
}