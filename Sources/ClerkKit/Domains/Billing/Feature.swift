import ClerkSnapshots
import Foundation

public typealias Feature = ClerkSnapshots.Feature

extension Feature {
  public init(
    id: String,
    name: String,
    description: String? = nil,
    slug: String,
    avatarUrl: String? = nil
  ) {
    self.init(
      object: "feature",
      id: id,
      name: name,
      description: description,
      slug: slug,
      avatarUrl: avatarUrl
    )
  }
}
