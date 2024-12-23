//
//  NewLifeReelView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/1/24.
//

import Foundation
import PhotosUI
import SwiftUI

struct NewLifeReelView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var isPresented: Bool
    var onboardingMode: Bool
    @State private var name = ""
    @State private var dateOfBirth: Date?
    @State private var selectedAssets: [PHAsset] = []
    @State private var showImagePicker = false
    @State private var imageMeta: [String: Any]?
    @State private var showDatePickerSheet = false
    @State private var showAgeText = false
    @State private var isLoading = false
    @State private var photoLibraryAuthorizationStatus = PHPhotoLibrary.authorizationStatus(
        for: .readWrite)
    @State private var showingPermissionAlert = false
    @State private var navigateToPersonDetail: Person?
    @State private var shouldNavigateToDetail = false

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

    init(viewModel: PersonViewModel, isPresented: Binding<Bool>, onboardingMode: Bool) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.onboardingMode = onboardingMode
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .center, spacing: 30) {
                    nameAndBirthDateView
                    photosView
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .ignoresSafeArea(.keyboard)
            .gesture(
                DragGesture().onChanged { _ in
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            )
            .navigationTitle("New Life Reel")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(onboardingMode)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !onboardingMode {
                        Button("Cancel") {
                            isPresented = false
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveNewPerson()
                    }
                    .disabled(name.isEmpty || dateOfBirth == nil || selectedAssets.isEmpty)
                }
            }
            .onChange(of: viewModel.people.count) { oldValue, newValue in
                if newValue > oldValue, let newPerson = viewModel.people.last {
                    viewModel.setSelectedPerson(newPerson)
                    isPresented = false
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(
                selectedAssets: $selectedAssets,
                isPresented: $showImagePicker,
                onSelect: { assets in
                    self.selectedAssets = assets
                    loadImages(from: assets)
                }
            )
            .edgesIgnoringSafeArea(.all)
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showDatePickerSheet) {
            DatePickerSheet(
                date: Binding(
                    get: { self.dateOfBirth ?? Date() },
                    set: {
                        self.dateOfBirth = $0
                        self.showAgeText = true
                    }
                ),
                isPresented: $showDatePickerSheet,
                onSave: { selectedDate in
                    // Add any additional logic you want to perform on save
                    self.dateOfBirth = selectedDate
                }
            )
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

    private var nameAndBirthDateView: some View {
        VStack(alignment: .leading, spacing: 30) {
            // Name section
            VStack(alignment: .leading, spacing: 10) {
                Text("Name")
                    .font(.headline)
                TextField("Name", text: $name)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(8)
            }

            // Date of Birth section
            VStack(alignment: .leading, spacing: 10) {
                Text("Date of birth")
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
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(8)
                .contentShape(Rectangle())
                .onTapGesture {
                    showDatePickerSheet = true
                }
            }

        }
    }

    private var photosView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add some of your favorite memories")
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: columns, alignment: .center, spacing: 10) {
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
            .frame(maxWidth: .infinity)
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

    private func loadImages(from assets: [PHAsset]) {
        for asset in assets {
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat

            PHImageManager.default().requestImage(
                for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit,
                options: options
            ) { _, info in
                self.imageMeta = info as? [String: Any]
            }
        }
    }

    private func saveNewPerson() {
        guard !name.isEmpty, let dateOfBirth = dateOfBirth, !selectedAssets.isEmpty else { return }

        isLoading = true

        let ageInMonths =
            Calendar.current.dateComponents([.month], from: dateOfBirth, to: Date()).month ?? 0
        let birthMonthsDisplay =
            ageInMonths < 24
            ? Person.BirthMonthsDisplay.twelveMonths : Person.BirthMonthsDisplay.none

        let newPerson = Person(
            name: self.name, dateOfBirth: dateOfBirth, birthMonthsDisplay: birthMonthsDisplay)

        // First add the person to the array
        viewModel.people.append(newPerson)
        viewModel.savePeople()

        // Then add photos to the person
        for asset in selectedAssets {
            if let index = viewModel.people.firstIndex(where: { $0.id == newPerson.id }) {
                viewModel.addPhoto(to: &viewModel.people[index], asset: asset)
            }
        }

        // Get the final version with photos
        if let finalPerson = viewModel.people.first(where: { $0.id == newPerson.id }) {
            // Set selected person and mark onboarding as completed
            viewModel.selectedPerson = finalPerson
            viewModel.setLastOpenedPerson(finalPerson)

            if onboardingMode {
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            }

            // First navigate to the detail view
            viewModel.navigateToPersonDetail(finalPerson)
            // Then dismiss the sheet
            isPresented = false
        }

        self.isLoading = false
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

extension NewLifeReelView {
    var permissionAlert: Alert {
        Alert(
            title: Text("Photo Access Required"),
            message: Text(
                "Life Reel needs access to your photo library to select photos for age tracking. Please grant access in Settings."
            ),
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
        manager.requestImage(
            for: asset, targetSize: CGSize(width: 111, height: 111), contentMode: .aspectFill,
            options: option
        ) { result, info in
            if let result = result {
                image = result
            }
        }
    }
}
