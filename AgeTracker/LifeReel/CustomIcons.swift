//
//  CustomIcons.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 9/19/24.
//

import Foundation
import SwiftUI

struct CustomIcon: View {
    let name: String
    let renderingMode: Image.TemplateRenderingMode

    init(name: String, renderingMode: Image.TemplateRenderingMode = .template) {
        self.name = name
        self.renderingMode = renderingMode
    }

    var body: some View {
        Image(name)
            .renderingMode(renderingMode)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

struct FacebookIcon: View {
    var body: some View {
        CustomIcon(name: "FacebookIcon")
    }
}

struct InstagramIcon: View {
    var body: some View {
        CustomIcon(name: "InstagramIcon")
    }
}

struct InstagramStoryIcon: View {
    var body: some View {
        CustomIcon(name: "InstagramStoryIcon")
    }
}

struct SMSIcon: View {
    var body: some View {
        CustomIcon(name: "SMSIcon")
    }
}
