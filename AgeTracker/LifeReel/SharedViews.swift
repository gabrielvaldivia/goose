//
//  SharedViews.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/9/24.
//

import Foundation
import SwiftUI
import PhotosUI
import Photos

struct PhotoView: View {
    let photo: Photo
    let containerWidth: CGFloat
    let isGridView: Bool
    @Binding var selectedPhoto: Photo?
    let person: Person

    var body: some View {
        Image(uiImage: photo.image ?? UIImage())
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: containerWidth)
            .onTapGesture {
                selectedPhoto = photo
            }
    }
}



struct ShareButton: View {
    var body: some View {
        Button(action: {
            // Share logic
        }) {
            Image(systemName: "square.and.arrow.up")
                .foregroundColor(.blue)
                .font(.system(size: 24, weight: .bold))
        }
    }
}

struct PhotoUtils {
    static func sortPhotos(_ photos: [Photo], order: SortOrder) -> [Photo] {
        photos.sorted { photo1, photo2 in
            switch order {
            case .latestToOldest:
                return photo1.dateTaken > photo2.dateTaken
            case .oldestToLatest:
                return photo1.dateTaken < photo2.dateTaken
            }
        }
    }

    static func groupAndSortPhotos(for person: Person, sortOrder: SortOrder, trackPregnancy: Bool, showBirthMonths: Bool, showPregnancyWeeks: Bool) -> [(String, [Photo])] {
        let calendar = Calendar.current
        let sortedPhotos = sortPhotos(person.photos, order: sortOrder)
        var groupedPhotos: [String: [Photo]] = [:]

        for photo in sortedPhotos {
            let components = calendar.dateComponents([.day], from: photo.dateTaken, to: person.dateOfBirth)
            let daysBeforeBirth = components.day ?? 0

            let sectionTitle: String
            if photo.dateTaken >= person.dateOfBirth {
                // Existing logic for after birth
                let ageComponents = calendar.dateComponents([.year, .month], from: person.dateOfBirth, to: photo.dateTaken)
                let years = ageComponents.year ?? 0
                let months = ageComponents.month ?? 0

                if years == 0 {
                    if showBirthMonths {
                        if months == 0 {
                            sectionTitle = "Birth Month"
                        } else {
                            sectionTitle = "\(months) Month\(months == 1 ? "" : "s")"
                        }
                    } else {
                        sectionTitle = "Birth Year"
                    }
                } else {
                    sectionTitle = "\(years) Year\(years == 1 ? "" : "s")"
                }
            } else if trackPregnancy {
                // Updated logic for pregnancy
                if showPregnancyWeeks {
                    let weeksBeforeBirth = daysBeforeBirth / 7
                    let pregnancyWeek = min(max(1, 40 - weeksBeforeBirth), 40)
                    sectionTitle = "\(pregnancyWeek) Week\(pregnancyWeek == 1 ? "" : "s") Pregnant"
                } else {
                    sectionTitle = "Pregnancy"
                }
            } else {
                continue // Skip pregnancy photos if not tracking
            }

            groupedPhotos[sectionTitle, default: []].append(photo)
        }

        // Sort the groups based on the orderFromSectionTitle function
        let sortedGroups = groupedPhotos.sorted { (group1, group2) in
            let order1 = orderFromSectionTitle(group1.key, sortOrder: sortOrder)
            let order2 = orderFromSectionTitle(group2.key, sortOrder: sortOrder)
            return order1 < order2
        }

        return sortedGroups
    }

