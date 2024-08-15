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
            let sectionTitle = sectionForPhoto(photo, person: person)
            groupedPhotos[sectionTitle, default: []].append(photo)
        }

        // Sort the groups
        let sortedGroups = groupedPhotos.sorted { (group1, group2) in
            let order1 = orderFromSectionTitle(group1.key, sortOrder: sortOrder)
            let order2 = orderFromSectionTitle(group2.key, sortOrder: sortOrder)
            return sortOrder == .oldestToLatest ? order1 < order2 : order1 > order2
        }

        return sortedGroups
    }

    static func orderFromSectionTitle(_ title: String, sortOrder: Person.SortOrder) -> Int {
        if title == "Pregnancy" {
            return sortOrder == .oldestToLatest ? Int.min : Int.max
        }
        if title.starts(with: "First Trimester") {
            return sortOrder == .oldestToLatest ? -300 : 300
        }
        if title.starts(with: "Second Trimester") {
            return sortOrder == .oldestToLatest ? -200 : 200
        }
        if title.starts(with: "Third Trimester") {
            return sortOrder == .oldestToLatest ? -100 : 100
        }
        if title.starts(with: "Week") {
            if let week = Int(title.components(separatedBy: " ").last ?? "") {
                return sortOrder == .oldestToLatest ? week : -week + 400
            }
        }
        if title == "Birth Month" { return sortOrder == .oldestToLatest ? 1001 : -1001 }
        if title == "Birth Year" { return sortOrder == .oldestToLatest ? 1002 : -1002 }
        if title.contains("Month") {
            let months = Int(title.components(separatedBy: " ").first ?? "0") ?? 0
            return sortOrder == .oldestToLatest ? 1001 + months : -1001 - months
        }
        if title.contains("Year") {
            let years = Int(title.components(separatedBy: " ").first ?? "0") ?? 0
            return sortOrder == .oldestToLatest ? 2000 + years : -2000 - years
        }
        return 3000 // Default value for unknown titles
    }

    static func sortedGroupedPhotosForAll(person: Person, viewModel: PersonViewModel) -> [(String, [Photo])] {
        let groupedPhotos = groupAndSortPhotos(
            for: person,
            sortOrder: viewModel.sortOrder
        )
        
        return sortGroupsBasedOnSettings(groupedPhotos, sortOrder: viewModel.sortOrder)
    }

    static func sortedGroupedPhotosForAllIncludingEmpty(person: Person, viewModel: PersonViewModel) -> [(String, [Photo])] {
        let allStacks = getAllExpectedStacks(for: person)
        let groupedPhotos = Dictionary(grouping: person.photos) { photo in
            PhotoUtils.sectionForPhoto(photo, person: person)
        }
        
        let completeGroupedPhotos = allStacks.map { stack in
            (stack, groupedPhotos[stack] ?? [])
        }
        
        return sortGroupsBasedOnSettings(completeGroupedPhotos, sortOrder: viewModel.sortOrder)
    }

    private static func sortGroupsBasedOnSettings(_ groups: [(String, [Photo])], sortOrder: Person.SortOrder) -> [(String, [Photo])] {
        return groups.sorted { (group1, group2) in
            let order1 = orderFromSectionTitle(group1.0, sortOrder: sortOrder)
            let order2 = orderFromSectionTitle(group2.0, sortOrder: sortOrder)
            return sortOrder == .oldestToLatest ? order1 < order2 : order1 > order2
        }
    }

    static func getAllExpectedStacks(for person: Person) -> [String] {
        var stacks: [String] = []
        let calendar = Calendar.current
        let currentDate = Date()
        
        let endDate = min(person.dateOfBirth, currentDate)
        let pregnancyStartDate = calendar.date(byAdding: .month, value: -9, to: person.dateOfBirth) ?? person.dateOfBirth
        
        // Include pregnancy stacks only if tracking is set to trimesters or weeks
        switch person.pregnancyTracking {
        case .trimesters:
            let trimesterDuration = TimeInterval(91 * 24 * 60 * 60) // 91 days in seconds
            for i in 0..<3 {
                let trimesterStart = pregnancyStartDate.addingTimeInterval(Double(i) * trimesterDuration)
                if trimesterStart < endDate {
                    stacks.append(["First Trimester", "Second Trimester", "Third Trimester"][i])
                }
            }
        case .weeks:
            for week in 1...40 {
                let weekStart = pregnancyStartDate.addingTimeInterval(Double(week - 1) * 7 * 24 * 60 * 60)
                if weekStart < endDate {
                    stacks.append("Week \(week)")
                }
            }
        case .none:
            // Don't add any pregnancy stacks
            break
        }
        
        // Handle past or current birth dates
        if person.dateOfBirth <= currentDate {
            let ageComponents = calendar.dateComponents([.year, .month], from: person.dateOfBirth, to: currentDate)
            let currentAgeInMonths = max(0, (ageComponents.year ?? 0) * 12 + (ageComponents.month ?? 0))
            let currentAgeInYears = ageComponents.year ?? 0

            switch person.birthMonthsDisplay {
            case .none:
                stacks.append("Birth Year")
                stacks.append(contentsOf: (1...currentAgeInYears).map { "\($0) Year\($0 == 1 ? "" : "s")" })
            case .twelveMonths:
                stacks.append("Birth Month")
                let monthsToShow = min(11, currentAgeInMonths)
                stacks.append(contentsOf: (1...monthsToShow).map { "\($0) Month\($0 == 1 ? "" : "s")" })
                if currentAgeInMonths >= 12 {
                    stacks.append("1 Year")
                    if currentAgeInYears > 1 {
                        stacks.append(contentsOf: (2...currentAgeInYears).map { "\($0) Years" })
                    }
                }
            case .twentyFourMonths:
                stacks.append("Birth Month")
                let monthsToShow = min(23, currentAgeInMonths)
                stacks.append(contentsOf: (1...monthsToShow).map { "\($0) Month\($0 == 1 ? "" : "s")" })
                if currentAgeInYears >= 2 {
                    stacks.append(contentsOf: (2...currentAgeInYears).map { "\($0) Years" })
                }
            }
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
        case "First Trimester":
            let pregnancyStart = calendar.date(byAdding: .month, value: -9, to: birthDate) ?? birthDate
            let end = calendar.date(byAdding: .month, value: 3, to: pregnancyStart) ?? birthDate
            return (start: pregnancyStart, end: end)
        case "Second Trimester":
            let pregnancyStart = calendar.date(byAdding: .month, value: -9, to: birthDate) ?? birthDate
            let start = calendar.date(byAdding: .month, value: 3, to: pregnancyStart) ?? birthDate
            let end = calendar.date(byAdding: .month, value: 6, to: pregnancyStart) ?? birthDate
            return (start: start, end: end)
        case "Third Trimester":
            let pregnancyStart = calendar.date(byAdding: .month, value: -9, to: birthDate) ?? birthDate
            let start = calendar.date(byAdding: .month, value: 6, to: pregnancyStart) ?? birthDate
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
            } else if section.starts(with: "Week") {
                if let week = Int(section.components(separatedBy: " ").last ?? "") {
                    let pregnancyStart = calendar.date(byAdding: .month, value: -9, to: birthDate) ?? birthDate
                    let start = calendar.date(byAdding: .day, value: (week - 1) * 7, to: pregnancyStart) ?? pregnancyStart
                    let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
                    return (start: start, end: end)
                }
            }
            throw NSError(domain: "Invalid section", code: 0, userInfo: nil)
        }
    }

    static func sectionForPhoto(_ photo: Photo, person: Person) -> String {
        let exactAge = ExactAge.calculate(for: person, at: photo.dateTaken)
        
        if exactAge.isPregnancy {
            switch person.pregnancyTracking {
            case .none:
                return "Before Birth"
            case .trimesters:
                let trimester = (exactAge.pregnancyWeeks - 1) / 13 + 1
                return "\(["First", "Second", "Third"][trimester - 1]) Trimester"
            case .weeks:
                return "Week \(exactAge.pregnancyWeeks)"
            }
        }
        
        if exactAge.isNewborn {
            return "Birth Month"
        }
        
        switch person.birthMonthsDisplay {
        case .none:
            return exactAge.years == 0 ? "Birth Year" : "\(exactAge.years) Year\(exactAge.years == 1 ? "" : "s")"
        case .twelveMonths:
            if exactAge.months < 12 {
                return "\(exactAge.months + 1) Month\(exactAge.months == 0 ? "" : "s")"
            } else {
                return "\(exactAge.years) Year\(exactAge.years == 1 ? "" : "s")"
            }
        case .twentyFourMonths:
            if exactAge.months < 24 {
                return "\(exactAge.months + 1) Month\(exactAge.months == 0 ? "" : "s")"
            } else {
                return "\(exactAge.years) Year\(exactAge.years == 1 ? "" : "s")"
            }
        }
    }

    static func getGeneralAgeStacks(for person: Person) -> [String] {
        var stacks: [String] = ["Pregnancy"]
        let calendar = Calendar.current
        let currentDate = Date()
        let ageComponents = calendar.dateComponents([.year, .month], from: person.dateOfBirth, to: currentDate)
        let currentAgeInMonths = (ageComponents.year ?? 0) * 12 + (ageComponents.month ?? 0)
        let currentAgeInYears = ageComponents.year ?? 0

        switch person.birthMonthsDisplay {
        case .none:
            stacks.append("Birth Year")
            stacks.append(contentsOf: (1...currentAgeInYears).map { "\($0) Year\($0 == 1 ? "" : "s")" })
        case .twelveMonths:
            stacks.append("Birth Month")
            let monthsToShow = min(11, currentAgeInMonths)
            stacks.append(contentsOf: (1...monthsToShow).map { "\($0) Month\($0 == 1 ? "" : "s")" })
            if currentAgeInMonths >= 12 {
                stacks.append("1 Year")
                if currentAgeInYears > 1 {
                    stacks.append(contentsOf: (2...currentAgeInYears).map { "\($0) Years" })
                }
            }
        case .twentyFourMonths:
            stacks.append("Birth Month")
            let monthsToShow = min(23, currentAgeInMonths)
            stacks.append(contentsOf: (1...monthsToShow).map { "\($0) Month\($0 == 1 ? "" : "s")" })
            if currentAgeInYears >= 2 {
                stacks.append(contentsOf: (2...max(2, currentAgeInYears)).map { "\($0) Years" })
            }
        }
        
        return stacks
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
    let isNewborn: Bool

    static func calculate(for person: Person, at date: Date) -> ExactAge {
        let calendar = Calendar.current
        
        // Handle the birth day separately
        if calendar.isDate(date, equalTo: person.dateOfBirth, toGranularity: .day) {
            return ExactAge(years: 0, months: 0, days: 0, isPregnancy: false, pregnancyWeeks: 0, isNewborn: true)
        }
        
        if date < person.dateOfBirth {
            let components = calendar.dateComponents([.day], from: date, to: person.dateOfBirth)
            let daysUntilBirth = components.day ?? 0
            let weeksPregnant = min(39, 40 - (daysUntilBirth / 7))
            return ExactAge(years: 0, months: 0, days: 0, isPregnancy: true, pregnancyWeeks: weeksPregnant, isNewborn: false)
        }
        
        var components = calendar.dateComponents([.year, .month, .day], from: person.dateOfBirth, to: date)
        
        // Adjust for exact month boundaries
        if calendar.component(.day, from: date) < calendar.component(.day, from: person.dateOfBirth) {
            components.month = (components.month ?? 0) - 1
            if components.month ?? 0 < 0 {
                components.year = (components.year ?? 0) - 1
                components.month = 11
            }
            let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: date)!
            let daysInPreviousMonth = calendar.range(of: .day, in: .month, for: previousMonthDate)!.count
            components.day = (components.day ?? 0) + daysInPreviousMonth
        }
        
        let years = components.year ?? 0
        let months = components.month ?? 0
        let days = components.day ?? 0
        
        return ExactAge(years: years, months: months, days: days, isPregnancy: false, pregnancyWeeks: 0, isNewborn: false)
    }

    func toString() -> String {
        if isNewborn {
            return "Newborn"
        }
        if isPregnancy {
            return "\(pregnancyWeeks) week\(pregnancyWeeks == 1 ? "" : "s") pregnant"
        }
        
        var parts: [String] = []
        if years > 0 { parts.append("\(years) year\(years == 1 ? "" : "s")") }
        if months > 0 { parts.append("\(months) month\(months == 1 ? "" : "s")") }
        if days > 0 || parts.isEmpty { parts.append("\(days) day\(days == 1 ? "" : "s")") }
        
        return parts.joined(separator: ", ")
    }

    func toShortString() -> String {
        if isPregnancy {
            return "\(pregnancyWeeks)w"
        }
        if years > 0 {
            return "\(years)y"
        }
        if months > 0 {
            return "\(months)m"
        }
        return "\(days)d"
    }
}

struct BirthDaySheet: View {
    @Binding var dateOfBirth: Date
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            DatePicker("", selection: $dateOfBirth, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .padding()
                .navigationTitle("Select Date of Birth")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button("Done") {
                    isPresented = false
                })
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let systemImageName: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImageName)
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .onTapGesture(perform: action)
    }
}

struct PhotoDatePickerSheet: View {
    @Binding var date: Date
    @Binding var isPresented: Bool
    var onSave: () -> Void

    var body: some View {
        VStack {
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                Spacer()
                Text("Edit Date")
                    .font(.headline)
                Spacer()
                Button("Save") {
                    onSave()
                    isPresented = false
                }
            }
            .padding()

            DatePicker("", selection: $date, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()

            Spacer()
        }
        .background(Color(UIColor.systemBackground))
    }
}