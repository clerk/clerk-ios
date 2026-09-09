# Authentication locale continuity

The previous native sign-in/sign-up services supplied the OS locale. The initial embedded profile reused a browser-only locale helper, which returns no language in a bare VM. Request tests reproduced the missing `fr-CA` and `ja-JP` values before the fix.

The runtime now supplies the preferred device language as a BCP 47 tag when connecting. The shared native host installs that value on its Clerk owner. Existing TypeScript authentication request construction uses it, retaining browser fallback when no native locale is supplied. An explicit sign-up locale takes precedence. Native code does not construct authentication request bodies.

The value is captured at connection time. A device-language change takes effect on the next connection. Replacing a native host changes subsequent request locales; disposing an older host cannot clear the replacement, and disposing the current host restores the previous behavior.

Validation: all 125 embedded-runtime tests and four existing browser-locale tests pass. Packaged-core tests on iOS Simulator and Android emulator assert the actual sign-in and sign-up HTTP bodies contain the device locale and preserve an explicit `de-DE` sign-up override. This verifies request negotiation, not translated UI, delivery content, or a live account's stored locale.
