//
//  AddPersonView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/1/24.
//

import Foundation
import SwiftUI

struct AddPersonView: View {
    @ObservedObject var viewModel: PersonViewModel
    @State private var name = ""
    @State private var dateOfBirth = Date()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Name", text: $name)
                DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
            }
            .navigationTitle("Add Person")
            .toolbar {
                Button("Save") {
                    viewModel.addPerson(name: name, dateOfBirth: dateOfBirth)
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}