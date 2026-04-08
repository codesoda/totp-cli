# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-08

### Added

- TOTP code generation (RFC 6238, SHA1, 6 digits, 30-second period)
- Environment variable support via `$ENV_VAR` syntax
- Automatic base32 normalization (mixed case, spaces, dashes, padding)
- Freshness guarantee — waits for the next code window when remaining validity is under 15 seconds
- Agent-friendly output — 6-digit code on stdout, status info on stderr
- Install script with support for pre-built binaries and local source builds
- CI workflow (fmt, clippy, build, test)
- Release workflow with cross-platform builds (macOS arm64/x86_64, Linux x86_64/aarch64)

[0.1.0]: https://github.com/codesoda/totp-cli/releases/tag/v0.1.0
