//
//  CameraView.swift
//
//  Created by Bryce Cogswell on 4/8/21.
//

import SwiftUI

struct CameraViewWrapper: UIViewRepresentable {

	@Binding var recognizedText: String
	@Binding var capturePhoto: Bool

	func makeUIView(context: Context) -> CameraView {
		return CameraView(frame: .zero)
	}

	func updateUIView(_ uiView: CameraView, context: Context) {
		if capturePhoto {
			uiView.captureCallback = { image in
				let hr = HoursRecognizer()
				let text = hr.hoursForImage(image: image)
				recognizedText = text
			}
			capturePhoto = false
			uiView.takePhoto(sender: nil)
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
