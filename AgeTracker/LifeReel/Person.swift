//
//  Person.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/1/24.
//

import Foundation
import UIKit
import AVFoundation
import Photos

struct Person: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var name: String
    var dateOfBirth: Date
    var photos: [Photo] = []
    var syncedAlbumIdentifier: String?
    var birthMonthsDisplay: BirthMonthsDisplay = .none

    enum BirthMonthsDisplay: String, Codable, CaseIterable {
        case none = "None"
        case twelveMonths = "12 Months"
        case twentyFourMonths = "24 Months"
    }

    enum SortOrder: String, Codable {
        case latestToOldest
        case oldestToLatest
    }

    init(name: String, dateOfBirth: Date) {
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.syncedAlbumIdentifier = nil
        self.birthMonthsDisplay = .none
    }

    // Add a new initializer for migration
    init(id: UUID, name: String, dateOfBirth: Date, photos: [Photo], syncedAlbumIdentifier: String?, birthMonthsDisplay: BirthMonthsDisplay) {
        self.id = id
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.photos = photos
        self.syncedAlbumIdentifier = syncedAlbumIdentifier
        self.birthMonthsDisplay = birthMonthsDisplay
    }

    static func == (lhs: Person, rhs: Person) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.dateOfBirth == rhs.dateOfBirth &&
               lhs.photos == rhs.photos &&
               lhs.syncedAlbumIdentifier == rhs.syncedAlbumIdentifier &&
               lhs.birthMonthsDisplay == rhs.birthMonthsDisplay
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, dateOfBirth, photos, syncedAlbumIdentifier, birthMonthsDisplay
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        dateOfBirth = try container.decode(Date.self, forKey: .dateOfBirth)
        photos = try container.decode([Photo].self, forKey: .photos)
        syncedAlbumIdentifier = try container.decodeIfPresent(String.self, forKey: .syncedAlbumIdentifier)
        birthMonthsDisplay = try container.decodeIfPresent(BirthMonthsDisplay.self, forKey: .birthMonthsDisplay) ?? .none
    }
}

struct Photo: Identifiable, Codable, Equatable {
    let id: UUID
    let assetIdentifier: String
    var dateTaken: Date
    let isVideo: Bool

    var image: UIImage? {
        guard !isVideo else { return nil }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = result.firstObject else { return nil }
        
        let manager = PHImageManager.default()
        var image: UIImage?
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .exact
        
        manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { result, _ in
            image = result
        }
        
        return image
    }

    var videoURL: URL? {
        guard isVideo else { return nil }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = result.firstObject else { return nil }
        
        var videoURL: URL?
        let options = PHVideoRequestOptions()
        options.version = .original
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            if let urlAsset = avAsset as? AVURLAsset {
                videoURL = urlAsset.url
            }
        }
        
        return videoURL
    }

    init(asset: PHAsset) {
        self.id = UUID()
        self.assetIdentifier = asset.localIdentifier
        self.dateTaken = asset.creationDate ?? Date()
        self.isVideo = asset.mediaType == .video
    }
}