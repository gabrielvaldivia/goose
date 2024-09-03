//
//  CustomImagePicker.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/12/24.
//

import Foundation
import SwiftUI
import Photos
import Vision
import CoreImage

struct CustomImagePicker: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    let sectionTitle: String
    @Binding var isPresented: Bool
    var onPhotosAdded: ([Photo]) -> Void
    @State private var isLoading = false

    var body: some View {
        CustomImagePickerRepresentable(
            viewModel: viewModel,
            person: $person,
            sectionTitle: sectionTitle,
            isPresented: $isPresented,
            onPhotosAdded: onPhotosAdded,
            isLoading: $isLoading
        )
        .onAppear {
            viewModel.loadingStacks.insert(sectionTitle)
        }
        .onDisappear {
            viewModel.loadingStacks.remove(sectionTitle)
        }
    }
}

struct CustomImagePickerRepresentable: UIViewControllerRepresentable {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    let sectionTitle: String
    @Binding var isPresented: Bool
    var onPhotosAdded: ([Photo]) -> Void
    @Binding var isLoading: Bool

    func makeUIViewController(context: Context) -> UINavigationController {
        guard !sectionTitle.isEmpty else {
            print("Error: Section title is empty")
            return UINavigationController()
        }

        let dateRange = try? PhotoUtils.getDateRangeForSection(sectionTitle, person: person)
        let picker = CustomImagePickerViewController(
            sectionTitle: sectionTitle,
            dateRange: dateRange ?? (start: Date(), end: Date()),
            viewModel: viewModel,
            person: person,
            isLoading: $isLoading
        )
        picker.delegate = context.coordinator
        let navigationController = UINavigationController(rootViewController: picker)
        return navigationController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CustomImagePickerDelegate {
        let parent: CustomImagePickerRepresentable

        init(_ parent: CustomImagePickerRepresentable) {
            self.parent = parent
        }

        func imagePicker(_ picker: CustomImagePickerViewController, didSelectAssets assets: [PHAsset]) {
            print("Selected \(assets.count) assets")
            DispatchQueue.main.async {
                picker.showLoadingIndicator()
            }
            parent.isLoading = true
            let dispatchGroup = DispatchGroup()
            var addedPhotos: [Photo] = []

            for (index, asset) in assets.enumerated() {
                dispatchGroup.enter()
                print("Processing asset \(index + 1) of \(assets.count)")
                parent.viewModel.addPhoto(to: parent.person, asset: asset) { photo in
                    if let photo = photo {
                        addedPhotos.append(photo)
                        print("Successfully added photo \(index + 1)")
                    } else {
                        print("Failed to add photo \(index + 1)")
                    }
                    dispatchGroup.leave()
                }
            }

            dispatchGroup.notify(queue: .main) {
                picker.hideLoadingIndicator()
                self.parent.isLoading = false
                self.parent.isPresented = false
                self.parent.onPhotosAdded(addedPhotos)
                
                print("Finished processing. Added \(addedPhotos.count) photos to \(self.parent.person.name) for section: \(self.parent.sectionTitle)")
            }
        }

        func imagePickerDidCancel(_ picker: CustomImagePickerViewController) {
            parent.isPresented = false
        }
    }
}

protocol CustomImagePickerDelegate: AnyObject {
    func imagePicker(_ picker: CustomImagePickerViewController, didSelectAssets assets: [PHAsset])
    func imagePickerDidCancel(_ picker: CustomImagePickerViewController)
}

class CustomImagePickerViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    weak var delegate: CustomImagePickerDelegate?
    private var dateRange: (start: Date, end: Date)
    private var sectionTitle: String
    private var collectionView: UICollectionView!
    private var assets: PHFetchResult<PHAsset>!
    private var selectedAssets: [PHAsset] = []
    private var titleLabel: UILabel!
    private var person: Person
    private var viewModel: PersonViewModel
    private var displayStartDate: Date!
    private var displayEndDate: Date!
    private var sortButton: UIButton!
    private var isSortedAscending = true // Track the current sort order
    private var isLoading = true
    private var segmentedControl: UISegmentedControl!
    private var showOnlyFaces = false
    private var allAssets: PHFetchResult<PHAsset>!
    private var facesAssets: [PHAsset] = []
    private var isLoadingFaces = false
    private var currentPage = 0
    private let pageSize = 20
    private var loadingIndicator: UIActivityIndicatorView!
    private var sortDescriptor: NSSortDescriptor {
        return NSSortDescriptor(key: "creationDate", ascending: isSortedAscending)
    }
    private var addButton: UIBarButtonItem!
    private var loadingBarButton: UIBarButtonItem!

