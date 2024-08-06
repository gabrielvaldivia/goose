import Foundation
import SwiftUI

struct SharePhotoView: View {
    let image: UIImage
    let name: String
    let age: String
    @Binding var isShareSheetPresented: Bool
    @Binding var activityItems: [Any]
    @State private var showingPolaroidSheet = false
    @State private var selectedTemplate = 0
    @State private var renderedImage: UIImage?
    @State private var isPreparingImage = false
    @State private var titleOption = TitleOption.name
    @State private var subtitleOption = TitleOption.age
    @State private var showAppIcon = true

    enum TitleOption: String, CaseIterable {
        case none = "None"
        case name = "Name"
        case age = "Age"
        case date = "Date"
    }

    init(image: UIImage, name: String, age: String, isShareSheetPresented: Binding<Bool>, activityItems: Binding<[Any]>) {
        self.image = image
        self.name = name
        self.age = age
        self._isShareSheetPresented = isShareSheetPresented
        self._activityItems = activityItems
        
        // Customize UIPageControl appearance
        UIPageControl.appearance().currentPageIndicatorTintColor = .secondaryLabel
        UIPageControl.appearance().pageIndicatorTintColor = .tertiaryLabel
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                TabView(selection: $selectedTemplate) {
                    LightTemplateView(image: image, name: name, age: age, titleOption: titleOption, subtitleOption: subtitleOption, showAppIcon: showAppIcon)
                        .tag(0)
                    DarkTemplateView(image: image, name: name, age: age, titleOption: titleOption, subtitleOption: subtitleOption, showAppIcon: showAppIcon)
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .frame(height: 480)

                Form {
                    Section(header: Text("Customization")) {
                        Picker("Title", selection: $titleOption) {
                            ForEach(TitleOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .onChange(of: titleOption) { oldValue, newValue in
                            if newValue == subtitleOption {
                                subtitleOption = .none
                            }
                        }
                        
                        Picker("Subtitle", selection: $subtitleOption) {
                            ForEach(availableSubtitleOptions, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .onChange(of: subtitleOption) { oldValue, newValue in
                            if newValue == titleOption {
                                titleOption = .none
                            }
                        }
                        
                        Toggle("Show App Icon", isOn: $showAppIcon)
                    }
                }
                .frame(height: 200)
            }
            .padding()
        }
        .background(Color(UIColor.secondarySystemBackground))
        .navigationTitle("Pick a share template")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: shareButton)
        .sheet(isPresented: $showingPolaroidSheet) {
            if let uiImage = renderedImage {
                ActivityViewController(activityItems: [uiImage])
            }
        }
    }

    private var availableSubtitleOptions: [TitleOption] {
        TitleOption.allCases.filter { $0 != titleOption || $0 == .none }
    }

    private var shareButton: some View {
        Button(action: {
            Task { @MainActor in
                await prepareSharePhoto()
            }
        }) {
            if isPreparingImage {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            } else {
                Text("Share")
            }
        }
        .disabled(isPreparingImage)
    }

    @MainActor
    private func prepareSharePhoto() async {
        guard !isPreparingImage else { return }
        isPreparingImage = true

        let templateView: some View = Group {
            if selectedTemplate == 0 {
                LightTemplateView(image: image, name: name, age: age, titleOption: titleOption, subtitleOption: subtitleOption, showAppIcon: showAppIcon)
            } else {
                DarkTemplateView(image: image, name: name, age: age, titleOption: titleOption, subtitleOption: subtitleOption, showAppIcon: showAppIcon)
            }
        }
        
        let renderer = ImageRenderer(content: templateView)
        renderer.scale = 3.0 // For better quality
        
        if let uiImage = renderer.uiImage {
            renderedImage = uiImage
            showingPolaroidSheet = true
        }
        isPreparingImage = false
    }
}

struct LightTemplateView: View {
    let image: UIImage
    let name: String
    let age: String
    let titleOption: SharePhotoView.TitleOption
    let subtitleOption: SharePhotoView.TitleOption
    let showAppIcon: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 280, height: 280)
                .clipped()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if !titleText.isEmpty {
                        Text(titleText)
                            .font(.headline)
                            .foregroundColor(.black)
                    }
                    if !subtitleText.isEmpty {
                        Text(subtitleText)
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
                if showAppIcon {
                    Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .frame(width: 320)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var titleText: String {
        switch titleOption {
        case .none: return ""
        case .name: return name
        case .age: return age
        case .date: return formatDate(Date())
        }
    }
    
    private var subtitleText: String {
        switch subtitleOption {
        case .none: return ""
        case .name: return name
        case .age: return age
        case .date: return formatDate(Date())
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct DarkTemplateView: View {
    let image: UIImage
    let name: String
    let age: String
    let titleOption: SharePhotoView.TitleOption
    let subtitleOption: SharePhotoView.TitleOption
    let showAppIcon: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 280, height: 280)
                .clipped()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if !titleText.isEmpty {
                        Text(titleText)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    if !subtitleText.isEmpty {
                        Text(subtitleText)
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
                if showAppIcon {
                    Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .frame(width: 320)
        .background(Color.black)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    private var titleText: String {
        switch titleOption {
        case .none: return ""
        case .name: return name
        case .age: return age
        case .date: return formatDate(Date())
        }
    }
    
    private var subtitleText: String {
        switch subtitleOption {
        case .none: return ""
        case .name: return name
        case .age: return age
        case .date: return formatDate(Date())
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}