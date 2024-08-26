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
                        navigateToPersonDetail = newPerson
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { navigateToPersonDetail != nil },
                set: { if !$0 { navigateToPersonDetail = nil } }
            )) {
                if let person = navigateToPersonDetail {
                    PersonDetailView(person: viewModel.bindingForPerson(person), viewModel: viewModel)
                }
            }
        }
    }
    
    private var appTourStep: some View {
        VStack {
            Spacer()
            
            TabView {
                tourPage(title: "Welcome to Life Reel", description: "Track the growth of your loved ones through photos and memories.", imageName: "hourglass")
                tourPage(title: "Organize Memories", description: "Create personalized timelines for each person in your life.", imageName: "rectangle.stack.fill.badge.person.crop")
                tourPage(title: "Share Moments", description: "Easily share beautiful slideshows of your memories.", imageName: "square.and.arrow.up")
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .frame(height: 300)
            
            Spacer()
            
            Button(action: {
                showAddPersonView = true
            }) {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    private func tourPage(title: String, description: String, imageName: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: imageName)
                .font(.system(size: 60))
                .foregroundColor(.blue)
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
            Text(description)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}