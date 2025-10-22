//
//  SafariView.swift
//  Clerk
//
//  Created by Mike Pitre on 6/23/25.
//

#if os(iOS)

import SafariServices
import SwiftUI

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context _: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_: SFSafariViewController, context _: Context) {
        // No updates needed as URL doesn't change after creation
    }
}

struct SafariSheetItem: Identifiable {
    let id = UUID()
    let url: URL
}

#endif

