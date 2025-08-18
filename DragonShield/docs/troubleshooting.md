# Troubleshooting

Common remedies for build and runtime issues.

## Metal `default.metallib` warning

When the app launches, the Metal framework may print a `default.metallib` warning. This message is harmless and can be ignored.

## Python interpreter not found

Ensure Python 3.11 is installed and on your PATH. The project uses `/usr/bin/python3`; if missing, install Xcode Command Line Tools or adjust your PATH.
