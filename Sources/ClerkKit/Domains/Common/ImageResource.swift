import ClerkSnapshots
import Foundation

public typealias ImageResource = ClerkSnapshots.ClerkImage

extension ImageResource {
  public init(
    id: String,
    name: String? = nil,
    publicUrl: String? = nil
  ) {
    self.init(
      object: "image",
      id: id,
      name: name ?? "",
      publicUrl: publicUrl ?? ""
    )
  }
}
