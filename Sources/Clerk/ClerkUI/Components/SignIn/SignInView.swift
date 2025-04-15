//
//  SignInView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/14/25.
//

import Factory
import SwiftUI

public struct SignInView: View {
  
  public init() {}
  
  public var body: some View {
    SignInStartView()
  }
}

#Preview {
  let _ = Container.shared.setupMocks()
  SignInView()
    .environment(Clerk.shared)
}
