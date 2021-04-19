//
//  CameraView.swift
//
//  Created by Bryce Cogswell on 4/8/21.
//

import SwiftUI

struct CameraViewWrapper: UIViewRepresentable {

	@Binding var recognizedText: String
	@Binding var restart: Bool			// set true to take a picture

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
			recognizedText = recognizer.text
		}
		if recognizer.isFinished() {
			
		}
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(recognizedText: $recognizedText, parent: self)
	}

	class Coordinator: NSObject {
		var recognizedText: Binding<String>
		var parent: CameraViewWrapper
        
		init(recognizedText: Binding<String>, parent: CameraViewWrapper) {
			self.recognizedText = recognizedText
			self.parent = parent
		}
	}
}
