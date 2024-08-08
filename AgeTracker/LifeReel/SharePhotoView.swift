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
    @State private var isRendering = false
    @State private var aspectRatio: AspectRatio = .original
    @Environment(\.dismiss) private var dismiss
    @State private var templateHeight: CGFloat = 520 // Default height

    enum TitleOption: String, CaseIterable, CustomStringConvertible {
        case none = "None"
        case name = "Name"
        case age = "Age"
        case date = "Date"
        
        var description: String { self.rawValue }
    }

    enum AspectRatio: String, CaseIterable, CustomStringConvertible {
        case original = "Original"
        case square = "Square"
        
        var description: String { self.rawValue }
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

    private var calculatedTemplateHeight: CGFloat {
        let baseHeight: CGFloat = 380 // Base height for square aspect ratio
        if aspectRatio == .original {
            let imageAspectRatio = image.size.height / image.size.width
            return baseHeight + (280 * (imageAspectRatio - 1))
        }
        return baseHeight
    }

    var body: some View {
        GeometryReader { geometry in
            VStack {
                // Header
                headerView
                    .frame(height: 52)
                    

                // Canvas
                VStack {
                    Spacer()
                    VStack {
                        TabView(selection: $selectedTemplate) {
                            LightTemplateView(image: image, name: name, age: age, titleOption: titleOption, subtitleOption: subtitleOption, showAppIcon: showAppIcon, isRendering: isRendering, aspectRatio: aspectRatio)
                                .tag(0)
                            DarkTemplateView(image: image, name: name, age: age, titleOption: titleOption, subtitleOption: subtitleOption, showAppIcon: showAppIcon, isRendering: isRendering, aspectRatio: aspectRatio)
                                .tag(1)
                            OverlayTemplateView(image: image, name: name, age: age, titleOption: titleOption, subtitleOption: subtitleOption, showAppIcon: showAppIcon, isRendering: isRendering, aspectRatio: aspectRatio)
                                .tag(2)
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(height: calculatedTemplateHeight)
                        
                        // Custom page indicator
                        HStack(spacing: 8) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(selectedTemplate == index ? Color.secondary : Color.secondary.opacity(0.5))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.vertical, 20)
                    }

                    Spacer()
                }
                .frame(height: geometry.size.height - 44 - 80) 

                // Controls
                controlsView
                    .frame(height: 60)
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .navigationBarHidden(true) 
        .sheet(isPresented: $showingPolaroidSheet) {
            if let uiImage = renderedImage {
                ActivityViewController(activityItems: [uiImage])
            }
        }
    }

    // Header View
    private var headerView: some View {
        HStack {
            cancelButton
            Spacer()
            Text("Pick template")
                .font(.headline)
            Spacer()
            shareButton
        }
        .padding(.horizontal)
    }

    // Controls View
    private var controlsView: some View {
        VStack {
            Divider()
            HStack(spacing: 40) {
                SimplifiedCustomizationButton(
                    icon: "textformat",
                    title: "Title",
                    options: TitleOption.allCases,
                    selection: $titleOption
                )

                SimplifiedCustomizationButton(
                    icon: "text.alignleft",
                    title: "Subtitle",
                    options: availableSubtitleOptions,
                    selection: $subtitleOption
                )

                SimplifiedCustomizationButton(
                    icon: "aspectratio",
                    title: "Aspect Ratio",
                    options: AspectRatio.allCases,
                    selection: $aspectRatio
                )

                // App Icon toggle
                VStack(spacing: 8) {
                    Button(action: { showAppIcon.toggle() }) {
                        VStack(spacing: 8) {
                            Image(systemName: showAppIcon ? "app.badge.checkmark" : "app")
                                .font(.system(size: 24))
                                .frame(height: 24)
                            Text("App Icon")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                }
                .frame(height: 50)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 8)
            
        }
        .background(Color(UIColor.systemBackground))
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

    private var cancelButton: some View {
        Button("Cancel") {
            dismiss()
        }
    }

    @MainActor
    private func prepareSharePhoto() async {
        guard !isPreparingImage else { return }
        isPreparingImage = true
        isRendering = true

        let templateView: some View = Group {
            switch selectedTemplate {
            case 0:
                LightTemplateView(image: image, name: name, age: age, titleOption: titleOption, subtitleOption: subtitleOption, showAppIcon: showAppIcon, isRendering: isRendering, aspectRatio: aspectRatio)
            case 1:
                DarkTemplateView(image: image, name: name, age: age, titleOption: titleOption, subtitleOption: subtitleOption, showAppIcon: showAppIcon, isRendering: isRendering, aspectRatio: aspectRatio)
            case 2:
                OverlayTemplateView(image: image, name: name, age: age, titleOption: titleOption, subtitleOption: subtitleOption, showAppIcon: showAppIcon, isRendering: isRendering, aspectRatio: aspectRatio)
            default:
                EmptyView()
            }
        }
        
        let renderer = ImageRenderer(content: templateView)
        renderer.scale = 3.0 // For better quality
        
        if let uiImage = renderer.uiImage {
            renderedImage = uiImage
            showingPolaroidSheet = true
        }
        isRendering = false
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
    let isRendering: Bool
    let aspectRatio: SharePhotoView.AspectRatio
    
    var body: some View {
        VStack(spacing: 20) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: aspectRatio == .square ? .fill : .fit)
                .frame(width: 280, height: aspectRatio == .square ? 280 : nil)
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
        .frame(minHeight: 320)
        .background(Color.white)
        .cornerRadius(isRendering ? 0 : 10)
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
    let isRendering: Bool
    let aspectRatio: SharePhotoView.AspectRatio
    
    var body: some View {
        VStack(spacing: 20) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: aspectRatio == .square ? .fill : .fit)
                .frame(width: 280, height: aspectRatio == .square ? 280 : nil)
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
        .frame(minHeight: 320)
        .background(Color.black)
        .cornerRadius(isRendering ? 0 : 10)
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

struct OverlayTemplateView: View {
    let image: UIImage
    let name: String
    let age: String
    let titleOption: SharePhotoView.TitleOption
    let subtitleOption: SharePhotoView.TitleOption
    let showAppIcon: Bool
    let isRendering: Bool
    let aspectRatio: SharePhotoView.AspectRatio
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: aspectRatio == .square ? .fill : .fit)
                .frame(width: 320, height: aspectRatio == .square ? 320 : nil)
                .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                if !titleText.isEmpty {
                    Text(titleText)
                        .font(.headline)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 1, x: 0, y: 1)
                }
                if !subtitleText.isEmpty {
                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 1, x: 0, y: 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            if showAppIcon {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 320)
        .frame(minHeight: 320)
        .cornerRadius(isRendering ? 0 : 10)
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

struct SimplifiedCustomizationButton<T: Hashable & CustomStringConvertible>: View {
    let icon: String
    let title: String
    let options: [T]
    @Binding var selection: T

    var body: some View {
        Menu {
            Picker(selection: $selection, label: EmptyView()) {
                ForEach(options, id: \.self) { option in
                    Text(option.description).tag(option)
                }
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.caption)
            }
        }
        .foregroundColor(.primary)
    }
}

struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}