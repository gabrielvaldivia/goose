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
        var stacks: [String] = []
        let calendar = Calendar.current
        let currentDate = Date()
        
        let endDate = min(person.dateOfBirth, currentDate)
        let pregnancyStartDate = calendar.date(byAdding: .month, value: -9, to: person.dateOfBirth) ?? person.dateOfBirth
        
        // Include pregnancy stacks based on the tracking option
        switch person.pregnancyTracking {
        case .none:
            if pregnancyStartDate < endDate {
                stacks.append("Pregnancy")
            }
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
        let calendar = Calendar.current
        let currentDate = Date()
        
        if person.dateOfBirth > currentDate {
            // Handle future birth dates
            switch person.pregnancyTracking {
            case .none:
                return "Pregnancy"
            case .trimesters:
                let weeksUntilBirth = calendar.dateComponents([.weekOfYear], from: photo.dateTaken, to: person.dateOfBirth).weekOfYear ?? 0
                let trimester = weeksUntilBirth / 13
                return ["Third Trimester", "Second Trimester", "First Trimester"][min(trimester, 2)]
            case .weeks:
                let weeksUntilBirth = calendar.dateComponents([.weekOfYear], from: photo.dateTaken, to: person.dateOfBirth).weekOfYear ?? 0
                let pregnancyWeek = max(1, 40 - weeksUntilBirth)
                return "Week \(min(40, pregnancyWeek))"
            }
        }

        if calendar.isDate(photo.dateTaken, equalTo: person.dateOfBirth, toGranularity: .day) {
            return "Birth Month"
        }

        let ageComponents = calendar.dateComponents([.year, .month, .day], from: person.dateOfBirth, to: photo.dateTaken)
        let ageInMonths = (ageComponents.year ?? 0) * 12 + (ageComponents.month ?? 0)
        let ageInDays = ageComponents.day ?? 0

        if photo.dateTaken < person.dateOfBirth {
            return "Pregnancy"
        }

        if calendar.isDate(photo.dateTaken, equalTo: person.dateOfBirth, toGranularity: .month) {
            return "Birth Month"
        }

        switch person.birthMonthsDisplay {
        case .none:
            return ageInMonths < 12 ? "Birth Year" : "\(ageComponents.year ?? 0) Year\(ageComponents.year == 1 ? "" : "s")"
        case .twelveMonths:
            if ageInMonths < 12 {
                return "\(ageInMonths) Month\(ageInMonths == 1 ? "" : "s")"
            } else {
                return "\(ageComponents.year ?? 0) Year\(ageComponents.year == 1 ? "" : "s")"
            }
        case .twentyFourMonths:
            if ageInMonths < 24 {
                return "\(ageInMonths) Month\(ageInMonths == 1 ? "" : "s")"
            } else {
                return "\(ageComponents.year ?? 0) Year\(ageComponents.year == 1 ? "" : "s")"
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
    let isNewborn: Bool  // Add this new property

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
        
        let components = calendar.dateComponents([.year, .month, .day], from: person.dateOfBirth, to: date)
        let years = components.year ?? 0
        let months = components.month ?? 0
        let days = components.day ?? 0
        
        // Adjust days and months if necessary
        var adjustedMonths = months
        var adjustedDays = days
        if days < 0 {
            adjustedMonths -= 1
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: date) ?? date
            let daysInPreviousMonth = calendar.range(of: .day, in: .month, for: previousMonth)?.count ?? 0
            adjustedDays += daysInPreviousMonth
        }
        
        switch person.birthMonthsDisplay {
        case .none:
            return ExactAge(years: years, months: 0, days: 0, isPregnancy: false, pregnancyWeeks: 0, isNewborn: false)
        case .twelveMonths:
            if years == 0 || (years == 1 && adjustedMonths == 0 && adjustedDays == 0) {
                return ExactAge(years: 0, months: years * 12 + adjustedMonths, days: adjustedDays, isPregnancy: false, pregnancyWeeks: 0, isNewborn: false)
            } else {
                return ExactAge(years: years, months: adjustedMonths, days: adjustedDays, isPregnancy: false, pregnancyWeeks: 0, isNewborn: false)
            }
        case .twentyFourMonths:
            if years < 2 || (years == 2 && adjustedMonths == 0 && adjustedDays == 0) {
                return ExactAge(years: 0, months: years * 12 + adjustedMonths, days: adjustedDays, isPregnancy: false, pregnancyWeeks: 0, isNewborn: false)
            } else {
                return ExactAge(years: years, months: adjustedMonths, days: adjustedDays, isPregnancy: false, pregnancyWeeks: 0, isNewborn: false)
            }
        }
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