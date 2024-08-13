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

public struct PhotoUtils {
    static func sortPhotos(_ photos: [Photo], order: Person.SortOrder) -> [Photo] {
        photos.sorted { photo1, photo2 in
            switch order {
            case .latestToOldest:
                return photo1.dateTaken > photo2.dateTaken
            case .oldestToLatest:
                return photo1.dateTaken < photo2.dateTaken
            }
        }
    }

    static func groupAndSortPhotos(for person: Person, sortOrder: Person.SortOrder) -> [(String, [Photo])] {
        let calendar = Calendar.current
        let sortedPhotos = sortPhotos(person.photos, order: sortOrder)
        var groupedPhotos: [String: [Photo]] = [:]

        for photo in sortedPhotos {
            let components = calendar.dateComponents([.year, .month], from: person.dateOfBirth, to: photo.dateTaken)
            let years = components.year ?? 0
            let months = components.month ?? 0

            let sectionTitle: String
            if photo.dateTaken < person.dateOfBirth && !calendar.isDate(photo.dateTaken, inSameDayAs: person.dateOfBirth) {
                sectionTitle = "Pregnancy"
            } else {
                switch person.birthMonthsDisplay {
                case .none:
                    if years == 0 {
                        sectionTitle = "Birth Year"
                    } else {
                        sectionTitle = "\(years) Year\(years == 1 ? "" : "s")"
                    }
                case .twelveMonths:
                    if years == 0 {
                        sectionTitle = "Birth Month"
                    } else {
                        sectionTitle = "\(years) Year\(years == 1 ? "" : "s")"
                    }
                case .twentyFourMonths:
                    let totalMonths = years * 12 + months
                    if totalMonths == 0 {
                        sectionTitle = "Birth Month"
                    } else if totalMonths > 0 && totalMonths <= 23 {
                        sectionTitle = "\(totalMonths) Month\(totalMonths == 1 ? "" : "s")"
                    } else {
                        sectionTitle = "\(years) Year\(years == 1 ? "" : "s")"
                    }
                }
            }

            groupedPhotos[sectionTitle, default: []].append(photo)
        }

        // Sort the groups
        let sortedGroups = groupedPhotos.sorted { (group1, group2) in
            let order1 = orderFromSectionTitle(group1.key, sortOrder: sortOrder)
            let order2 = orderFromSectionTitle(group2.key, sortOrder: sortOrder)
            return order1 < order2
        }

        return sortedGroups
    }

    static func orderFromSectionTitle(_ title: String, sortOrder: Person.SortOrder) -> Int {
        if title == "Pregnancy" {
            return sortOrder == .oldestToLatest ? Int.min : Int.max
        }
        if title == "Birth Month" { return sortOrder == .oldestToLatest ? 1001 : -1 }
        if title == "Birth Year" { return sortOrder == .oldestToLatest ? 1002 : -2 }
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
            sortOrder: viewModel.sortOrder
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
            sortOrder: viewModel.sortOrder
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
        var stacks: [String] = ["Pregnancy"] // Add "Pregnancy" as the first stack
        let calendar = Calendar.current
        let currentDate = Date()
        let ageComponents = calendar.dateComponents([.year, .month], from: person.dateOfBirth, to: currentDate)
        let currentAgeInMonths = (ageComponents.year ?? 0) * 12 + (ageComponents.month ?? 0)

        if person.birthMonthsDisplay == .none {
            stacks.append("Birth Year")
        } else if person.birthMonthsDisplay == .twelveMonths {
            stacks.append("Birth Month")
            stacks.append(contentsOf: (1...min(11, currentAgeInMonths)).map { "\($0) Month\($0 == 1 ? "" : "s")" })
        } else if person.birthMonthsDisplay == .twentyFourMonths {
            stacks.append("Birth Month")
            stacks.append(contentsOf: (1...min(23, currentAgeInMonths)).map { "\($0) Month\($0 == 1 ? "" : "s")" })
        }

        let currentAge = ageComponents.year ?? 0
        let yearStacks = (1...currentAge).map { "\($0) Year\($0 == 1 ? "" : "s")" }
        
        if person.birthMonthsDisplay == .twentyFourMonths {
            stacks.append(contentsOf: yearStacks.filter { $0 != "1 Year" })
        } else {
            stacks.append(contentsOf: yearStacks)
        }
        
        return stacks
    }
    
    static func getDateRangeForSection(_ section: String, person: Person) throws -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let birthDate = person.dateOfBirth

        switch section {
        case "Pregnancy":
            let start = calendar.date(byAdding: .month, value: -9, to: birthDate) ?? birthDate
            return (start: start, end: birthDate)
        case "Birth Month":
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: birthDate) ?? birthDate
            return (start: birthDate, end: endOfMonth)
        default:
            if section.contains("Month") {
                if let months = Int(section.components(separatedBy: " ").first ?? "") {
                    let start = calendar.date(byAdding: .month, value: months - 1, to: birthDate) ?? birthDate
                    let end = calendar.date(byAdding: .month, value: months, to: birthDate) ?? birthDate
                    return (start: start, end: end)
                }
            } else if section.contains("Year") {
                if let years = Int(section.components(separatedBy: " ").first ?? "") {
                    let start = calendar.date(byAdding: .year, value: years - 1, to: birthDate) ?? birthDate
                    let end = calendar.date(byAdding: .year, value: years, to: birthDate) ?? birthDate
                    return (start: start, end: end)
                }
            }
            throw NSError(domain: "Invalid section", code: 0, userInfo: nil)
        }
    }

    enum DateRangeError: Error {
        case invalidDate(String)
        case invalidSection(String)
    }
}