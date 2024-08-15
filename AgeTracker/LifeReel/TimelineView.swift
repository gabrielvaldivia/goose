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
        GeometryReader { geometry in
            if sortedGroupedPhotosForAll().isEmpty {
                EmptyStateView(
                    title: "No photos in timeline",
                    subtitle: "Add photos to see them here",
                    systemImageName: "photo.on.rectangle.angled",
                    action: {
                        // You might want to add an action here, like opening the image picker
                    }
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                ScrollView {
                    LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                        ForEach(sortedGroupedPhotosForAll(), id: \.0) { section, photos in
                            if !photos.isEmpty {
                                Section(header: stickyHeader(for: section)) {
                                    LazyVStack(spacing: 10) {
                                        ForEach(sortPhotos(photos), id: \.id) { photo in
                                            TimelineItemView(photo: photo, person: person, selectedPhoto: $selectedPhoto)
                                        }
                                    }
                                }
                                .id(section)
                            }
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 80)
                }
            }
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
            PhotoView(photo: photo, 
                      containerWidth: UIScreen.main.bounds.width - 40, 
                      isGridView: false, 
                      selectedPhoto: $selectedPhoto, 
                      person: person)
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
        let groupedPhotos = Dictionary(grouping: person.photos) { photo in
            PhotoUtils.sectionForPhoto(photo, person: person)
        }
        
        let sortedGroups = groupedPhotos.sorted { (group1, group2) -> Bool in
            let date1 = group1.value.max(by: { $0.dateTaken < $1.dateTaken })?.dateTaken ?? Date.distantPast
            let date2 = group2.value.max(by: { $0.dateTaken < $1.dateTaken })?.dateTaken ?? Date.distantPast
            return date1 > date2
        }
        
        return sortedGroups.map { ($0.key, $0.value.sorted(by: { $0.dateTaken > $1.dateTaken })) }
    }
    
    private func calculateAge(for person: Person, at date: Date) -> String {
        return ExactAge.calculate(for: person, at: date).toString()
    }
}