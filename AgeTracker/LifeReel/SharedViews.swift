//
//  SharedViews.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/9/24.
//

import Foundation
import Photos
import PhotosUI
import SwiftUI

// PhotoUtils: Utility struct containing helper functions for photo management and organization
public struct PhotoUtils {

    static func groupAndSortPhotos(for person: Person) -> [(String, [Photo])] {
        let sortedPhotos = person.photos.sorted { $0.dateTaken < $1.dateTaken }
        var groupedPhotos: [String: [Photo]] = [:]

        for photo in sortedPhotos {
            let sectionTitle = sectionForPhoto(photo, person: person)
            groupedPhotos[sectionTitle, default: []].append(photo)
        }

        return groupedPhotos.sorted { $0.key < $1.key }
    }

    static func sortedGroupedPhotosForAll(person: Person, viewModel: PersonViewModel) -> [(
        String, [Photo]
    )] {
        return groupAndSortPhotos(for: person)
    }

    static func sortedGroupedPhotosForAllIncludingEmpty(person: Person, viewModel: PersonViewModel)
        -> [(String, [Photo])]
    {
        let allStacks = getAllMilestones(for: person)
        let groupedPhotos = Dictionary(grouping: person.photos) { photo in
            PhotoUtils.sectionForPhoto(photo, person: person)
        }

        let completeGroupedPhotos = allStacks.map { stack in
            (stack, groupedPhotos[stack] ?? [])
        }

        return completeGroupedPhotos.sorted { $0.0 < $1.0 }
    }

    static func getAllMilestones(for person: Person) -> [String] {
        var stacks: [String] = []
        let calendar = Calendar.current
        let currentDate = Date()

        let endDate = min(person.dateOfBirth, currentDate)
        let pregnancyStartDate =
            calendar.date(byAdding: .month, value: -9, to: person.dateOfBirth) ?? person.dateOfBirth

        // Include pregnancy stacks only if tracking is set to trimesters or weeks
        switch person.pregnancyTracking {
        case .trimesters:
            let trimesterDuration = TimeInterval(91 * 24 * 60 * 60)  // 91 days in seconds
            for i in 0..<3 {
                let trimesterStart = pregnancyStartDate.addingTimeInterval(
                    Double(i) * trimesterDuration)
                if trimesterStart < endDate {
                    stacks.append(["First Trimester", "Second Trimester", "Third Trimester"][i])
                }
            }
        case .weeks:
            for week in 1...40 {
                let weekStart = pregnancyStartDate.addingTimeInterval(
                    Double(week - 1) * 7 * 24 * 60 * 60)
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
            let ageComponents = calendar.dateComponents(
                [.year, .month], from: person.dateOfBirth, to: currentDate)
            let currentAgeInMonths = max(
                0, (ageComponents.year ?? 0) * 12 + (ageComponents.month ?? 0))
            let currentAgeInYears = ageComponents.year ?? 0

            switch person.birthMonthsDisplay {
            case .none:
                stacks.append("Birth Year")
                stacks.append(
                    contentsOf: (1...currentAgeInYears).map { "\($0) Year\($0 == 1 ? "" : "s")" })
            case .twelveMonths:
                stacks.append("Birth Month")
                let monthsToShow = min(11, currentAgeInMonths)
                stacks.append(
                    contentsOf: (1...monthsToShow).map { "\($0) Month\($0 == 1 ? "" : "s")" })
                stacks.append(
                    contentsOf: (1...currentAgeInYears).map { "\($0) Year\($0 == 1 ? "" : "s")" })
            case .twentyFourMonths:
                stacks.append("Birth Month")
                let monthsToShow = min(23, currentAgeInMonths)
                stacks.append(
                    contentsOf: (1...monthsToShow).map { "\($0) Month\($0 == 1 ? "" : "s")" })
                if currentAgeInYears >= 2 {
                    stacks.append(contentsOf: (2...currentAgeInYears).map { "\($0) Years" })
                }
            }
        }

        return stacks
    }

    static func getDateRangeForSection(_ section: String, person: Person) throws -> (
        start: Date, end: Date
    ) {
        let calendar = Calendar.current
        let birthDate = person.dateOfBirth

        switch section {
        case "Pregnancy":
            let start = calendar.date(byAdding: .month, value: -9, to: birthDate) ?? birthDate
            return (start: start, end: birthDate)
        case "First Trimester":
            let pregnancyStart =
                calendar.date(byAdding: .month, value: -9, to: birthDate) ?? birthDate
            let end = calendar.date(byAdding: .month, value: 3, to: pregnancyStart) ?? birthDate
            return (start: pregnancyStart, end: end)
        case "Second Trimester":
            let pregnancyStart =
                calendar.date(byAdding: .month, value: -9, to: birthDate) ?? birthDate
            let start = calendar.date(byAdding: .month, value: 3, to: pregnancyStart) ?? birthDate
            let end = calendar.date(byAdding: .month, value: 6, to: pregnancyStart) ?? birthDate
            return (start: start, end: end)
        case "Third Trimester":
            let pregnancyStart =
                calendar.date(byAdding: .month, value: -9, to: birthDate) ?? birthDate
            let start = calendar.date(byAdding: .month, value: 6, to: pregnancyStart) ?? birthDate
            return (start: start, end: birthDate)
        case "Birth Month":
            let start = person.dateOfBirth
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: start)!
            let end = calendar.date(byAdding: .day, value: -1, to: nextMonth)!
            return (start: start, end: end)
        case "Birth Year":
            let start = calendar.startOfDay(for: birthDate)
            let end = calendar.date(byAdding: .year, value: 1, to: start)!
            let adjustedEnd = calendar.date(byAdding: .day, value: -1, to: end)!
            return (start: start, end: adjustedEnd)
        default:
            if section.contains("Month") {
                if let months = Int(section.components(separatedBy: " ").first ?? "") {
                    let start =
                        calendar.date(byAdding: .month, value: months - 1, to: birthDate)
                        ?? birthDate
                    let end =
                        calendar.date(byAdding: .month, value: months, to: birthDate) ?? birthDate
                    return (start: start, end: end)
                }
            } else if section.contains("Year") {
                if let years = Int(section.components(separatedBy: " ").first ?? "") {
                    let targetYear = calendar.component(.year, from: birthDate) + years
                    let startComponents = DateComponents(
                        year: targetYear, month: calendar.component(.month, from: birthDate),
                        day: calendar.component(.day, from: birthDate))
                    let start = calendar.date(from: startComponents) ?? birthDate
                    let end = calendar.date(byAdding: .year, value: 1, to: start) ?? birthDate
                    let adjustedEnd = calendar.date(byAdding: .day, value: -1, to: end) ?? end
                    return (start: start, end: adjustedEnd)
                }
            } else if section.starts(with: "Week") {
                if let week = Int(section.components(separatedBy: " ").last ?? "") {
                    let pregnancyStart =
                        calendar.date(byAdding: .month, value: -9, to: birthDate) ?? birthDate
                    let start =
                        calendar.date(byAdding: .day, value: (week - 1) * 7, to: pregnancyStart)
                        ?? pregnancyStart
                    let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
                    let adjustedEnd = calendar.date(byAdding: .second, value: -1, to: end) ?? end
                    return (start: start, end: adjustedEnd)
                }
            }
            throw NSError(domain: "Invalid section", code: 0, userInfo: nil)
        }
    }

