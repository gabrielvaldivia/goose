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
    let id: UUID
    var name: String
    var dateOfBirth: Date
    var photos: [Photo]
    var syncedAlbumIdentifier: String?
    var birthMonthsDisplay: BirthMonthsDisplay
    var showEmptyStacks: Bool
    var pregnancyTracking: PregnancyTracking

    enum BirthMonthsDisplay: String, Codable, CaseIterable {
        case none = "None"
        case twelveMonths = "12 Months"
        case twentyFourMonths = "24 Months"
    }

    enum SortOrder: String, Codable {
        case latestToOldest
        case oldestToLatest
    }

    enum PregnancyTracking: String, Codable {
        case none, trimesters, weeks
    }

    static func defaultPregnancyTracking(for dateOfBirth: Date) -> PregnancyTracking {
        let calendar = Calendar.current
        let currentDate = Date()
        
        if dateOfBirth <= currentDate {
            return .none
        }
        
        let components = calendar.dateComponents([.month], from: currentDate, to: dateOfBirth)
        let monthsUntilBirth = components.month ?? 0
        
        if monthsUntilBirth > 2 {
            return .weeks
        } else {
            return .trimesters
        }
    }

    init(name: String, dateOfBirth: Date) {
        self.id = UUID()
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.photos = []
        self.syncedAlbumIdentifier = nil
        self.birthMonthsDisplay = .none
        self.showEmptyStacks = true
        self.pregnancyTracking = Person.defaultPregnancyTracking(for: dateOfBirth)
    }

    // Add a new initializer for migration
    init(id: UUID, name: String, dateOfBirth: Date, photos: [Photo], syncedAlbumIdentifier: String?, birthMonthsDisplay: BirthMonthsDisplay, showEmptyStacks: Bool, pregnancyTracking: PregnancyTracking) {
        self.id = id
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.photos = photos
        self.syncedAlbumIdentifier = syncedAlbumIdentifier
        self.birthMonthsDisplay = birthMonthsDisplay
        self.showEmptyStacks = showEmptyStacks
        self.pregnancyTracking = pregnancyTracking
    }

    static func == (lhs: Person, rhs: Person) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.dateOfBirth == rhs.dateOfBirth &&
               lhs.photos == rhs.photos &&
               lhs.syncedAlbumIdentifier == rhs.syncedAlbumIdentifier &&
               lhs.birthMonthsDisplay == rhs.birthMonthsDisplay &&
               lhs.showEmptyStacks == rhs.showEmptyStacks &&
               lhs.pregnancyTracking == rhs.pregnancyTracking
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, dateOfBirth, photos, syncedAlbumIdentifier, birthMonthsDisplay, showEmptyStacks, pregnancyTracking
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        dateOfBirth = try container.decode(Date.self, forKey: .dateOfBirth)
        photos = try container.decode([Photo].self, forKey: .photos)
        syncedAlbumIdentifier = try container.decodeIfPresent(String.self, forKey: .syncedAlbumIdentifier)
        birthMonthsDisplay = try container.decodeIfPresent(BirthMonthsDisplay.self, forKey: .birthMonthsDisplay) ?? .none
        showEmptyStacks = try container.decodeIfPresent(Bool.self, forKey: .showEmptyStacks) ?? true
        pregnancyTracking = try container.decodeIfPresent(PregnancyTracking.self, forKey: .pregnancyTracking) ?? .none
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(dateOfBirth, forKey: .dateOfBirth)
        try container.encode(photos, forKey: .photos)
        try container.encodeIfPresent(syncedAlbumIdentifier, forKey: .syncedAlbumIdentifier)
        try container.encode(birthMonthsDisplay, forKey: .birthMonthsDisplay)
        try container.encode(showEmptyStacks, forKey: .showEmptyStacks)
        try container.encode(pregnancyTracking, forKey: .pregnancyTracking)
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

    init?(asset: PHAsset) {
        guard let creationDate = asset.creationDate else {
            return nil
        }
        self.id = UUID()
        self.assetIdentifier = asset.localIdentifier
        self.dateTaken = creationDate
        self.isVideo = asset.mediaType == .video
    }
}