//
//  DatePickerSheet.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 9/4/24.
//

import Foundation
import SwiftUI



struct DatePickerSheet: View {
    @Binding var date: Date
    @Binding var isPresented: Bool
    var onSave: (Date) -> Void

    var body: some View {
        NavigationView {
            VStack {
                DatePicker("Select Date", selection: $date, displayedComponents: [.date])
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
            }
            .navigationBarItems(
                leading: Button("Cancel") { isPresented = false },
                trailing: Button("Save") {
                    onSave(date)
                    isPresented = false
                }
            )
            .navigationBarTitle("Select Date", displayMode: .inline)
        }
    }
}