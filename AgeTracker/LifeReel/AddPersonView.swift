//
//  AddPersonView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/1/24.
//

import Foundation
import SwiftUI
import PhotosUI

struct AddPersonView: View {
    @ObservedObject var viewModel: PersonViewModel
    @State private var name = ""
    @State private var dateOfBirth: Date?
    @State private var selectedAssets: [PHAsset] = []
    @State private var showImagePicker = false
    @State private var showDatePickerSheet = false
    @State private var showAgeText = false
    @Environment(\.presentationMode) var presentationMode
    
    let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 3)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    TextField("Name", text: $name)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(8)
                    
                    HStack {
                        Text("Date of Birth")
                        Spacer()
                        if let dateOfBirth = dateOfBirth {
                            Text(dateOfBirth, formatter: dateFormatter)
                                .foregroundColor(.gray)
                        } else {
                            Text("Select Date")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showDatePickerSheet = true
                    }
                    
                    // Photo selection grid
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(selectedAssets, id: \.localIdentifier) { asset in
                            AssetThumbnailView(asset: asset, isSelected: true)
                        }
                        
                        Button(action: {
                            showImagePicker = true
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 24))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.top, 20)
                    
                    if showAgeText, let dob = dateOfBirth, !name.isEmpty, !selectedAssets.isEmpty {
                        Text(calculateAge(for: dob, at: selectedAssets.first?.creationDate ?? Date(), name: name))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer(minLength: 300)
                }
                .padding()
            }
            .background(Color(UIColor.secondarySystemBackground))
            .ignoresSafeArea(.keyboard)
            .navigationTitle("Add Person")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveNewPerson()
                }
                .disabled(selectedAssets.isEmpty || name.isEmpty)
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedAssets: $selectedAssets, isPresented: $showImagePicker)
        }
        .sheet(isPresented: $showDatePickerSheet) {
            BirthDaySheet(dateOfBirth: Binding(
                get: { self.dateOfBirth ?? Date() },
                set: { 
                    self.dateOfBirth = $0
                    self.showAgeText = true
                }
            ), isPresented: $showDatePickerSheet)
                .presentationDetents([.height(300)])
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    private func calculateAge(for dob: Date, at photoDate: Date, name: String) -> String {
        let calendar = Calendar.current
        
        if photoDate >= dob {
            let components = calendar.dateComponents([.year, .month, .day], from: dob, to: photoDate)
            let years = components.year ?? 0
            let months = components.month ?? 0
            let days = components.day ?? 0
            
            var ageComponents: [String] = []
            if years > 0 { ageComponents.append("\(years) year\(years == 1 ? "" : "s")") }
            if months > 0 { ageComponents.append("\(months) month\(months == 1 ? "" : "s")") }
            if days > 0 || ageComponents.isEmpty { ageComponents.append("\(days) day\(days == 1 ? "" : "s")") }
            
            return "\(name) is \(ageComponents.joined(separator: ", ")) old"
        } else {
            let weeksBeforeBirth = calendar.dateComponents([.weekOfYear], from: photoDate, to: dob).weekOfYear ?? 0
            let pregnancyWeek = max(40 - weeksBeforeBirth, 0)
            
            if pregnancyWeek > 0 {
                return "\(name)'s mom is \(pregnancyWeek) week\(pregnancyWeek == 1 ? "" : "s") pregnant"
            } else {
                return "\(name)'s mom is not yet pregnant"
            }
        }
    }
    
    private func saveNewPerson() {
        guard let dateOfBirth = dateOfBirth, !selectedAssets.isEmpty else { return }
        
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        
        let group = DispatchGroup()
        var newPerson: Person?
        
        for (index, asset) in selectedAssets.enumerated() {
            group.enter()
            PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, _ in
                if let image = image {
                    if index == 0 {
                        newPerson = Person(name: self.name, dateOfBirth: dateOfBirth)
                        self.viewModel.addPerson(name: self.name, dateOfBirth: dateOfBirth, image: image, dateTaken: asset.creationDate ?? Date())
                    } else if var person = newPerson {
                        self.viewModel.addPhoto(to: &person, image: image, dateTaken: asset.creationDate ?? Date())
                        newPerson = person
                    }
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.presentationMode.wrappedValue.dismiss()
        }
    }
}