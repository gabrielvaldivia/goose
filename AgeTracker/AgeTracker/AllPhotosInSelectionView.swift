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
    
    let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 3)
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(photos) { photo in
                    NavigationLink(destination: FullScreenPhotoView(photo: photo, onDelete: {
                        onDelete(photo)
                    })) {
                        if let image = photo.image {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            Color.gray
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(sectionTitle)
    }
}