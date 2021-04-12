//
//  OpeningHoursPhotoApp.swift
//  OpeningHoursPhoto
//
//  Created by Bryce Cogswell on 4/9/21.
//

import SwiftUI

@main
struct OpeningHoursPhotoApp: App {
	init() {
#if targetEnvironment(macCatalyst)
		let bulk = BulkProcess()
		bulk.processFolder(path: "OpeningHoursPhotos")
		bulk.processFolder(path: "opening_hours/deduplicated")
#endif
	}

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
