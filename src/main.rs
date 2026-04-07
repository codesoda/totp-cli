use data_encoding::BASE32_NOPAD;
use hmac::{Hmac, Mac};
use sha1::Sha1;
use std::env;
use std::process;
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

type HmacSha1 = Hmac<Sha1>;

fn totp(secret: &[u8], time_step: u64) -> u32 {
    let mut mac = HmacSha1::new_from_slice(secret).expect("HMAC accepts any key size");
    mac.update(&time_step.to_be_bytes());
    let result = mac.finalize().into_bytes();
    let offset = (result[19] & 0x0f) as usize;
    let code = ((result[offset] as u32 & 0x7f) << 24)
        | ((result[offset + 1] as u32) << 16)
        | ((result[offset + 2] as u32) << 8)
        | (result[offset + 3] as u32);
    code % 1_000_000
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 {
        eprintln!("Usage: totp <secret|$ENV_VAR>");
        eprintln!();
        eprintln!("  Pass a base32 TOTP secret directly, or prefix with $ to read from env:");
        eprintln!("    totp JBSWY3DPEHPK3PXP");
        eprintln!("    totp $GITHUB_TOTP_SECRET");
        process::exit(1);
    }

    let input = &args[1];

    // If prefixed with $, resolve from environment
    let secret_str = if let Some(var_name) = input.strip_prefix('$') {
        match env::var(var_name) {
            Ok(val) => val,
            Err(_) => {
                eprintln!("Error: environment variable '{}' is not set", var_name);
                process::exit(1);
            }
        }
    } else {
        input.clone()
    };

    // Normalize: uppercase, strip spaces/dashes, add padding if needed
    let cleaned: String = secret_str
        .to_uppercase()
        .chars()
        .filter(|c| !c.is_whitespace() && *c != '-')
        .collect();

    // BASE32_NOPAD expects no padding, so strip any '=' chars
    let no_pad: String = cleaned.chars().filter(|c| *c != '=').collect();

    let secret_bytes = match BASE32_NOPAD.decode(no_pad.as_bytes()) {
        Ok(bytes) => bytes,
        Err(_) => {
            eprintln!("Error: invalid base32 secret");
            process::exit(1);
        }
    };

    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .expect("time went backwards")
        .as_secs();

    let seconds_remaining = 30 - (now % 30);

    // If code would expire in <15s, wait for a fresh one
    let (time_step, seconds_remaining) = if seconds_remaining < 15 {
        eprintln!(
            "\x1b[2mcode expires in {}s, waiting for fresh code...\x1b[0m",
            seconds_remaining
        );
        thread::sleep(Duration::from_secs(seconds_remaining));
        let fresh_now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("time went backwards")
            .as_secs();
        (fresh_now / 30, 30 - (fresh_now % 30))
    } else {
        (now / 30, seconds_remaining)
    };

    let code = totp(&secret_bytes, time_step);
    println!("{:06}", code);

    // Show expiry on stderr so agents can cleanly parse stdout
    eprintln!("\x1b[2mexpires in {}s\x1b[0m", seconds_remaining);
}
