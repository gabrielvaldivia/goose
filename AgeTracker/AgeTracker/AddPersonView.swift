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
    @State private var dateOfBirth = Date()
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var imageMeta: [String: Any]?
    @State private var showDatePickerSheet = false
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
                        Text(dateOfBirth, formatter: dateFormatter)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showDatePickerSheet = true
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
                        let dateTaken = extractDateTaken(from: imageMeta) ?? dateOfBirth
                        viewModel.addPerson(name: name, dateOfBirth: dateOfBirth, image: image, dateTaken: dateTaken)
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
            BirthDaySheet(dateOfBirth: $dateOfBirth, isPresented: $showDatePickerSheet)
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
}