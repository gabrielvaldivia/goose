import SwiftUI
import Photos

struct Helpers {
    static func loadImage(selectedAssets: [PHAsset], person: Person, viewModel: PersonViewModel, completion: @escaping (Person) -> Void) {
        guard !selectedAssets.isEmpty else { 
            print("No assets to load")
            completion(person)
            return 
        }
        
        let dispatchGroup = DispatchGroup()
        var updatedPerson = person
        
        for asset in selectedAssets {
            dispatchGroup.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                if let newPhoto = Photo(asset: asset) {
                    DispatchQueue.main.async {
                        viewModel.addPhoto(to: &updatedPerson, asset: asset)
                        print("Added photo with date: \(newPhoto.dateTaken) and identifier: \(newPhoto.assetIdentifier)")
                        dispatchGroup.leave()
                    }
                } else {
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            viewModel.updatePerson(updatedPerson)
            print("All photos have been added")
            viewModel.objectWillChange.send()
            completion(updatedPerson)
        }
    }

    static func deletePhoto(_ photo: Photo, from person: inout Person, viewModel: PersonViewModel) {
        if let index = person.photos.firstIndex(where: { $0.id == photo.id }) {
            person.photos.remove(at: index)
            viewModel.updatePerson(person)
        }
    }

    static func handleSelectedAssetsChange(oldValue: [PHAsset], newValue: [PHAsset]) {
        if !newValue.isEmpty {
            print("Assets selected: \(newValue)")
        } else {
            print("No assets selected")
        }
    }

    static func handleOnAppear(person: inout Person, viewModel: PersonViewModel) {
        if let updatedPerson = viewModel.people.first(where: { $0.id == person.id }) {
            person = updatedPerson
        }
    }

    static func deletePhotoAlert(photoToDelete: Photo?, onDelete: @escaping (Photo) -> Void) -> Alert {
        Alert(
            title: Text("Delete Photo"),
            message: Text("Are you sure you want to delete this photo?"),
            primaryButton: .destructive(Text("Delete")) {
                if let photoToDelete = photoToDelete {
                    onDelete(photoToDelete)
                }
            },
            secondaryButton: .cancel()
        )
    }

    static func photoDatePickerSheet(date: Binding<Date>, isPresented: Binding<Bool>, onSave: @escaping () -> Void) -> some View {
        PhotoDatePickerSheet(date: date, isPresented: isPresented) {
            onSave()
        }
        .presentationDetents([.height(300)])
    }

    static func updateScrollPosition(_ value: CGPoint, sections: [String]) -> String? {
        if let index = sections.firstIndex(where: { section in
            let sectionY = value.y + UIScreen.main.bounds.height / 2
            return sectionY >= 0 && sectionY <= UIScreen.main.bounds.height
        }) {
            return sections[index]
        }
        return nil
    }

    static func scrollToStoredPosition(proxy: ScrollViewProxy, section: String?, currentScrollPosition: String?) {
        let positionToScroll = section ?? currentScrollPosition
        if let position = positionToScroll {
            withAnimation {
                proxy.scrollTo(position, anchor: .top)
            }
        }
    }

    static func sortedGroupedPhotosForAll(person: Person, viewModel: PersonViewModel) -> [(String, [Photo])] {
        return PhotoUtils.sortedGroupedPhotosForAll(person: person, viewModel: viewModel)
    }

    static func groupAndSortPhotos(for person: Person) -> [(String, [Photo])] {
        return PhotoUtils.groupAndSortPhotos(for: person)
    }

    static func sheetContent(_ item: ActiveSheet, viewModel: PersonViewModel, person: Binding<Person>) -> some View {
        Group {
            switch item {
            case .settings:
                NavigationView {
                    PersonSettingsView(viewModel: viewModel, person: person)
                }
            case .shareView:
                ShareSlideshowView(
                    photos: person.wrappedValue.photos,
                    person: person.wrappedValue,
                    sectionTitle: "All Photos"
                )
            case .customImagePicker(let moment, _):
                NavigationView {
                    CustomImagePicker(
                        viewModel: viewModel,
                        person: person,
                        sectionTitle: moment,
                        isPresented: Binding.constant(true),
                        onPhotosAdded: { _ in
                            viewModel.updatePerson(person.wrappedValue)
                        }
                    )
                }
            }
        }
    }

    static func imagePickerContent(viewModel: PersonViewModel, person: Binding<Person>, currentMoment: String, isImagePickerPresented: Binding<Bool>) -> some View {
        CustomImagePicker(
            viewModel: viewModel,
            person: person,
            sectionTitle: currentMoment,
            isPresented: isImagePickerPresented,
            onPhotosAdded: { newPhotos in
                viewModel.updatePerson(person.wrappedValue)
            }
        )
    }

    static func deletePerson(_ person: Person, viewModel: PersonViewModel) {
        viewModel.deletePerson(person)
    }
}