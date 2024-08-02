//
//  BulkImportView.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/2/24.
//

import Foundation
import SwiftUI
import Photos

struct BulkImportView: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    @State private var albums: [PHAssetCollection] = []
    @State private var selectedAlbum: PHAssetCollection?
    @State private var selectedPhotos: [PHAsset] = []
    @State private var selectedAssets: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading...")
                } else if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                } else {
                    Picker("Select Album", selection: $selectedAlbum) {
                        Text("Choose an album").tag(nil as PHAssetCollection?)
                        ForEach(albums, id: \.localIdentifier) { album in
                            Text(album.localizedTitle ?? "Untitled Album").tag(album as PHAssetCollection?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding()
                    
                    if let _ = selectedAlbum {
                        List {
                            ForEach(selectedPhotos, id: \.localIdentifier) { asset in
                                AssetThumbnailView(asset: asset, isSelected: binding(for: asset))
                            }
                        }
                    } else {
                        Text("Please select an album")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationBarTitle("Bulk Import")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Import") {
                    importSelectedPhotos()
                }
                .disabled(selectedAssets.isEmpty)
            )
        }
        .onAppear(perform: fetchAlbums)
        .onChange(of: selectedAlbum) { newAlbum in
            fetchPhotosFromSelectedAlbum()
        }
    }
    
    private func binding(for asset: PHAsset) -> Binding<Bool> {
        Binding(
            get: { self.selectedAssets.contains(asset.localIdentifier) },
            set: { isSelected in
                if isSelected {
                    self.selectedAssets.insert(asset.localIdentifier)
                } else {
                    self.selectedAssets.remove(asset.localIdentifier)
                }
            }
        )
    }
    
    private func fetchAlbums() {
        isLoading = true
        errorMessage = nil
        viewModel.fetchAlbums { result in
            isLoading = false
            switch result {
            case .success(let fetchedAlbums):
                self.albums = fetchedAlbums
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func fetchPhotosFromSelectedAlbum() {
        guard let album = selectedAlbum else { return }
        isLoading = true
        errorMessage = nil
        viewModel.fetchPhotosFromAlbum(album) { result in
            isLoading = false
            switch result {
            case .success(let assets):
                selectedPhotos = assets
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func importSelectedPhotos() {
        let assetsToImport = selectedPhotos.filter { selectedAssets.contains($0.localIdentifier) }
        print("Importing \(assetsToImport.count) photos")
        
        for asset in assetsToImport {
            let options = PHImageRequestOptions()
            options.isSynchronous = true
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, info in
                if let image = image {
                    print("Successfully retrieved image for asset: \(asset.localIdentifier)")
                    print("Image size: \(image.size.width) x \(image.size.height)")
                    viewModel.addPhoto(to: &person, image: image, dateTaken: asset.creationDate ?? Date())
                } else {
                    print("Failed to import photo for asset: \(asset.localIdentifier)")
                    if let error = info?[PHImageErrorKey] as? Error {
                        print("Error: \(error.localizedDescription)")
                    }
                    if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                        print("Image is degraded")
                    }
                }
            }
        }
        
        if let updatedPerson = viewModel.people.first(where: { $0.id == person.id }) {
            person = updatedPerson
        }
        
        print("Import completed")
        presentationMode.wrappedValue.dismiss()
    }
}

struct AssetThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?
    @Binding var isSelected: Bool
    
    var body: some View {
        HStack {
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Color.gray
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            Spacer()
            Toggle("", isOn: $isSelected)
        }
        .onAppear(perform: loadImage)
    }
    
    private func loadImage() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 100, height: 100), contentMode: .aspectFill, options: options) { result, _ in
            image = result
        }
    }
}