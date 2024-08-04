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
    }
    
    func addPerson(name: String, dateOfBirth: Date, image: UIImage, dateTaken: Date) {
        let newPerson = Person(name: name, dateOfBirth: dateOfBirth)
        people.append(newPerson)
        if let index = people.firstIndex(where: { $0.id == newPerson.id }) {
            addPhoto(to: &people[index], image: image, dateTaken: dateTaken)
        }
        savePeople()
    }
    
    func addPhoto(to person: inout Person, image: UIImage, dateTaken: Date) {
        print("Adding photo to \(person.name) with date: \(dateTaken)")
        let newPhoto = Photo(image: image, dateTaken: dateTaken)
        person.photos.append(newPhoto)
        person.photos.sort { $0.dateTaken < $1.dateTaken } // Sort photos by date
        if let index = people.firstIndex(where: { $0.id == person.id }) {
            people[index] = person
            savePeople()
            objectWillChange.send()  // Notify observers of the change
            print("Photo added successfully. Total photos for \(person.name): \(person.photos.count)")
        } else {
            print("Failed to find person \(person.name) in people array")
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
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year, .month, .day], from: person.dateOfBirth, to: date)
        return (ageComponents.year ?? 0, ageComponents.month ?? 0, ageComponents.day ?? 0)
    }
    
    func updatePerson(_ updatedPerson: Person) {
        if let index = people.firstIndex(where: { $0.id == updatedPerson.id }) {
            people[index] = updatedPerson
            savePeople()
            objectWillChange.send()
        }
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
                    self.addPhoto(to: &updatedPerson, image: image, dateTaken: asset.creationDate ?? Date())
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
}

enum PhotoAccessError: Error {
    case denied
    case unknown
    case albumNotFound
}