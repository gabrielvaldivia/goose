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
    @State private var expandedButton: String?

    enum TitleOption: String, CaseIterable {
        case none = "None"
        case name = "Name"
        case age = "Age"
        case date = "Date"
    }

    enum AspectRatio: String, CaseIterable {
        case original = "Original"
        case square = "Square"
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
                                .background(GeometryReader { innerGeometry in
                                    Color.clear.preference(key: ViewHeightKey.self, value: innerGeometry.size.height)
                                })
                            DarkTemplateView(image: image, name: name, age: age, titleOption: titleOption, subtitleOption: subtitleOption, showAppIcon: showAppIcon, isRendering: isRendering, aspectRatio: aspectRatio)
                                .tag(1)
                                .background(GeometryReader { innerGeometry in
                                    Color.clear.preference(key: ViewHeightKey.self, value: innerGeometry.size.height)
                                })
                            OverlayTemplateView(image: image, name: name, age: age, titleOption: titleOption, subtitleOption: subtitleOption, showAppIcon: showAppIcon, isRendering: isRendering, aspectRatio: aspectRatio)
                                .tag(2)
                                .background(GeometryReader { innerGeometry in
                                    Color.clear.preference(key: ViewHeightKey.self, value: innerGeometry.size.height)
                                })
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(height: templateHeight)
                        
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
                    .onPreferenceChange(ViewHeightKey.self) { height in
                        self.templateHeight = height
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
                CustomizationButton(
                    icon: "textformat",
                    title: "Title",
                    options: TitleOption.allCases,
                    selection: $titleOption,
                    expandedButton: $expandedButton,
                    buttonId: "title"
                )

                CustomizationButton(
                    icon: "text.alignleft",
                    title: "Subtitle",
                    options: availableSubtitleOptions,
                    selection: $subtitleOption,
                    expandedButton: $expandedButton,
                    buttonId: "subtitle"
                )

                CustomizationButton(
                    icon: "aspectratio",
                    title: "Aspect Ratio",
                    options: AspectRatio.allCases,
                    selection: $aspectRatio,
                    expandedButton: $expandedButton,
                    buttonId: "aspectRatio"
                )

                // Updated App Icon toggle with fixed height
                VStack(spacing: 8) {
                    Button(action: { showAppIcon.toggle() }) {
                        VStack(spacing: 8) {
                            Image(systemName: showAppIcon ? "app.badge.checkmark" : "app")
                                .font(.system(size: 24))
                                .frame(height: 24) // Fixed height for the icon
                            Text("App Icon")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                }
                .frame(height: 50) // Fixed height for the entire button
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
                .aspectRatio(contentMode: .fill)
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
                .aspectRatio(contentMode: .fill)
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
                .aspectRatio(contentMode: .fill)
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
        .frame(width: 320, height: aspectRatio == .square ? 320 : nil)
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

struct CustomizationButton<T: Hashable>: View {
    let icon: String
    let title: String
    let options: [T]
    @Binding var selection: T
    @Binding var expandedButton: String?
    let buttonId: String

    private let optionHeight: CGFloat = 32
    private let dropdownPadding: CGFloat = 16

    var body: some View {
        VStack {
            Button(action: {
                if expandedButton == buttonId {
                    expandedButton = nil
                } else {
                    expandedButton = buttonId
                }
            }) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                    Text(title)
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
            .overlay(
                GeometryReader { geometry in
                    if expandedButton == buttonId {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(options, id: \.self) { option in
                                Button(action: {
                                    selection = option
                                    expandedButton = nil
                                }) {
                                    Text(String(describing: option))
                                        .foregroundColor(selection == option ? .blue : .primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .frame(height: optionHeight)
                                }
                            }
                        }
                        .padding(dropdownPadding)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
                        .frame(width: 150)
                        .position(x: calculateXPosition(geometry: geometry),
                                  y: calculateYPosition(geometry: geometry))
                    }
                }
            )
        }
    }
    
    private func calculateXPosition(geometry: GeometryProxy) -> CGFloat {
        let globalX = geometry.frame(in: .global).minX
        let screenWidth = UIScreen.main.bounds.width
        let dropdownWidth: CGFloat = 150
        
        if globalX + dropdownWidth > screenWidth {
            // Align right edge of dropdown with right edge of button
            return geometry.size.width - (dropdownWidth / 2)
        } else if globalX < dropdownWidth / 2 {
            // Align left edge of dropdown with left edge of button
            return dropdownWidth / 2
        } else {
            // Center dropdown on button
            return geometry.size.width / 2
        }
    }
    
    private func calculateYPosition(geometry: GeometryProxy) -> CGFloat {
        let dropdownHeight = CGFloat(options.count) * optionHeight + dropdownPadding * 2
        let spaceBelowButton = UIScreen.main.bounds.height - geometry.frame(in: .global).maxY
        
        if spaceBelowButton >= dropdownHeight + 10 {
            // Position below if there's enough space
            return geometry.size.height + dropdownHeight / 2 + 5
        } else {
            // Position above if there's not enough space below
            return -dropdownHeight / 2 - 5
        }
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