    static func orderFromSectionTitle(_ title: String, sortOrder: SortOrder) -> Int {
        if title.contains("Pregnant") {
            let week = Int(title.components(separatedBy: " ").first ?? "0") ?? 0
            return sortOrder == .oldestToLatest ? week : 1000 - week
        }
        if title == "Pregnancy" { return sortOrder == .oldestToLatest ? 0 : 1000 }
        if title == "Birth Month" { return sortOrder == .oldestToLatest ? 1001 : -1 }
        if title == "Birth Year" { return sortOrder == .oldestToLatest ? 1001 : -1 }
        if title.contains("Month") {
            let months = Int(title.components(separatedBy: " ").first ?? "0") ?? 0
            return sortOrder == .oldestToLatest ? 1001 + months : -1 - months
        }
        if title.contains("Year") {
            let years = Int(title.components(separatedBy: " ").first ?? "0") ?? 0
            return sortOrder == .oldestToLatest ? 2000 + years : -1000 - years
        }
        return 3000 // Default value for unknown titles
    }

    static func sortedGroupedPhotosForAll(person: Person, viewModel: PersonViewModel) -> [(String, [Photo])] {
        let groupedPhotos = groupAndSortPhotos(
            for: person,
            sortOrder: viewModel.sortOrder,
            trackPregnancy: person.trackPregnancy,
            showBirthMonths: person.showBirthMonths,
            showPregnancyWeeks: person.showPregnancyWeeks
        )
        
        // Convert groupedPhotos to a dictionary for easier lookup
        let groupedPhotosDict = Dictionary(groupedPhotos, uniquingKeysWith: { (first, _) in first })
        
        // Ensure all expected stacks are present, even if empty
        let allStacks = getAllExpectedStacks(for: person)
        let completeGroupedPhotos = allStacks.map { stack in
            (stack, groupedPhotosDict[stack] ?? [])
        }
        
        let sortedGroups = completeGroupedPhotos.sorted { (group1, group2) -> Bool in
            let order1 = orderFromSectionTitle(group1.0, sortOrder: viewModel.sortOrder)
            let order2 = orderFromSectionTitle(group2.0, sortOrder: viewModel.sortOrder)
            return order1 < order2
        }
        
        // Filter out empty stacks
        let nonEmptyGroups = sortedGroups.filter { !$0.1.isEmpty }
        
        return nonEmptyGroups
    }

    static func sortedGroupedPhotosForAllIncludingEmpty(person: Person, viewModel: PersonViewModel) -> [(String, [Photo])] {
        let groupedPhotos = groupAndSortPhotos(
            for: person,
            sortOrder: viewModel.sortOrder,
            trackPregnancy: person.trackPregnancy,
            showBirthMonths: person.showBirthMonths,
            showPregnancyWeeks: person.showPregnancyWeeks
        )
        
        // Convert groupedPhotos to a dictionary for easier lookup
        let groupedPhotosDict = Dictionary(groupedPhotos, uniquingKeysWith: { (first, _) in first })
        
        // Ensure all expected stacks are present, even if empty
        let allStacks = getAllExpectedStacks(for: person)
        let completeGroupedPhotos = allStacks.map { stack in
            (stack, groupedPhotosDict[stack] ?? [])
        }
        
        let sortedGroups = completeGroupedPhotos.sorted { (group1, group2) -> Bool in
            let order1 = orderFromSectionTitle(group1.0, sortOrder: viewModel.sortOrder)
            let order2 = orderFromSectionTitle(group2.0, sortOrder: viewModel.sortOrder)
            return order1 < order2
        }
        
        return sortedGroups
    }

    static func getAllExpectedStacks(for person: Person) -> [String] {
        var stacks: [String] = []
        if person.trackPregnancy {
            if person.showPregnancyWeeks {
                stacks.append(contentsOf: (1...40).map { "\($0) Week\($0 == 1 ? "" : "s") Pregnant" })
            } else {
                stacks.append("Pregnancy")
            }
        }
        if person.showBirthMonths {
            stacks.append("Birth Month")
            stacks.append(contentsOf: (1...11).map { "\($0) Month\($0 == 1 ? "" : "s")" })
        } else {
            stacks.append("Birth Year")
        }
        let currentAge = Calendar.current.dateComponents([.year], from: person.dateOfBirth, to: Date()).year ?? 0
        stacks.append(contentsOf: (1...currentAge).map { "\($0) Year\($0 == 1 ? "" : "s")" })
        return stacks
    }
}