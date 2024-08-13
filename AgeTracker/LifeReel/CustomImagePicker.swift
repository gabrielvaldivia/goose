//
//  CustomImagePicker.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/12/24.
//

import Foundation
import SwiftUI
import Photos

struct CustomImagePicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let dateRange: (start: Date, end: Date)
    let person: Person
    let onPick: ([PHAsset]) -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let picker = CustomImagePickerViewController(dateRange: dateRange, person: person)
        picker.delegate = context.coordinator
        let nav = UINavigationController(rootViewController: picker)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CustomImagePickerDelegate {
        let parent: CustomImagePicker

        init(_ parent: CustomImagePicker) {
            self.parent = parent
        }

        func imagePicker(_ picker: CustomImagePickerViewController, didSelectAssets assets: [PHAsset]) {
            parent.onPick(assets)
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
    private var person: Person
    private var collectionView: UICollectionView!
    private var assets: PHFetchResult<PHAsset>!
    private var selectedAssets: [PHAsset] = []
    private var titleLabel: UILabel!

    init(dateRange: (start: Date, end: Date), person: Person) {
        self.dateRange = dateRange
        self.person = person
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        fetchAssets()
        setupTitleLabel()
        setupNavigationBar()
    }

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 1
        let width = (view.bounds.width - 3) / 4
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

    private func fetchAssets() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", dateRange.start as NSDate, dateRange.end as NSDate)
        fetchOptions.predicate = predicate

        assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }

    private func setupTitleLabel() {
        titleLabel = UILabel()
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d ''yy"
        let startDateString = dateFormatter.string(from: dateRange.start)
        let endDateString = dateFormatter.string(from: dateRange.end)
        
        let nameFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
        let dateFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        
        let attributedString = NSMutableAttributedString(string: "\(person.name)\n", attributes: [.font: nameFont])
        attributedString.append(NSAttributedString(string: "\(startDateString) — \(endDateString)", attributes: [.font: dateFont]))
        
        titleLabel.attributedText = attributedString
        
        // Ensure the label size is calculated correctly
        titleLabel.sizeToFit()
    }

    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", style: .done, target: self, action: #selector(doneTapped))
        updateAddButtonState()
        
        // Set the titleView to the titleLabel
        navigationItem.titleView = titleLabel
    }

    @objc private func cancelTapped() {
        delegate?.imagePickerDidCancel(self)
    }

    @objc private func doneTapped() {
        delegate?.imagePicker(self, didSelectAssets: selectedAssets)
    }

    private func updateAddButtonState() {
        navigationItem.rightBarButtonItem?.isEnabled = !selectedAssets.isEmpty
    }

    // UICollectionViewDataSource methods
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as! ImageCell
        let asset = assets.object(at: indexPath.item)
        cell.configure(with: asset)
        return cell
    }

    // UICollectionViewDelegate methods
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
        
        // Create a blue checkmark with white circle background
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

    func configure(with asset: PHAsset) {
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