    static func sectionForPhoto(_ photo: Photo, person: Person) -> String {
        let exactAge = AgeCalculator.calculate(for: person, at: photo.dateTaken)
        let calendar = Calendar.current

        if exactAge.isPregnancy {
            switch person.pregnancyTracking {
            case .none:
                return ""  // Return an empty string for photos before birth when tracking is off
            case .trimesters:
                let trimester = (exactAge.pregnancyWeeks - 1) / 13 + 1
                return "\(["First", "Second", "Third"][trimester - 1]) Trimester"
            case .weeks:
                return "Week \(exactAge.pregnancyWeeks)"
            }
        }

        // Check if the photo is within the birth month
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: person.dateOfBirth)!
        let endOfBirthMonth = calendar.date(byAdding: .day, value: -1, to: nextMonth)!
        if photo.dateTaken >= person.dateOfBirth && photo.dateTaken <= endOfBirthMonth {
            return "Birth Month"
        }

        switch person.birthMonthsDisplay {
        case .none:
            return exactAge.years == 0
                ? "Birth Year" : "\(exactAge.years) Year\(exactAge.years == 1 ? "" : "s")"
        case .twelveMonths:
            if exactAge.years == 0 {
                return "\(exactAge.months) Month\(exactAge.months == 1 ? "" : "s")"
            } else if exactAge.years == 1 && exactAge.months == 0 {
                return "1 Year"
            } else {
                return "\(exactAge.years) Year\(exactAge.years == 1 ? "" : "s")"
            }
        case .twentyFourMonths:
            if exactAge.months < 24 {
                return "\(exactAge.months) Month\(exactAge.months == 1 ? "" : "s")"
            } else {
                return "\(exactAge.years) Year\(exactAge.years == 1 ? "" : "s")"
            }
        }
    }

    static func getGeneralAgeStacks(for person: Person) -> [String] {
        var stacks: [String] = ["Pregnancy"]
        let calendar = Calendar.current
        let currentDate = Date()
        let ageComponents = calendar.dateComponents(
            [.year, .month], from: person.dateOfBirth, to: currentDate)
        let currentAgeInMonths = (ageComponents.year ?? 0) * 12 + (ageComponents.month ?? 0)
        let currentAgeInYears = ageComponents.year ?? 0

        switch person.birthMonthsDisplay {
        case .none:
            stacks.append("Birth Year")
            stacks.append(
                contentsOf: (1...currentAgeInYears).map { "\($0) Year\($0 == 1 ? "" : "s")" })
        case .twelveMonths:
            stacks.append("Birth Month")
            let monthsToShow = min(11, currentAgeInMonths)
            stacks.append(contentsOf: (0...monthsToShow).map { "\($0) Month\($0 == 1 ? "" : "s")" })
            if currentAgeInMonths >= 12 {
                stacks.append("1 Year")
                if currentAgeInYears > 1 {
                    stacks.append(contentsOf: (2...currentAgeInYears).map { "\($0) Years" })
                }
            }
        case .twentyFourMonths:
            stacks.append("Birth Month")
            let monthsToShow = min(23, currentAgeInMonths)
            stacks.append(contentsOf: (0...monthsToShow).map { "\($0) Month\($0 == 1 ? "" : "s")" })
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

// EmptyStateView: Displays a message when there are no photos
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

// Circular button component
struct CircularButton: View {
    let systemName: String
    let action: () -> Void
    let size: CGFloat
    var backgroundColor: Color = Color.gray.opacity(0.2)
    var iconColor: Color?
    var blurEffect: Bool = false
    var iconSize: CGFloat?

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(backgroundColor)

                if blurEffect {
                    VisualEffectView(
                        effect: UIBlurEffect(style: colorScheme == .dark ? .dark : .light)
                    )
                    .clipShape(Circle())
                }

                Image(systemName: systemName)
                    .font(.system(size: iconSize ?? (size * 0.4), weight: .bold))
                    .foregroundColor(iconColor ?? .primary)
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}

// Segmented control for switching between grid and timeline views
struct SegmentedControlView: View {
    @Binding var selectedTab: Int
    @Binding var animationDirection: UIPageViewController.NavigationDirection
    @Namespace private var animation
    @Environment(\.colorScheme) var colorScheme

    let options = ["person.crop.rectangle.stack", "square.grid.2x2"]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options.indices, id: \.self) { index in
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.15)) {
                        animationDirection = index > selectedTab ? .forward : .reverse
                        selectedTab = index
                    }
                }) {
                    Image(systemName: options[index])
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 60, height: 36)
                        .background(
                            ZStack {
                                if selectedTab == index {
                                    Capsule()
                                        .fill(Color.primary.opacity(0.3))
                                        .matchedGeometryEffect(id: "SelectedSegment", in: animation)
                                }
                            }
                        )
                        .foregroundColor(
                            colorScheme == .dark
                                ? (selectedTab == index ? .white : .white.opacity(0.5))
                                : (selectedTab == index ? .white : .black.opacity(0.5)))
                }
            }
        }
        .padding(4)
        .background(
            ZStack {
                VisualEffectView(effect: UIBlurEffect(style: colorScheme == .dark ? .dark : .light))
                if colorScheme == .light {
                    Color.black.opacity(0.1)
                }
            }
        )
        .clipShape(Capsule())
    }
}

