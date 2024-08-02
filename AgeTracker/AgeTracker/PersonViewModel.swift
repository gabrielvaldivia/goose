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
    
    func addPerson(name: String, dateOfBirth: Date) {
        let newPerson = Person(name: name, dateOfBirth: dateOfBirth)
        people.append(newPerson)
        savePeople()
    }
    
    func addPhoto(to person: inout Person, image: UIImage, dateTaken: Date) {
        print("Adding photo to \(person.name) with date: \(dateTaken)")
        let newPhoto = Photo(image: image, dateTaken: dateTaken)
        person.photos.append(newPhoto)
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
    
    func calculateAge(for person: Person, at date: Date) -> (years: Int, months: Int, days: Int) {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year, .month, .day], from: person.dateOfBirth, to: date)
        return (ageComponents.year ?? 0, ageComponents.month ?? 0, ageComponents.day ?? 0)
    }
    
    func updatePerson(_ person: Person) {
        if let index = people.firstIndex(where: { $0.id == person.id }) {
            people[index] = person
            savePeople()
            objectWillChange.send()  // Notify observers of the change
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
}

enum PhotoAccessError: Error {
    case denied
    case unknown
}