    init(sectionTitle: String, dateRange: (start: Date, end: Date), viewModel: PersonViewModel, person: Person, isLoading: Binding<Bool>) {
        self.sectionTitle = sectionTitle
        self.dateRange = dateRange
        self.person = person
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        self.isLoading = isLoading.wrappedValue
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupNavigationBar()
        setupBottomBar()
        setupLoadingIndicator()
        showLoadingIndicator()
        fetchAssets()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.loadingStacks.insert(sectionTitle)
    }

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 1
        let width = (view.bounds.width - 2) / 3 // Changed from 4 to 3 columns
        layout.itemSize = CGSize(width: width, height: width)

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.allowsMultipleSelection = true
        collectionView.register(ImageCell.self, forCellWithReuseIdentifier: "ImageCell")

        view.addSubview(collectionView)
    }

    private func setupDateRange() {
        let calendar = Calendar.current

        guard !sectionTitle.isEmpty else {
            print("Error: Section title is empty")
            displayStartDate = calendar.startOfDay(for: Date())
            displayEndDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: displayStartDate) ?? displayStartDate
            return
        }

        do {
            let range = try PhotoUtils.getDateRangeForSection(sectionTitle, person: person)
            displayStartDate = range.start
            displayEndDate = range.end
            
            // Adjust start and end dates based on the section title
            let components = sectionTitle.components(separatedBy: " ")
            if components.count == 2, let value = Int(components[0]) {
                if sectionTitle == "Birth Year" {
                    displayStartDate = calendar.startOfDay(for: person.dateOfBirth)
                    displayEndDate = calendar.date(byAdding: .year, value: 1, to: person.dateOfBirth) ?? displayEndDate
                    displayEndDate = calendar.date(byAdding: .day, value: -1, to: displayEndDate) ?? displayEndDate
                } else if components[1].starts(with: "Year") {
                    displayStartDate = calendar.date(byAdding: .year, value: value, to: person.dateOfBirth) ?? displayStartDate
                    displayEndDate = calendar.date(byAdding: .year, value: value + 1, to: person.dateOfBirth) ?? displayEndDate
                    displayEndDate = calendar.date(byAdding: .day, value: -1, to: displayEndDate) ?? displayEndDate
                } else if components[1].starts(with: "Month") {
                    displayStartDate = calendar.date(byAdding: .month, value: value, to: person.dateOfBirth) ?? displayStartDate
                    displayEndDate = calendar.date(byAdding: .month, value: value + 1, to: person.dateOfBirth) ?? displayEndDate
                    displayEndDate = calendar.date(byAdding: .day, value: -1, to: displayEndDate) ?? displayEndDate
                }
            }
            
            // Ensure the end date is at the end of the day
            displayEndDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: displayEndDate) ?? displayEndDate
            
            print("Date range for \(sectionTitle): \(displayStartDate ?? Date()) to \(displayEndDate ?? Date())")
        } catch {
            print("Error setting up date range for section \(sectionTitle): \(error)")
            // Fallback to default behavior
            if sectionTitle == "Birth Month" {
                displayStartDate = calendar.startOfDay(for: person.dateOfBirth)
                displayEndDate = calendar.date(byAdding: .month, value: 1, to: displayStartDate)!
                displayEndDate = calendar.date(byAdding: .day, value: -1, to: displayEndDate)!
            } else if sectionTitle == "Pregnancy" {
                displayStartDate = dateRange.start
                displayEndDate = dateRange.end
            } else {
                displayStartDate = calendar.startOfDay(for: dateRange.start)
                displayEndDate = calendar.date(byAdding: .day, value: -1, to: endOfDay(for: dateRange.end))!
            }
        }
    }

    private func endOfDay(for date: Date) -> Date {
        return Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: date)!
    }

    private func fetchAssets() {
        setupDateRange()
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [sortDescriptor]
        
        let predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", displayStartDate as NSDate, displayEndDate as NSDate)
        fetchOptions.predicate = predicate

        allAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        assets = allAssets
        
        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.setupTitleLabel()
            self.hideLoadingIndicator()
            self.isLoading = false
        }
        
        print("Fetched \(allAssets.count) assets for \(sectionTitle)")
    }

    @objc private func sortButtonTapped() {
        isSortedAscending.toggle()
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [sortDescriptor]
        
        let predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", displayStartDate as NSDate, displayEndDate as NSDate)
        fetchOptions.predicate = predicate

        allAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        if showOnlyFaces {
            assets = PHAsset.fetchAssets(withLocalIdentifiers: facesAssets.map { $0.localIdentifier }, options: fetchOptions)
        } else {
            assets = allAssets
        }

        collectionView.reloadData()
        
        print("Sort button tapped. Sorted \(isSortedAscending ? "ascending" : "descending")")
    }

    @objc private func segmentedControlValueChanged() {
        showOnlyFaces = segmentedControl.selectedSegmentIndex == 1
        
        if showOnlyFaces {
            facesAssets.removeAll()
            currentPage = 0
            loadMoreFaces()
        } else {
            assets = allAssets
            collectionView.reloadData()
        }
    }

    private func loadMoreFaces() {
        guard !isLoadingFaces else { return }
        isLoadingFaces = true
        loadingIndicator.startAnimating()
        
        let startIndex = currentPage * pageSize
        let endIndex = min(startIndex + pageSize, allAssets.count)
        
        // Add this check to prevent invalid range creation
        guard startIndex < endIndex else {
            // We've processed all assets, so we should stop here
            DispatchQueue.main.async {
                self.isLoadingFaces = false
                self.loadingIndicator.stopAnimating()
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let assetsToProcess = (startIndex..<endIndex).compactMap { self.allAssets.object(at: $0) }
            let newFacesAssets = self.filterAssetsWithFaces(assets: assetsToProcess)
            
            DispatchQueue.main.async {
                self.facesAssets.append(contentsOf: newFacesAssets)
                
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [self.sortDescriptor]
                self.assets = PHAsset.fetchAssets(withLocalIdentifiers: self.facesAssets.map { $0.localIdentifier }, options: fetchOptions)
                
                self.collectionView.reloadData()
                self.currentPage += 1
                self.isLoadingFaces = false
                self.loadingIndicator.stopAnimating()
                
                if self.showOnlyFaces && endIndex < self.allAssets.count {
                    self.loadMoreFaces()
                }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if showOnlyFaces && indexPath.item == assets.count - 1 && !isLoadingFaces {
            loadMoreFaces()
        }
    }

    private func filterAssetsWithFaces(assets: [PHAsset]) -> [PHAsset] {
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        
        var assetsWithFaces: [PHAsset] = []
        
        for asset in assets {
            _ = autoreleasepool {
                PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 500, height: 500), contentMode: .aspectFit, options: options) { image, _ in
                    if let cgImage = image?.cgImage {
                        let ciImage = CIImage(cgImage: cgImage)
                        let context = CIContext()
                        let detector = CIDetector(ofType: CIDetectorTypeFace, context: context, options: [CIDetectorAccuracy: CIDetectorAccuracyLow])
                        
                        if let faces = detector?.features(in: ciImage), !faces.isEmpty {
                            assetsWithFaces.append(asset)
                        }
                    }
                }
            }
        }
        
        return assetsWithFaces
    }

    private func setupTitleLabel() {
        titleLabel = UILabel()
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d ''yy"
        
        let startDateString = dateFormatter.string(from: displayStartDate)
        let endDateString = dateFormatter.string(from: displayEndDate)
        
        let sectionFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
        let dateFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        
        let attributedString = NSMutableAttributedString(string: "\(sectionTitle)\n", attributes: [.font: sectionFont])
        attributedString.append(NSAttributedString(string: "\(startDateString) — \(endDateString)", attributes: [.font: dateFont]))
        
        titleLabel.attributedText = attributedString
        
        titleLabel.sizeToFit()
        navigationItem.titleView = titleLabel
    }

    func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonTapped))
        
        addButton = UIBarButtonItem(title: "Add", style: .done, target: self, action: #selector(doneTapped))
        
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.hidesWhenStopped = false
        loadingBarButton = UIBarButtonItem(customView: loadingIndicator)
        
        updateAddButtonState()
        
        navigationItem.titleView = titleLabel
    }

    private func setupBottomBar() {
        let bottomBar = UIView()
        bottomBar.backgroundColor = .systemBackground
        view.addSubview(bottomBar)
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 44)
        ])

        setupSortButton(in: bottomBar)
        setupSegmentedControl(in: bottomBar)
    }

    private func setupSortButton(in bottomBar: UIView) {
        sortButton = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        let sortIcon = UIImage(systemName: "arrow.up.arrow.down", withConfiguration: config)
        sortButton.setImage(sortIcon, for: .normal)
        sortButton.addTarget(self, action: #selector(sortButtonTapped), for: .touchUpInside)
        
        bottomBar.addSubview(sortButton)
        sortButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sortButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            sortButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor)
        ])
    }

    private func setupSegmentedControl(in bottomBar: UIView) {
        segmentedControl = UISegmentedControl(items: ["All Photos", "Faces"])
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentedControlValueChanged), for: .valueChanged)
        
        bottomBar.addSubview(segmentedControl)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            segmentedControl.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
            segmentedControl.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            segmentedControl.widthAnchor.constraint(lessThanOrEqualTo: bottomBar.widthAnchor, multiplier: 0.6)
        ])
    }

    private func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.center = view.center
        view.addSubview(loadingIndicator)
    }

    @objc private func cancelButtonTapped() {
        viewModel.loadingStacks.remove(sectionTitle)
        dismiss(animated: true, completion: nil)
    }

    @objc private func doneTapped() {
        showLoadingIndicator()
        delegate?.imagePicker(self, didSelectAssets: selectedAssets)
    }

    func updateAddButtonState() {
        if selectedAssets.isEmpty {
            navigationItem.rightBarButtonItem = nil
        } else {
            navigationItem.rightBarButtonItem = addButton
        }
    }

    func showLoadingIndicator() {
        navigationItem.rightBarButtonItem = loadingBarButton
        (loadingBarButton.customView as? UIActivityIndicatorView)?.startAnimating()
    }

    func hideLoadingIndicator() {
        (loadingBarButton.customView as? UIActivityIndicatorView)?.stopAnimating()
        updateAddButtonState()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as! ImageCell
        let asset = assets.object(at: indexPath.item)
        cell.configure(with: asset, person: person)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset = assets.object(at: indexPath.item)
        selectedAssets.append(asset)
        updateAddButtonState()
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let asset = assets.object(at: indexPath.item)
        if let index = selectedAssets.firstIndex(of: asset) {
            selectedAssets.remove(at: index)
        }
        updateAddButtonState()
    }
}

class ImageCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let checkmarkView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupImageView()
        setupCheckmarkView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupImageView() {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func setupCheckmarkView() {
        checkmarkView.isHidden = true
        checkmarkView.contentMode = .scaleAspectFit
        contentView.addSubview(checkmarkView)
        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            checkmarkView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            checkmarkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            checkmarkView.widthAnchor.constraint(equalToConstant: 24),
            checkmarkView.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        let checkmark = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)?
            .withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
        
        let whiteCircle = UIImage(systemName: "circle.fill", withConfiguration: config)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        
        if let whiteCircle = whiteCircle, let checkmark = checkmark {
            UIGraphicsBeginImageContextWithOptions(whiteCircle.size, false, 0.0)
            whiteCircle.draw(in: CGRect(origin: .zero, size: whiteCircle.size))
            checkmark.draw(in: CGRect(origin: .zero, size: checkmark.size))
            let combinedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            checkmarkView.image = combinedImage
        }
    }

    func configure(with asset: PHAsset, person: Person) {
        let manager = PHImageManager.default()
        manager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: nil) { [weak self] image, _ in
            self?.imageView.image = image
        }
    }

    override var isSelected: Bool {
        didSet {
            checkmarkView.isHidden = !isSelected
            contentView.alpha = isSelected ? 0.7 : 1.0
        }
    }
}