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
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var imageMeta: [String: Any]?
    @State private var showDatePickerSheet = false
    @State private var showAgeText = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Photo selection section
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 100, height: 100)
                        
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "camera")
                                .font(.system(size: 24))
                                .foregroundColor(.blue)
                        }
                    }
                    .onTapGesture {
                        showImagePicker = true
                    }
                    
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
                    
                    // Add the age text here
                    if showAgeText, let dob = dateOfBirth, !name.isEmpty, let image = selectedImage {
                        let photoDate = extractDateTaken(from: imageMeta) ?? Date()
                        Text(calculateAge(for: dob, at: photoDate, name: name))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer(minLength: 300) // Add extra space at the bottom
                }
                .padding()
            }
            .background(Color(UIColor.secondarySystemBackground))
            .ignoresSafeArea(.keyboard) // Ignore the keyboard safe area
            .navigationTitle("Add Person")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    if let image = selectedImage {
                        let dateTaken = extractDateTaken(from: imageMeta) ?? dateOfBirth ?? Date()
                        viewModel.addPerson(name: name, dateOfBirth: dateOfBirth ?? Date(), image: image, dateTaken: dateTaken)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .disabled(selectedImage == nil || name.isEmpty)
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage, imageMeta: $imageMeta, isPresented: $showImagePicker)
        }
        .sheet(isPresented: $showDatePickerSheet) {
            BirthDaySheet(dateOfBirth: Binding(
                get: { self.dateOfBirth ?? Date() },
                set: { 
                    self.dateOfBirth = $0
                    self.showAgeText = true
                }
            ), isPresented: $showDatePickerSheet)
                .presentationDetents([.height(300)]) // Make it a small sheet
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    private func extractDateTaken(from metadata: [String: Any]?) -> Date? {
        if let dateTimeOriginal = metadata?["DateTimeOriginal"] as? String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            return dateFormatter.date(from: dateTimeOriginal)
        }
        return nil
    }
    
    // Updated function to calculate age or pregnancy stage
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
}