//
//  AgeCalculator.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/15/24.
//

import Foundation

struct AgeCalculator {
    static func calculate(for person: Person, at date: Date) -> ExactAge {
        let calendar = Calendar.current
        
        // Convert both dates to start of day
        let startOfDayDate = calendar.startOfDay(for: date)
        let startOfDayBirthDate = calendar.startOfDay(for: person.dateOfBirth)
        
        // Handle the birth day separately
        if calendar.isDate(startOfDayDate, equalTo: startOfDayBirthDate, toGranularity: .day) {
            return ExactAge(years: 0, months: 0, days: 0, isPregnancy: false, pregnancyWeeks: 0, isNewborn: true)
        }
        
        if startOfDayDate < startOfDayBirthDate {
            let components = calendar.dateComponents([.day], from: startOfDayDate, to: startOfDayBirthDate)
            let daysUntilBirth = components.day ?? 0
            let weeksPregnant = min(39, 40 - (daysUntilBirth / 7))
            return ExactAge(years: 0, months: 0, days: 0, isPregnancy: true, pregnancyWeeks: weeksPregnant, isNewborn: false)
        }
        
        let components = calendar.dateComponents([.year, .month, .day], from: startOfDayBirthDate, to: startOfDayDate)
        let totalMonths = (components.year ?? 0) * 12 + (components.month ?? 0)
        
        if person.birthMonthsDisplay == .twentyFourMonths && totalMonths < 24 {
            return ExactAge(
                years: 0,
                months: totalMonths,
                days: components.day ?? 0,
                isPregnancy: false,
                pregnancyWeeks: 0,
                isNewborn: false
            )
        } else {
            return ExactAge(
                years: components.year ?? 0,
                months: components.month ?? 0,
                days: components.day ?? 0,
                isPregnancy: false,
                pregnancyWeeks: 0,
                isNewborn: false
            )
        }
    }

    static func sectionForPhoto(_ photo: Photo, person: Person) -> String {
        let exactAge = calculate(for: person, at: photo.dateTaken)
        let calendar = Calendar.current
        
        if exactAge.isPregnancy {
            switch person.pregnancyTracking {
            case .none:
                return ""
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
        
        // Calculate the age at the start of the year containing the photo
        let yearStart = calendar.date(from: DateComponents(year: calendar.component(.year, from: photo.dateTaken), month: calendar.component(.month, from: person.dateOfBirth), day: calendar.component(.day, from: person.dateOfBirth)))!
        let ageAtYearStart = calendar.dateComponents([.year], from: person.dateOfBirth, to: yearStart).year!
        
        switch person.birthMonthsDisplay {
        case .none:
            return "\(ageAtYearStart) Year\(ageAtYearStart == 1 ? "" : "s")"
        case .twelveMonths:
            if exactAge.years == 0 {
                return "Birth Year"
            } else {
                return "\(ageAtYearStart) Year\(ageAtYearStart == 1 ? "" : "s")"
            }
        case .twentyFourMonths:
            if exactAge.months < 24 {
                return "\(exactAge.months + 1) Month\(exactAge.months == 0 ? "" : "s")"
            } else {
                return "\(ageAtYearStart) Year\(ageAtYearStart == 1 ? "" : "s")"
            }
        }
    }
}

struct ExactAge {
    let years: Int
    let months: Int
    let days: Int
    let isPregnancy: Bool
    let pregnancyWeeks: Int
    let isNewborn: Bool

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
        if days > 0 { parts.append("\(days) day\(days == 1 ? "" : "s")") }
        
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