## Strings

User-facing text is in two catalogs. `Sources/ClerkKitUI/Resources/Localizable.xcstrings` holds the text of the prebuilt views, and `Sources/ClerkKit/Resources/Localizable.xcstrings` holds the error text of the core SDK. In both, the English text is the key, and each key holds a translation for every language the SDK ships.

When you change English text, rename its key in the catalog that holds it and update the translation in every language to say what the new text says. A Swift literal with no key in the catalog shows in English in every language. Old translations kept under a new key still say what the old text said.

When you add text, add its key with a translation in every language.

A key marked `"shouldTranslate" : false` holds text that is the same in every language. It has no translations, whether you add it or change it.

## Comments

Don't write comments unless they explain a constraint from a platform, library,
or spec that we can't change. If our own code needs explaining, change the code:
rename it, give it a type, extract a helper, or pin it with a test.

Keep license headers, doc comments on public API, and `// MARK:` markers.
Don't leave commented-out code.
