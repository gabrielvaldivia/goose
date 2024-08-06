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
    @State private var imageMeta: [String: Any]?
    @State private var showDatePickerSheet = false
    @State private var showAgeText = false
    @Environment(\.presentationMode) var presentationMode
    @State private var isLoading = false
    @State private var photoLibraryAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var showingPermissionAlert = false
    
    let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 111, maximum: 111), spacing: 10)
    ]
    
    private var remainingPlaceholders: Int {
        switch selectedAssets.count {
        case 0:
            return 3
        case 1:
            return 2
        default:
            return 1
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) { // Increased spacing between sections
                    // Name section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Name")
                            .font(.headline)
                        TextField("Name", text: $name)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(8)
                    }
                    
                    // Date of Birth section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Date of Birth")
                            .font(.headline)
                        HStack {
                            if let dateOfBirth = dateOfBirth {
                                Text(dateOfBirth, formatter: dateFormatter)
                                    .foregroundColor(.primary)
                            } else {
                                Text("Select Date")
                                    .foregroundColor(Color(UIColor.placeholderText))
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showDatePickerSheet = true
                        }
                    }
                    
                    // Photos section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Photos")
                            .font(.headline)
                        // Photo selection grid
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                            ForEach(selectedAssets, id: \.localIdentifier) { asset in
                                AssetThumbnail(asset: asset) {
                                    removeAsset(asset)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            
                            ForEach(0..<remainingPlaceholders, id: \.self) { _ in
                                Button(action: {
                                    requestPhotoLibraryAuthorization()
                                }) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                                            .foregroundColor(Color(UIColor.placeholderText).opacity(0.5))
                                            .aspectRatio(1, contentMode: .fit)
                                            .frame(height: 111)
                                        
                                        Image(systemName: "plus")
                                            .font(.system(size: 24))
                                            .foregroundColor(Color(UIColor.placeholderText))
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    if showAgeText, let dob = dateOfBirth, !name.isEmpty, !selectedAssets.isEmpty {
                        let photoDate = extractDateTaken(from: imageMeta) ?? Date()
                        Text(calculateAge(for: dob, at: photoDate, name: name))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer(minLength: 300)
                }
                .padding()
            }
            .background(Color(UIColor.secondarySystemBackground))
            .ignoresSafeArea(.keyboard)
            .navigationTitle("Add Someone")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveNewPerson()
                }
                .disabled(selectedAssets.isEmpty || name.isEmpty || dateOfBirth == nil)
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
        .overlay(
            Group {
                if isLoading {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("Saving...")
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                }
            }
        )
        .alert(isPresented: $showingPermissionAlert, content: { permissionAlert })
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
    
    private func loadImages(from assets: [PHAsset]) {
        for asset in assets {
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            
            PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { _, info in
                self.imageMeta = info as? [String: Any]
            }
        }
    }
    
    private func saveNewPerson() {
        guard let dateOfBirth = dateOfBirth, !selectedAssets.isEmpty else { return }
        
        isLoading = true
        print("Selected assets count: \(selectedAssets.count)")
        
        var newPerson = Person(name: self.name, dateOfBirth: dateOfBirth)
        
        for asset in selectedAssets {
            viewModel.addPhoto(to: &newPerson, asset: asset)
        }
        
        viewModel.updatePerson(newPerson)
        print("New person created with \(newPerson.photos.count) photos")
        self.isLoading = false
        self.presentationMode.wrappedValue.dismiss()
    }
    
    private func requestPhotoLibraryAuthorization() {
        switch photoLibraryAuthorizationStatus {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    self.photoLibraryAuthorizationStatus = status
                    if status == .authorized {
                        self.showImagePicker = true
                    }
                }
            }
        case .restricted, .denied:
            showingPermissionAlert = true
        case .authorized, .limited:
            showImagePicker = true
        @unknown default:
            break
        }
    }
    
    private func removeAsset(_ asset: PHAsset) {
        selectedAssets.removeAll { $0.localIdentifier == asset.localIdentifier }
    }
}

extension AddPersonView {
    var permissionAlert: Alert {
        Alert(
            title: Text("Photo Access Required"),
            message: Text("Life Reel needs access to your photo library to select photos for age tracking. Please grant access in Settings."),
            primaryButton: .default(Text("Open Settings"), action: openSettings),
            secondaryButton: .cancel()
        )
    }

    func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

struct AssetThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage?
    var onRemove: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 111, height: 111)
                        .clipped()
                } else {
                    Color.gray
                        .frame(width: 111, height: 111)
                }
            }
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .padding(4)
        }
        .frame(width: 111, height: 111)
        .onAppear(perform: loadImage)
    }
    
    private func loadImage() {
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        option.isSynchronous = true
        manager.requestImage(for: asset, targetSize: CGSize(width: 111, height: 111), contentMode: .aspectFill, options: option) { result, info in
            if let result = result {
                image = result
            }
        }
    }
}