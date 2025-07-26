# Troubleshooting

## RenderBox default.metallib error

When launching DragonShield you might see a console message similar to:

```
Unable to open mach-O at path: /AppleInternal/Library/.../RenderBox.framework/.../default.metallib Error:2
```

This originates from macOS attempting to load a Metal shader library that is not present on non-internal systems. The warning is harmless and does not prevent the application from running.

If the message appears repeatedly or the app fails to start, reinstall the Xcode Command Line Tools (`xcode-select --install`) or the full Xcode application to restore missing system resources.

## Language code warnings

When running on macOS you may see console output similar to:

```
GenerativeModelsAvailability.Parameters: Initialized with invalid language code: en-GB. Expected to receive two-letter ISO 639 code.
AFIsDeviceGreymatterEligible Missing entitlements for os_eligibility lookup
-[AFPreferences _languageCodeWithFallback:] No language code saved, but Assistant is enabled - returning: en-GB
```

These messages are emitted by Apple's Siri frameworks and do not affect DragonShield. Setting the environment variable `LANG=en` or ensuring your system language is configured correctly will silence the warnings.
