//
//  CustomImagePicker.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/12/24.
//

import Foundation
import SwiftUI
import Photos

struct CustomImagePicker: View {
    @ObservedObject var viewModel: PersonViewModel
    @Binding var person: Person
    let sectionTitle: String
    @Binding var isPresented: Bool
    var onPhotosAdded: ([Photo]) -> Void  // Added this line

    var body: some View {
        CustomImagePickerRepresentable(
            viewModel: viewModel,
            person: $person,
            sectionTitle: sectionTitle,
            isPresented: $isPresented,
            onPhotosAdded: onPhotosAdded  // Added this line
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
    var onPhotosAdded: ([Photo]) -> Void  // Added this line

    func makeUIViewController(context: Context) -> UINavigationController {
        let dateRange = try? PhotoUtils.getDateRangeForSection(sectionTitle, person: person)
        let picker = CustomImagePickerViewController(
            sectionTitle: sectionTitle,
            dateRange: dateRange ?? (start: Date(), end: Date()),
            viewModel: viewModel
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
            for asset in assets {
                parent.viewModel.addPhoto(to: &parent.person, asset: asset)
            }
            parent.isPresented = false
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
    private var birthDate: Date
    private var viewModel: PersonViewModel
    private var displayStartDate: Date!
    private var displayEndDate: Date!

    init(sectionTitle: String, dateRange: (start: Date, end: Date), viewModel: PersonViewModel) {
        self.sectionTitle = sectionTitle
        self.dateRange = dateRange
        self.birthDate = dateRange.start
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        fetchAssets()
        setupNavigationBar()
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

        if sectionTitle == "Birth Month" {
            displayStartDate = calendar.startOfDay(for: dateRange.start)
            displayEndDate = calendar.date(byAdding: .month, value: 1, to: displayStartDate)!
        } else if sectionTitle == "Pregnancy" {
            displayStartDate = dateRange.start
            displayEndDate = dateRange.end
        } else {
            displayStartDate = calendar.date(byAdding: .month, value: 1, to: calendar.startOfDay(for: dateRange.start))!
            displayEndDate = calendar.date(byAdding: .month, value: 1, to: displayStartDate)!
        }
        
        // Adjust the end date to be one day before
        displayEndDate = calendar.date(byAdding: .day, value: -1, to: displayEndDate)!
    }

    private func fetchAssets() {
        setupDateRange()
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", displayStartDate as NSDate, displayEndDate as NSDate)
        fetchOptions.predicate = predicate

        assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.setupTitleLabel()
        }
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

    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", style: .done, target: self, action: #selector(doneTapped))
        updateAddButtonState()
        
        navigationItem.titleView = titleLabel
    }

    @objc private func cancelButtonTapped() {
        viewModel.loadingStacks.remove(sectionTitle)
        dismiss(animated: true, completion: nil)
    }

    @objc private func doneTapped() {
        viewModel.loadingStacks.remove(sectionTitle)
        dismiss(animated: true) {
            self.delegate?.imagePicker(self, didSelectAssets: self.selectedAssets)
        }
    }

    private func updateAddButtonState() {
        navigationItem.rightBarButtonItem?.isEnabled = !selectedAssets.isEmpty
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as! ImageCell
        let asset = assets.object(at: indexPath.item)
        cell.configure(with: asset, birthDate: birthDate)
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

    func configure(with asset: PHAsset, birthDate: Date) {
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