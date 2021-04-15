//
//  CameraView.swift
//
//  Created by Bryce Cogswell on 4/8/21.
//

import SwiftUI

struct CameraViewWrapper: UIViewRepresentable {

	@Binding var recognizedText: String
	@Binding var capturePhoto: Bool			// set true to take a picture

	@StateObject var recognizer = HoursRecognizer()

	func makeUIView(context: Context) -> CameraView {
		let cam = CameraView(frame: .zero)
		cam.observationsCallback = { observations, camera in
			recognizer.updateWithLiveObservations( observations: observations, camera: camera )
		}
		return cam
	}

	func updateUIView(_ uiView: CameraView, context: Context) {
		if capturePhoto {
			uiView.photoCallback = { image in
				recognizer.setImage(image: image, isRotated: true)
				recognizedText = recognizer.text
			}
			capturePhoto = false
			uiView.takePhoto(sender: nil)
		}
		if recognizedText != recognizer.text {
			print("\(recognizer.text)")
			recognizedText = recognizer.text
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
