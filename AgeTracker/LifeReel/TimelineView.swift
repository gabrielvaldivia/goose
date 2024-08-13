//
//  TimelineView.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/12/24.
//

import Foundation

import SwiftUI
import Photos

struct TimelineView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    @Binding var selectedPhoto: Photo?
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                ForEach(sortedGroupedPhotosForAll(), id: \.0) { section, photos in
                    Section(header: stickyHeader(for: section)) {
                        ForEach(sortPhotos(photos), id: \.id) { photo in
                            TimelineItemView(photo: photo, person: person, selectedPhoto: $selectedPhoto)
                        }
                    }
                    .id(section)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 80) // Increased bottom padding
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            updateScrollPosition(value)
        }
    }
    
    private func stickyHeader(for section: String) -> some View {
        HStack {
            Spacer()
            Text(section)
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    VisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
                        .clipShape(Capsule())
                )
            Spacer()
        }
        .padding(.top, 8)
    }
    
    private struct TimelineItemView: View {
        let photo: Photo
        let person: Person
        @Binding var selectedPhoto: Photo?
        
        var body: some View {
            PhotoView(photo: photo, containerWidth: UIScreen.main.bounds.width - 40, isGridView: false, selectedPhoto: $selectedPhoto, person: person)
                .aspectRatio(contentMode: .fit)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
                .onTapGesture {
                    selectedPhoto = photo
                }
        }
    }
    
    private func sortPhotos(_ photos: [Photo]) -> [Photo] {
        photos.sorted { photo1, photo2 in
            switch viewModel.sortOrder {
            case .latestToOldest:
                return photo1.dateTaken > photo2.dateTaken
            case .oldestToLatest:
                return photo1.dateTaken < photo2.dateTaken
            }
        }
    }
    
    private func sortedGroupedPhotosForAll() -> [(String, [Photo])] {
        return PhotoUtils.sortedGroupedPhotosForAllIncludingEmpty(person: person, viewModel: viewModel)
    }
    
    private func updateScrollPosition(_ value: CGPoint) {
        // Implement the logic to update scroll position
    }
}