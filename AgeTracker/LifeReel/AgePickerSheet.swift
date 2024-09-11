//
//  AgePickerSheet.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 9/4/24.
//

import Foundation
import SwiftUI

struct AgePickerSheet: View {
    @State private var years: Int
    @State private var months: Int
    @State private var days: Int
    @Binding var isPresented: Bool
    var onSave: (ExactAge) -> Void

    init(age: ExactAge, isPresented: Binding<Bool>, onSave: @escaping (ExactAge) -> Void) {
        let (y, m, d) = Self.convertToYearsMonthsDays(age: age)
        self._years = State(initialValue: y)
        self._months = State(initialValue: m)
        self._days = State(initialValue: d)
        self._isPresented = isPresented
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    VStack {
                        Text("Years")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Picker("Years", selection: $years) {
                            ForEach(0...100, id: \.self) { year in
                                Text("\(year)").tag(year)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 100, height: 150)
                        .clipped()
                    }

                    VStack {
                        Text("Months")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Picker("Months", selection: $months) {
                            ForEach(0...11, id: \.self) { month in
                                Text("\(month)").tag(month)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 100, height: 150)
                        .clipped()
                    }

                    VStack {
                        Text("Days")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Picker("Days", selection: $days) {
                            ForEach(0...30, id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 100, height: 150)
                        .clipped()
                    }
                }
            }
            .navigationBarItems(
                leading: Button("Cancel") { isPresented = false },
                trailing: Button("Save") {
                    let newAge = ExactAge(
                        years: years, months: months, days: days, isPregnancy: false,
                        pregnancyWeeks: 0, isNewborn: false)
                    onSave(newAge)
                    isPresented = false
                }
            )
            .navigationBarTitle("Select Age", displayMode: .inline)
        }
    }

    private static func convertToYearsMonthsDays(age: ExactAge) -> (Int, Int, Int) {
        if age.isPregnancy {
            return (0, 0, 0)  // Handle pregnancy case if needed
        }

        let totalMonths = age.years * 12 + age.months
        let years = totalMonths / 12
        let remainingMonths = totalMonths % 12

        return (years, remainingMonths, age.days)
    }
}