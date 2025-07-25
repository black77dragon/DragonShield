# Troubleshooting

## RenderBox default.metallib error

When launching DragonShield you might see a console message similar to:

```
Unable to open mach-O at path: /AppleInternal/Library/.../RenderBox.framework/.../default.metallib Error:2
```

This originates from macOS attempting to load a Metal shader library that is not present on non-internal systems. The warning is harmless and does not prevent the application from running.

If the message appears repeatedly or the app fails to start, reinstall the Xcode Command Line Tools (`xcode-select --install`) or the full Xcode application to restore missing system resources.
