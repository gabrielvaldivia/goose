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
        
        if calendar.isDate(date, inSameDayAs: birthDate) {
            return "Birth day"
        }
        
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
                if years > 0 { ageComponents.append("\(years) year\(years == 1 ? "" : "s")") }
                if months > 0 { ageComponents.append("\(months) month\(months == 1 ? "" : "s")") }
                if days > 0 { ageComponents.append("\(days) day\(days == 1 ? "" : "s")") }
            }
            
            return ageComponents.joined(separator: ", ")
        } else {
            let componentsBeforeBirth = calendar.dateComponents([.day], from: date, to: birthDate)
            let daysBeforeBirth = componentsBeforeBirth.day ?? 0
            let weeksPregnant = 40 - (daysBeforeBirth / 7)
            
            if weeksPregnant > 0 {
                return "\(weeksPregnant) week\(weeksPregnant == 1 ? "" : "s") pregnant"
            } else {
                return "Before pregnancy"
            }
        }
    }
}