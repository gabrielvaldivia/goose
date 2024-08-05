//
//  PersonViewModel.swift
//  AgeTracker
//
//  Created by Gabriel Valdivia on 8/1/24.
//

import Foundation
import UIKit
import Photos

class PersonViewModel: ObservableObject {
    @Published var people: [Person] = []
    
    init() {
        loadPeople()
        
        // Check if photo migration is needed
        if !UserDefaults.standard.bool(forKey: "photoMigrationCompleted") {
            migratePhotos()
            UserDefaults.standard.set(true, forKey: "photoMigrationCompleted")
        }
    }
    
    func addPerson(name: String, dateOfBirth: Date, asset: PHAsset) {
        var newPerson = Person(name: name, dateOfBirth: dateOfBirth)
        addPhoto(to: &newPerson, asset: asset)
        people.append(newPerson)
        savePeople()
    }
    
    func addPhoto(to person: inout Person, asset: PHAsset) {
        print("Adding photo to \(person.name) with date: \(asset.creationDate ?? Date())")
        let newPhoto = Photo(asset: asset)
        if !person.photos.contains(where: { $0.assetIdentifier == newPhoto.assetIdentifier }) {
            person.photos.append(newPhoto)
            person.photos.sort { $0.dateTaken < $1.dateTaken }
            if let index = people.firstIndex(where: { $0.id == person.id }) {
                people[index] = person
                savePeople()
                objectWillChange.send()
                print("Photo added successfully. Total photos for \(person.name): \(person.photos.count)")
            } else {
                print("Failed to find person \(person.name) in people array")
            }
        } else {
            print("Photo with asset identifier \(newPhoto.assetIdentifier) already exists for \(person.name)")
        }
    }
    
    func addPhoto(to person: inout Person, photo: Photo) {
        print("Adding photo to \(person.name) with date: \(photo.dateTaken)")
        if !person.photos.contains(where: { $0.assetIdentifier == photo.assetIdentifier }) {
            person.photos.append(photo)
            person.photos.sort { $0.dateTaken < $1.dateTaken }
            if let index = people.firstIndex(where: { $0.id == person.id }) {
                people[index] = person
                savePeople()
                objectWillChange.send()
                print("Photo added successfully. Total photos for \(person.name): \(person.photos.count)")
            } else {
                print("Failed to find person \(person.name) in people array")
            }
        } else {
            print("Photo with asset identifier \(photo.assetIdentifier) already exists for \(person.name)")
        }
    }
    
    func deletePerson(at offsets: IndexSet) {
        people.remove(atOffsets: offsets)
        savePeople()
    }
    
    func deletePerson(_ person: Person) {
        if let index = people.firstIndex(where: { $0.id == person.id }) {
            people.remove(at: index)
            savePeople()
        }
    }
    
    func calculateAge(for person: Person, at date: Date) -> (years: Int, months: Int, days: Int) {
        return AgeCalculator.calculateAge(for: person, at: date)
    }
    
    func updatePerson(_ updatedPerson: Person) {
        if let index = people.firstIndex(where: { $0.id == updatedPerson.id }) {
            people[index] = updatedPerson
        } else {
            people.append(updatedPerson)
        }
        savePeople()
        objectWillChange.send()
    }
    
    private func savePeople() {
        if let encoded = try? JSONEncoder().encode(people) {
            UserDefaults.standard.set(encoded, forKey: "SavedPeople")
        }
    }
    
    private func loadPeople() {
        if let savedPeople = UserDefaults.standard.data(forKey: "SavedPeople") {
            if let decodedPeople = try? JSONDecoder().decode([Person].self, from: savedPeople) {
                people = decodedPeople
            }
        }
    }
    
