//
//  AppLogoView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/16/25.
//

import Kingfisher
import SwiftUI

struct AppLogoView: View {
  @Environment(\.clerk) private var clerk

  var body: some View {
    KFImage(URL(string: clerk.environment.displayConfig?.logoImageUrl ?? ""))
      .resizable()
      .scaledToFit()
  }
}

#Preview {
  AppLogoView()
}
