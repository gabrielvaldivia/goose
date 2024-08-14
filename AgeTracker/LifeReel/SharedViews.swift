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
            let totalMonths = years * 12 + months

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
                    if totalMonths == 0 {
                        sectionTitle = "Birth Month"
                    } else if totalMonths <= 11 {
                        sectionTitle = "\(totalMonths + 1) Month\(totalMonths == 0 ? "" : "s")"
                    } else {
                        sectionTitle = "\(years) Year\(years == 1 ? "" : "s")"
                    }
                case .twentyFourMonths:
                    if totalMonths == 0 {
                        sectionTitle = "Birth Month"
                    } else if totalMonths <= 23 {
                        sectionTitle = "\(totalMonths + 1) Month\(totalMonths == 0 ? "" : "s")"
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
        var stacks: [String] = ["Pregnancy"]
        let calendar = Calendar.current
        let currentDate = Date()
        let ageComponents = calendar.dateComponents([.year, .month], from: person.dateOfBirth, to: currentDate)
        let currentAgeInMonths = (ageComponents.year ?? 0) * 12 + (ageComponents.month ?? 0)

        switch person.birthMonthsDisplay {
        case .none:
            stacks.append("Birth Year")
        case .twelveMonths:
            stacks.append("Birth Month")
            stacks.append(contentsOf: (1...min(11, currentAgeInMonths)).map { "\($0) Month\($0 == 1 ? "" : "s")" })
        case .twentyFourMonths:
            stacks.append("Birth Month")
            stacks.append(contentsOf: (1...min(23, currentAgeInMonths)).map { "\($0) Month\($0 == 1 ? "" : "s")" })
        }

        let currentAge = max(0, ageComponents.year ?? 0)
        let yearStacks = (1...max(1, currentAge)).map { "\($0) Year\($0 == 1 ? "" : "s")" }
        
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

    static func sectionForPhoto(_ photo: Photo, person: Person) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: person.dateOfBirth, to: photo.dateTaken)
        let years = components.year ?? 0
        let months = components.month ?? 0
        let totalMonths = years * 12 + months

        if photo.dateTaken < person.dateOfBirth && !calendar.isDate(photo.dateTaken, inSameDayAs: person.dateOfBirth) {
            return "Pregnancy"
        } else {
            switch person.birthMonthsDisplay {
            case .none:
                if years == 0 {
                    return "Birth Year"
                } else {
                    return "\(years) Year\(years == 1 ? "" : "s")"
                }
            case .twelveMonths:
                if totalMonths == 0 {
                    return "Birth Month"
                } else if totalMonths <= 11 {
                    return "\(totalMonths + 1) Month\(totalMonths == 0 ? "" : "s")"
                } else {
                    return "\(years) Year\(years == 1 ? "" : "s")"
                }
            case .twentyFourMonths:
                if totalMonths == 0 {
                    return "Birth Month"
                } else if totalMonths <= 23 {
                    return "\(totalMonths + 1) Month\(totalMonths == 0 ? "" : "s")"
                } else {
                    return "\(years) Year\(years == 1 ? "" : "s")"
                }
            }
        }
    }

    enum DateRangeError: Error {
        case invalidDate(String)
        case invalidSection(String)
    }
}

struct ExactAge {
    let years: Int
    let months: Int
    let days: Int
    let isPregnancy: Bool
    let pregnancyWeeks: Int

    static func calculate(for person: Person, at date: Date) -> ExactAge {
        let calendar = Calendar.current
        
        if date < person.dateOfBirth {
            let components = calendar.dateComponents([.day], from: date, to: person.dateOfBirth)
            let daysUntilBirth = components.day ?? 0
            let weeksPregnant = 40 - (daysUntilBirth / 7)
            return ExactAge(years: 0, months: 0, days: 0, isPregnancy: true, pregnancyWeeks: weeksPregnant)
        }
        
        let components = calendar.dateComponents([.year, .month, .day], from: person.dateOfBirth, to: date)
        let years = components.year ?? 0
        let months = components.month ?? 0
        let days = components.day ?? 0
        
        switch person.birthMonthsDisplay {
        case .none:
            return ExactAge(years: years, months: 0, days: 0, isPregnancy: false, pregnancyWeeks: 0)
        case .twelveMonths:
            if years == 0 || (years == 1 && months == 0 && days == 0) {
                return ExactAge(years: 0, months: years * 12 + months, days: days, isPregnancy: false, pregnancyWeeks: 0)
            } else {
                return ExactAge(years: years, months: months, days: days, isPregnancy: false, pregnancyWeeks: 0)
            }
        case .twentyFourMonths:
            if years < 2 || (years == 2 && months == 0 && days == 0) {
                return ExactAge(years: 0, months: years * 12 + months, days: days, isPregnancy: false, pregnancyWeeks: 0)
            } else {
                return ExactAge(years: years, months: months, days: days, isPregnancy: false, pregnancyWeeks: 0)
            }
        }
    }

    func toString() -> String {
        if isPregnancy {
            return "\(pregnancyWeeks) week\(pregnancyWeeks == 1 ? "" : "s") pregnant"
        }
        
        var parts: [String] = []
        if years > 0 { parts.append("\(years) year\(years == 1 ? "" : "s")") }
        if months > 0 { parts.append("\(months) month\(months == 1 ? "" : "s")") }
        if days > 0 || parts.isEmpty { parts.append("\(days) day\(days == 1 ? "" : "s")") }
        
        return parts.joined(separator: ", ")
    }
}

struct GeneralAge {
    let value: Int
    let unit: AgeUnit
    
    enum AgeUnit {
        case month
        case year
    }
    
    static func calculate(for person: Person, at date: Date, displayOption: Person.BirthMonthsDisplay) -> GeneralAge {
        let calendar = Calendar.current
        
        if date < person.dateOfBirth {
            return GeneralAge(value: 0, unit: .month)
        }
        
        let components = calendar.dateComponents([.year, .month], from: person.dateOfBirth, to: date)
        let totalMonths = (components.year ?? 0) * 12 + (components.month ?? 0)
        
        switch displayOption {
        case .none:
            return GeneralAge(value: components.year ?? 0, unit: .year)
        case .twelveMonths:
            if totalMonths <= 11 {
                return GeneralAge(value: totalMonths + 1, unit: .month)
            } else {
                return GeneralAge(value: components.year ?? 0, unit: .year)
            }
        case .twentyFourMonths:
            if totalMonths <= 23 {
                return GeneralAge(value: totalMonths + 1, unit: .month)
            } else {
                return GeneralAge(value: components.year ?? 0, unit: .year)
            }
        }
    }

    func toString() -> String {
        switch unit {
        case .month:
            return value == 0 ? "Birth Month" : "\(value) Month\(value == 1 ? "" : "s")"
        case .year:
            return "\(value) Year\(value == 1 ? "" : "s")"
        }
    }
}