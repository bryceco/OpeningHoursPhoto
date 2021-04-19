//
//  ContentView.swift
//  OpeningHoursPhoto
//
//  Created by Bryce Cogswell on 4/9/21.
//

import SwiftUI

public struct OpeningHoursPhotoView: View {
	@Binding var show: Bool
	@Binding var recognizedText: String

	@State private var restart: Bool

	init( show: Binding<Bool>, recognizedText: Binding<String> ) {
		self._show = show
		self._recognizedText = recognizedText
		self._restart = State(initialValue: false)
	}

	public var body: some View {
		VStack {
			CameraViewWrapper(recognizedText: $recognizedText,
							  restart: $restart)
				.background(Color.blue)
			Spacer()
			Text(recognizedText)
				.frame(height: 200.0)
			HStack {
				Spacer()
				Button("Cancel") {
					recognizedText = ""
					show = false
				}
				Spacer()
				Button("Retry") {
					restart = true
				}
				Spacer()
				Button("Accept") {
					show = false
				}
				Spacer()
			}
		}
	}
}

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
