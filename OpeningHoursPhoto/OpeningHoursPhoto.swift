//
//  CameraView.swift
//
//  Created by Bryce Cogswell on 4/8/21.
//

import SwiftUI


fileprivate extension Button {
	func withMyButtonStyle() -> some View {
		self.padding()
			.foregroundColor(.white)
			.background(Capsule().fill(Color.blue))
	}
}

public struct OpeningHoursPhotoView: View {
	@Binding var show: Bool
	@Binding var returnedText: String
	@State private var restart: Bool

	@StateObject var recognizer = HoursRecognizer()

	init( show: Binding<Bool>, recognizedText: Binding<String> ) {
		self._show = show
		self._returnedText = recognizedText
		self._restart = State(initialValue: false)
	}

	public var body: some View {
		ZStack(alignment: .topLeading) {
			VStack {
				OpeningHoursPhoto(recognizer: recognizer,
								  restart: $restart)
					.background(Color.blue)
				Spacer()
				Text(recognizer.text)
					.frame(height: 200.0)
				HStack {
					Spacer()
					Button("Cancel") {
						show = false
					}.withMyButtonStyle()
					Spacer()
					Button("Retry") {
						restart = true
					}.withMyButtonStyle()
					Spacer()
					Button("Accept") {
						show = false
						returnedText = recognizer.text
					}.withMyButtonStyle()
					.disabled( !recognizer.isFinished() )
					Spacer()
				}
			}
			Picker(recognizer.language.rawValue, selection: $recognizer.language) {
				ForEach(HoursRecognizer.Language.allCases) { lang in
					Text( lang.rawValue ).tag( lang )
				}
			}
			.pickerStyle(MenuPickerStyle())
			.foregroundColor(.white)
			.padding()
			.background(Color.blue)
			.overlay(Capsule(style: .continuous)
						.stroke(Color.white, lineWidth: 2.0))
		}
	}
}

struct OpeningHoursPhoto: UIViewRepresentable {

	@ObservedObject var recognizer: HoursRecognizer
	@Binding var restart: Bool

	func makeUIView(context: Context) -> CameraView {
		let cam = CameraView(frame: .zero)
		cam.observationsCallback = { observations, camera in
			recognizer.updateWithLiveObservations( observations: observations, camera: camera )
		}
		cam.shouldRecordCallback = {
			return !recognizer.isFinished()
		}
		return cam
	}

	func updateUIView(_ uiView: CameraView, context: Context) {
		if restart {
			DispatchQueue.main.async {
				restart = false
				recognizer.restart()
				uiView.startRunning()
			}
		}
		if recognizer.isFinished() {
			// TODO: enable Accept button
		}
	}
}
