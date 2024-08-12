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
        let groupedPhotos = groupAndSortPhotos(forYearView: true)
        
        let sortedGroups = groupedPhotos.sorted { (group1, group2) -> Bool in
            let order1 = orderFromSectionTitle(group1.0)
            let order2 = orderFromSectionTitle(group2.0)
            return viewModel.sortOrder == .latestToOldest ? order1 > order2 : order1 < order2
        }
        
        return sortedGroups
    }
    
    private func orderFromSectionTitle(_ title: String) -> Int {
        if title == "Pregnancy" { return -1 }
        if title == "Birth" { return 0 }
        if title.contains("Month") {
            let months = Int(title.components(separatedBy: " ").first ?? "0") ?? 0
            return months
        }
        if title.contains("Year") {
            let years = Int(title.components(separatedBy: " ").first ?? "0") ?? 0
            return years * 12 + 1000 // Add 1000 to ensure years come after months
        }
        return 0
    }
    
    private func groupAndSortPhotos(forYearView: Bool = false) -> [(String, [Photo])] {
        let calendar = Calendar.current
        let sortedPhotos = sortPhotos(person.photos)
        var groupedPhotos: [String: [Photo]] = [:]

        for photo in sortedPhotos {
            let components = calendar.dateComponents([.year, .month], from: person.dateOfBirth, to: photo.dateTaken)
            let years = components.year ?? 0
            let months = components.month ?? 0

            let sectionTitle: String
            if photo.dateTaken >= person.dateOfBirth {
                if years == 0 && months == 0 {
                    sectionTitle = "Birth Month"
                } else if years == 0 {
                    sectionTitle = "\(months) Month\(months == 1 ? "" : "s")"
                } else {
                    sectionTitle = "\(years) Year\(years == 1 ? "" : "s")"
                }
            } else {
                sectionTitle = forYearView ? "Pregnancy" : calculatePregnancyWeek(photo.dateTaken)
            }

            groupedPhotos[sectionTitle, default: []].append(photo)
        }

        return groupedPhotos.map { ($0.key, $0.value) }
    }
    
    private func calculatePregnancyWeek(_ date: Date) -> String {
        let calendar = Calendar.current
        let componentsBeforeBirth = calendar.dateComponents([.day], from: date, to: person.dateOfBirth)
        let daysBeforeBirth = componentsBeforeBirth.day ?? 0
        let weeksBeforeBirth = daysBeforeBirth / 7
        let remainingDays = daysBeforeBirth % 7
        let pregnancyWeek = max(40 - weeksBeforeBirth, 0)
        
        if pregnancyWeek == 40 {
            return "Birth Month"
        } else if pregnancyWeek > 0 {
            if remainingDays > 0 {
                return "\(pregnancyWeek) Week\(pregnancyWeek == 1 ? "" : "s") and \(remainingDays) Day\(remainingDays == 1 ? "" : "s") Pregnant"
            } else {
                return "\(pregnancyWeek) Week\(pregnancyWeek == 1 ? "" : "s") Pregnant"
            }
        } else {
            return "Before Pregnancy"
        }
    }
    
    private func updateScrollPosition(_ value: CGPoint) {
        // Implement the logic to update scroll position
    }
}
