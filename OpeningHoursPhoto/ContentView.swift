//
//  ContentView.swift
//  OpeningHoursPhoto
//
//  Created by Bryce Cogswell on 4/9/21.
//

import SwiftUI

struct ContentView: View {

	@State private var recognizedText = "Opening hours unknown"
	@State private var showCameraView = false
	@State private var capturePhoto = false

	var body: some View {
		NavigationView {
			VStack {
				ScrollView {
					ZStack {
						RoundedRectangle(cornerRadius: 20, style: .continuous)
							.fill(Color.gray.opacity(0.2))

						Text(recognizedText)
							.padding()
					}
					.padding()
				}

				Spacer()

				Button(action: {
					self.showCameraView = true
				}) {
					Text("Take Photo")
				}
				.padding()
				.foregroundColor(.white)
				.background(Capsule().fill(Color.blue))
			}
			.navigationBarTitle("OpeningHours")
			.sheet(isPresented: $showCameraView) {
				OpeningHoursPhotoView(show: $showCameraView, recognizedText: $recognizedText)
			}
		}
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}
