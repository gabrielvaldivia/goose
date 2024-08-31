//
//  OnboardingView.swift
//  LifeReel
//
//  Created by Gabriel Valdivia on 8/25/24.
//

import Foundation
import SwiftUI
import PhotosUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @ObservedObject var viewModel: PersonViewModel
    @State private var showAddPersonView = false
    @State private var navigateToPersonDetail: Person?

    var body: some View {
        NavigationStack {
            VStack {
                appTourStep
            }
            .background(Color(UIColor.systemBackground))
            .onAppear {
                setupPageControlAppearance()
            }
            .onDisappear {
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            }
            .sheet(isPresented: $showAddPersonView) {
                AddPersonView(
                    viewModel: viewModel,
                    isPresented: $showAddPersonView,
                    onboardingMode: true,
                    currentStep: .constant(1)
                )
            }
            .onChange(of: viewModel.people.count) { oldCount, newCount in
                if newCount > oldCount, let newPerson = viewModel.people.last {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        viewModel.setSelectedPerson(newPerson)
                        showOnboarding = false
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    }
                }
            }
        }
    }
    
    private var appTourStep: some View {
        VStack(spacing: 0) {
            Text("Life Reel")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.vertical, 40)
            
            TabView {
                tourPage(description: "Relive the joy of watching your loved ones grow", imageName: "onboarding-welcome")
                tourPage(description: "Upload a photo, see the age—it's that simple!", imageName: "onboarding-age")
                tourPage(description: "Time travel through your favorite moments", imageName: "onboarding-organize")
                tourPage(description: "Share stunning slideshows of cherished memories", imageName: "onboarding-share")
                tourPage(description: "Get reminders to capture key milestones", imageName: "onboarding-reminders")
                tourPage(description: "Perfect for your children, pets, and beyond", imageName: "onboarding-get-started")

            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .ignoresSafeArea()
            
            Button(action: {
                showAddPersonView = true
            }) {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .padding(.horizontal)
            .padding(.vertical, 20)
        }
        .background(Color(UIColor.systemBackground))
    }
    
    private func tourPage(description: String, imageName: String) -> some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {

                ZStack {
                    randomBackgroundColor()
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .padding(40)
                }
                .frame(width: geometry.size.width, height: geometry.size.width) // Square frame
                .clipped() // Ensure the ZStack doesn't exceed its frame



                Text(description)
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                Spacer() 

            }
        }
    }
    
    private func randomBackgroundColor() -> Color {
        Color(
            red: .random(in: 0.1...0.9),
            green: .random(in: 0.1...0.9),
            blue: .random(in: 0.1...0.9)
        ).opacity(0.3)
    }
    
    private func setupPageControlAppearance() {
        UIPageControl.appearance().currentPageIndicatorTintColor = UIColor.secondaryLabel
        UIPageControl.appearance().pageIndicatorTintColor = UIColor.secondaryLabel.withAlphaComponent(0.2)
    }
}