    // New function to fetch photos for a person
    func fetchPhotosForPerson(_ person: Person, completion: @escaping (Result<[PHAsset], Error>) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                if newStatus == .authorized {
                    self.performFetch(for: person, completion: completion)
                } else {
                    completion(.failure(PhotoAccessError.denied))
                }
            }
        case .restricted, .denied:
            completion(.failure(PhotoAccessError.denied))
        case .authorized, .limited:
            performFetch(for: person, completion: completion)
        @unknown default:
            completion(.failure(PhotoAccessError.unknown))
        }
    }
    
    private func performFetch(for person: Person, completion: @escaping (Result<[PHAsset], Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            
            var personPhotos: [PHAsset] = []
            
            allPhotos.enumerateObjects { (asset, _, stop) in
                let personNamePredicate = NSPredicate(format: "localizedTitle = %@", person.name)
                let personFetchResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
                let personAlbums = personFetchResult.objects(at: IndexSet(integersIn: 0..<personFetchResult.count)).filter { personNamePredicate.evaluate(with: $0) }
                
                if !personAlbums.isEmpty {
                    personPhotos.append(asset)
                }
                
                if personPhotos.count >= 100 {  // Limit to 100 photos for performance
                    stop.pointee = true
                }
            }
            
            DispatchQueue.main.async {
                completion(.success(personPhotos))
            }
        }
    }
    
    func fetchAlbums(completion: @escaping (Result<[PHAssetCollection], Error>) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                if newStatus == .authorized {
                    self.performAlbumsFetch(completion: completion)
                } else {
                    completion(.failure(PhotoAccessError.denied))
                }
            }
        case .restricted, .denied:
            completion(.failure(PhotoAccessError.denied))
        case .authorized, .limited:
            performAlbumsFetch(completion: completion)
        @unknown default:
            completion(.failure(PhotoAccessError.unknown))
        }
    }
    
    private func performAlbumsFetch(completion: @escaping (Result<[PHAssetCollection], Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
            let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
            
            var albums: [PHAssetCollection] = []
            userAlbums.enumerateObjects { (collection, _, _) in
                albums.append(collection)
            }
            smartAlbums.enumerateObjects { (collection, _, _) in
                albums.append(collection)
            }
            
            DispatchQueue.main.async {
                completion(.success(albums))
            }
        }
    }
    
    func fetchPhotosFromAlbum(_ album: PHAssetCollection, completion: @escaping (Result<[PHAsset], Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let assetsFetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)
            
            var assets: [PHAsset] = []
            assetsFetchResult.enumerateObjects { (asset, _, _) in
                assets.append(asset)
            }
            
            DispatchQueue.main.async {
                completion(.success(assets))
            }
        }
    }
    
    func syncAlbums(completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var success = true
        
        for person in people {
            if let albumIdentifier = person.syncedAlbumIdentifier,
               let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumIdentifier], options: nil).firstObject {
                group.enter()
                fetchNewPhotosFromAlbum(album, for: person) { result in
                    if !result {
                        success = false
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(success)
        }
    }
    
    private func fetchNewPhotosFromAlbum(_ album: PHAssetCollection, for person: Person, completion: @escaping (Bool) -> Void) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(in: album, options: fetchOptions)
        
        var success = true
        let group = DispatchGroup()
        
        assets.enumerateObjects { (asset, _, stop) in
            if person.photos.contains(where: { $0.dateTaken == asset.creationDate }) {
                stop.pointee = true
                return
            }
            
            group.enter()
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            
            PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { image, _ in
                if let image = image {
                    var updatedPerson = person
                    self.addPhoto(to: &updatedPerson, asset: asset)
                    self.updatePerson(updatedPerson)
                } else {
                    success = false
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(success)
        }
    }
    
    func fetchAlbum(withIdentifier identifier: String, completion: @escaping (Result<PHAssetCollection, Error>) -> Void) {
        let result = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [identifier], options: nil)
        if let album = result.firstObject {
            completion(.success(album))
        } else {
            completion(.failure(PhotoAccessError.albumNotFound))
        }
    }
    
    func movePerson(from source: IndexSet, to destination: Int) {
        people.move(fromOffsets: source, toOffset: destination)
    }
    
    func deleteAllPhotos(for person: Person, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Find the person in the people array
            guard var updatedPerson = self.people.first(where: { $0.id == person.id }) else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PersonNotFound", code: 404, userInfo: nil)))
                }
                return
            }
            
            // Remove all photos
            updatedPerson.photos.removeAll()
            
            // Update the person in the people array
            if let index = self.people.firstIndex(where: { $0.id == person.id }) {
                self.people[index] = updatedPerson
            }
            
            // Save the updated people array
            self.savePeople()
            
            DispatchQueue.main.async {
                self.objectWillChange.send()
                completion(.success(()))
            }
        }
    }
    
    func migratePhotos() {
        print("Starting photo migration...")
        for personIndex in 0..<people.count {
            var person = people[personIndex]
            var newPhotos: [Photo] = []
            
            for oldPhoto in person.photos {
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: [oldPhoto.assetIdentifier], options: nil)
                if let asset = assets.firstObject {
                    let newPhoto = Photo(asset: asset)
                    newPhotos.append(newPhoto)
                    print("Migrated photo for \(person.name): \(newPhoto.assetIdentifier)")
                } else {
                    print("Failed to migrate photo for \(person.name): \(oldPhoto.assetIdentifier)")
                }
            }
            
            person.photos = newPhotos
            people[personIndex] = person
        }
        
        savePeople()
        print("Photo migration completed.")
    }
}

enum PhotoAccessError: Error {
    case denied
    case unknown
    case albumNotFound
}