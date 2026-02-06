//
//  SafariView.swift
//  CustomFlows
//

import SafariServices
import SwiftUI

struct SafariView: UIViewControllerRepresentable {
  let url: URL

  func makeUIViewController(context _: Context) -> SFSafariViewController {
    SFSafariViewController(url: url)
  }

  func updateUIViewController(_: SFSafariViewController, context _: Context) {}
}
