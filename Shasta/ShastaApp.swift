//
//  ShastaApp.swift
//  Shasta
//
//  Created by samsam on 3/13/26.
//

import SwiftUI

// MARK: - Entry
@main struct Entry: App {
	var body: some Scene {
		DocumentGroup(newDocument: ShastaDocument()) { file in
			ShastaView(document: file.$document)
		}
	}
}
