//
//  PhotoDatePicker.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/6/24.
//

import Foundation

import SwiftUI

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
        }
        .background(Color(UIColor.systemBackground))
    }
}