//
//  ImagePicker.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/1/24.
//

import Foundation
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Photos

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedAssets: [PHAsset]
    @Binding var isPresented: Bool
    var onSelect: ([PHAsset]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            let identifiers = results.compactMap(\.assetIdentifier)
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
            let assets = fetchResult.objects(at: IndexSet(integersIn: 0..<fetchResult.count))
            parent.selectedAssets = assets
            parent.onSelect(assets)
            parent.isPresented = false
            print("ImagePicker selected \(assets.count) assets")
        }
    }
}