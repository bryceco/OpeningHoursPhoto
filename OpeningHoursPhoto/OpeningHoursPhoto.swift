//
//  CameraView.swift
//
//  Created by Bryce Cogswell on 4/8/21.
//

import SwiftUI

public struct OpeningHoursPhotoView: View {
	@Binding var show: Bool
	@Binding var recognizedText: String
	@State private var restart: Bool

	@State var temporaryText: String

	init( show: Binding<Bool>, recognizedText: Binding<String> ) {
		self._show = show
		self._recognizedText = recognizedText
		self._restart = State(initialValue: false)
		self._temporaryText = State(initialValue: "")
	}

	public var body: some View {
		VStack {
			OpeningHoursPhoto(recognizedText: $temporaryText,
							  restart: $restart)
				.background(Color.blue)
			Spacer()
			Text(temporaryText)
				.frame(height: 200.0)
			HStack {
				Spacer()
				Button("Cancel") {
					show = false
				}
				Spacer()
				Button("Retry") {
					restart = true
				}
				Spacer()
				Button("Accept") {
					show = false
					recognizedText = temporaryText
				}
				Spacer()
			}
		}
	}
}

struct OpeningHoursPhoto: UIViewRepresentable {

	@Binding var recognizedText: String
	@Binding var restart: Bool

	@StateObject var recognizer = HoursRecognizer()

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
		if recognizedText != recognizer.text {
			DispatchQueue.main.async {
				recognizedText = recognizer.text
			}
		}
		if recognizer.isFinished() {
			// TODO: enable Accept button
		}
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(recognizedText: $recognizedText, parent: self)
	}

	class Coordinator: NSObject {
		var recognizedText: Binding<String>
		var parent: OpeningHoursPhoto
        
		init(recognizedText: Binding<String>, parent: OpeningHoursPhoto) {
			self.recognizedText = recognizedText
			self.parent = parent
		}
	}
}
