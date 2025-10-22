//
//  AppLogoView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/16/25.
//

#if os(iOS)

import Kingfisher
import SwiftUI

struct AppLogoView: View {
    @Environment(\.clerk) private var clerk

    var body: some View {
        KFImage(URL(string: clerk.environment.displayConfig?.logoImageUrl ?? ""))
            .resizable()
            //      .placeholder {
            //        #if DEBUG
            //        Image(systemName: "circle.square.fill")
            //          .resizable()
            //          .scaledToFit()
            //        #endif
            //      }
            .scaledToFit()
    }
}

#Preview {
    AppLogoView()
        .padding()
}

#endif
