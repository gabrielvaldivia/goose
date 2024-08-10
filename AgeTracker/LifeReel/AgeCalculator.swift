//
//  AgeCalculator.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/4/24.
//

import Foundation

struct AgeCalculator {
    static func calculateAge(for person: Person, at date: Date) -> (years: Int, months: Int, days: Int) {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year, .month, .day], from: person.dateOfBirth, to: date)
        return (ageComponents.year ?? 0, ageComponents.month ?? 0, ageComponents.day ?? 0)
    }

    static func calculateAgeString(for person: Person, at date: Date) -> String {
        let calendar = Calendar.current
        let birthDate = person.dateOfBirth
        
        if date >= birthDate {
            let components = calendar.dateComponents([.year, .month, .day], from: birthDate, to: date)
            let years = components.year ?? 0
            let months = components.month ?? 0
            let days = components.day ?? 0
            
            if years == 0 && months == 0 && days == 0 {
                return "Newborn"
            }
            
            var ageComponents: [String] = []
            
            // Special case: If age is less than 1 year, show months and days
            if years == 0 {
                if months > 0 {
                    ageComponents.append("\(months) month\(months == 1 ? "" : "s")")
                }
                if days > 0 || ageComponents.isEmpty {
                    ageComponents.append("\(days) day\(days == 1 ? "" : "s")")
                }
            } else {
                switch person.ageFormat {
                case .full:
                    if years > 0 { ageComponents.append("\(years) year\(years == 1 ? "" : "s")") }
                    if months > 0 { ageComponents.append("\(months) month\(months == 1 ? "" : "s")") }
                    if days > 0 { ageComponents.append("\(days) day\(days == 1 ? "" : "s")") }
                case .yearMonth:
                    if years > 0 { ageComponents.append("\(years) year\(years == 1 ? "" : "s")") }
                    if months > 0 || ageComponents.isEmpty { ageComponents.append("\(months) month\(months == 1 ? "" : "s")") }
                case .yearOnly:
                    ageComponents.append("\(years) year\(years == 1 ? "" : "s")")
                }
            }
            
            return ageComponents.joined(separator: ", ")
        } else {
            let componentsBeforeBirth = calendar.dateComponents([.day], from: date, to: birthDate)
            let daysBeforeBirth = componentsBeforeBirth.day ?? 0
            let weeksBeforeBirth = daysBeforeBirth / 7
            let remainingDays = daysBeforeBirth % 7
            let pregnancyWeek = max(40 - weeksBeforeBirth, 0)
            
            if pregnancyWeek == 40 {
                return "Newborn"
            } else if pregnancyWeek > 0 {
                let weekString = "\(pregnancyWeek) week\(pregnancyWeek == 1 ? "" : "s")"
                let dayString = "\(remainingDays) day\(remainingDays == 1 ? "" : "s")"
                
                if remainingDays > 0 {
                    return "\(weekString) and \(dayString)"
                } else {
                    return weekString
                }
            } else {
                return "Before pregnancy"
            }
        }
    }
}