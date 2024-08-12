//
//  StacksView.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/12/24.
//

import Foundation
import SwiftUI

struct StacksView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    @Binding var selectedPhoto: Photo?
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(sortedGroupedPhotosForAll(), id: \.0) { section, photos in
                            StackSectionView(
                                section: section,
                                photos: photos,
                                selectedPhoto: $selectedPhoto,
                                person: person,
                                cardHeight: 300,
                                maxWidth: geometry.size.width - 30
                            )
                        }
                    }
                    .padding()
                    .padding(.bottom, 80) // Increased bottom padding
                }
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
        if title == "Birth Month" { return 0 }
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
    
    private func groupAndSortPhotos(forYearView: Bool) -> [(String, [Photo])] {
        let calendar = Calendar.current
        var groupedPhotos: [String: [Photo]] = [:]
        
        let sortedPhotos = person.photos.sorted { (photo1, photo2) -> Bool in
            switch viewModel.sortOrder {
            case .oldestToLatest:
                return photo1.dateTaken < photo2.dateTaken
            case .latestToOldest:
                return photo1.dateTaken > photo2.dateTaken
            }
        }
        
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
                sectionTitle = "Pregnancy"
            }
            
            groupedPhotos[sectionTitle, default: []].append(photo)
        }
        
        // Sort photos within each group
        for (key, value) in groupedPhotos {
            groupedPhotos[key] = value.sorted { (photo1, photo2) -> Bool in
                switch viewModel.sortOrder {
                case .oldestToLatest:
                    return photo1.dateTaken < photo2.dateTaken
                case .latestToOldest:
                    return photo1.dateTaken > photo2.dateTaken
                }
            }
        }
        
        return groupedPhotos.map { ($0.key, $0.value) }
    }
}

struct StackSectionView: View {
    let section: String
    let photos: [Photo]
    @Binding var selectedPhoto: Photo?
    let person: Person
    let cardHeight: CGFloat
    let maxWidth: CGFloat
    
    var body: some View {
        NavigationLink(destination: StackDetailView(sectionTitle: section, photos: photos, onDelete: { _ in }, person: person)) {
            if let randomPhoto = photos.randomElement() {
                ZStack(alignment: .bottom) {
                    if let image = randomPhoto.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: cardHeight)
                            .frame(maxWidth: maxWidth)
                            .clipped()
                            .cornerRadius(20)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: cardHeight)
                            .frame(maxWidth: maxWidth)
                            .cornerRadius(20)
                    }
                    
                    // Gradient overlay
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: cardHeight / 3)
                    .frame(maxWidth: maxWidth)
                    .cornerRadius(20)
                    
                    HStack {
                        HStack(spacing: 8) {
                            Text(section)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.system(size: 18, weight: .bold))
                        }
                        
                        Spacer()
                        
                        Text("\(photos.count) photo\(photos.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                    .padding()
                }
            } else {
                Text("No photos available")
                    .italic()
                    .foregroundColor(.gray)
                    .frame(height: cardHeight)
                    .frame(maxWidth: maxWidth)
            }
        }
    }
}