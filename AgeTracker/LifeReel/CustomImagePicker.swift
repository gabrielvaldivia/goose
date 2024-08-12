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
    let targetDate: Date
    let onPick: ([PHAsset]) -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let picker = CustomImagePickerViewController(targetDate: targetDate)
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
    private var targetDate: Date
    private var collectionView: UICollectionView!
    private var assets: PHFetchResult<PHAsset>!
    private var selectedAssets: [PHAsset] = []

    init(targetDate: Date) {
        self.targetDate = targetDate
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
        
        // Calculate the date 40 weeks before the target date
        let calendar = Calendar.current
        let fortyWeeksBefore = calendar.date(byAdding: .weekOfYear, value: -40, to: targetDate)!
        
        // Create a predicate to filter assets
        let predicate = NSPredicate(format: "creationDate >= %@", fortyWeeksBefore as NSDate)
        fetchOptions.predicate = predicate

        assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.scrollToTargetDate()
        }
    }

    private func scrollToTargetDate() {
        guard let lastIndex = assets.lastObject.flatMap({ assets.index(of: $0) }) else { return }
        for i in 0...lastIndex {
            let asset = assets.object(at: i)
            if let creationDate = asset.creationDate, creationDate <= targetDate {
                let indexPath = IndexPath(item: i, section: 0)
                collectionView.scrollToItem(at: indexPath, at: .top, animated: false)
                break
            }
        }
    }

    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", style: .done, target: self, action: #selector(doneTapped))
        updateAddButtonState()
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

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupImageView()
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

    func configure(with asset: PHAsset) {
        let manager = PHImageManager.default()
        manager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: nil) { [weak self] image, _ in
            self?.imageView.image = image
        }
    }

    override var isSelected: Bool {
        didSet {
            contentView.alpha = isSelected ? 0.7 : 1.0
        }
    }
}