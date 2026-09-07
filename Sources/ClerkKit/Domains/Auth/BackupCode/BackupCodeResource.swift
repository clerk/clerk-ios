import ClerkSnapshots
import Foundation

public typealias BackupCodeResource = ClerkSnapshots.BackupCode

extension BackupCodeResource {
  public init(
    id: String,
    codes: [String],
    createdAt: Date,
    updatedAt: Date
  ) {
    self.init(
      object: "backup_code",
      id: id,
      codes: codes,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
