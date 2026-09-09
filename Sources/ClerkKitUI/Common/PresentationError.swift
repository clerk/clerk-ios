#if os(iOS) || os(macOS)
import Foundation

struct PresentationError: LocalizedError {
  let errorDescription: String?

  init(message: String.LocalizationValue, localizationBundle: Bundle) {
    errorDescription = String(localized: message, bundle: localizationBundle)
  }
}
#endif
