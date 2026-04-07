# totp

Dead simple TOTP code generator. No config, no dependencies, no fuss — just pass a secret and get a code.

Designed for automated agent sessions: pass a secret directly or reference a `$ENV_VAR` by name. If the current code would expire in under 15 seconds, `totp` waits for the next window and returns a fresh code with maximum validity. The 6-digit code is printed to stdout with all status info on stderr, so `$(totp $SECRET)` always gives you a clean, ready-to-use token.

## Usage

```bash
totp JBSWY3DPEHPK3PXP
```

```
482193
expires in 23s
```

### Environment variables

To keep secrets out of shell history, store them in an environment variable and reference it with `$`:

```bash
export GITHUB_TOTP_SECRET="JBSWY3DPEHPK3PXP"
totp $GITHUB_TOTP_SECRET
```

## Installation

### Pre-built binary

```bash
curl -fsSL https://raw.githubusercontent.com/codesoda/totp/master/install.sh | sh
```

### From source

```bash
git clone https://github.com/codesoda/totp.git
cd totp
./install.sh
```

Requires [Rust](https://rustup.rs/) to build from source.

Installs to `~/.totp/bin/totp` with a symlink in `~/.local/bin/`.

## How it works

Standard [RFC 6238](https://datatracker.ietf.org/doc/html/rfc6238) TOTP — SHA1, 6 digits, 30-second period. Compatible with GitHub, Google, AWS, and any other service using standard TOTP.

The secret is a base32-encoded string (spaces, dashes, padding, and mixed case are all handled automatically).

## Exit codes

| Code | Meaning |
|------|---------|
| 0    | Success |
| 1    | Invalid input or missing environment variable |

## License

MIT
