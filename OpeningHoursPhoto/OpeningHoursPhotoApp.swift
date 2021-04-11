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
		let bulk = BulkProcess()
		bulk.processFolder(path: "opening_hours/deduplicated")
	}

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