// Bottom control bar with share, view toggle, and add photo buttons
struct BottomControls: View {
    let shareAction: () -> Void
    let addPhotoAction: () -> Void
    @Binding var selectedTab: Int
    @Binding var animationDirection: UIPageViewController.NavigationDirection
    let options: [String]

    var body: some View {
        HStack {
            CircularButton(
                systemName: "square.and.arrow.up",
                action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    shareAction()
                },
                size: 40,
                iconSize: nil
            )
            Spacer()

            SegmentedControlView(selectedTab: $selectedTab, animationDirection: $animationDirection)

            Spacer()

            CircularButton(
                systemName: "plus",
                action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    addPhotoAction()
                },
                size: 50,
                backgroundColor: .blue,
                iconSize: nil
            )
        }
        .padding(.horizontal)
    }
}

// Scrubber handle
struct ScrubberHandle: View {
    let tapAreaSize: CGFloat
    let lineHeight: CGFloat = 2
    let tapAreaHeight: CGFloat = 60
    let blueLineWidth: CGFloat = 14

    var body: some View {
        ZStack {
            // Clear background rectangle
            Rectangle()
                .fill(Color.clear)
                .frame(width: tapAreaSize, height: tapAreaHeight)

            // Blue line
            Rectangle()
                .fill(Color.blue)
                .frame(width: blueLineWidth, height: lineHeight)
                .offset(x: (tapAreaSize - blueLineWidth) / 2)

            // Transparent overlay for larger tap area
            Color.clear
                .frame(width: tapAreaSize, height: tapAreaHeight)
                .contentShape(Rectangle())
        }
    }
}

// UIViewRepresentable for visual effects
struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
        UIVisualEffectView()
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) {
        uiView.effect = effect
    }
}
