# Wire Conformance Receipt (Latest)

- Date (UTC): 2026-03-06T03:02:18Z
- Repository: `/root/psync`
- Host: `Linux my-vps 6.1.0-43-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.1.162-1 (2026-02-08) x86_64 GNU/Linux`

## Frozen Invariants

- `preimage = "ftf-msg-v1\0" || cbor(blankSig(msg))`
- `hash = multihash(sha2-256(preimage))`
- `sig = Ed25519.Sign(sk, mh_bytes)`
- `replay = (t, mh_bytes)`
- `trace status = local CAS truth`

## Toolchain

- `cargo --version`: `cargo 1.94.0 (85eff7c80 2026-01-15)`
- `rustc --version`: `rustc 1.94.0 (4a4ef493e 2026-03-02)`
- `ghc --version`: `The Glorious Glasgow Haskell Compilation System, version 9.0.2`

## Conformance Command

```bash
bash verify-wire.sh
```

## Result

```text
[verify-wire] Building Haskell CLI
Up to date
[verify-wire] Running Haskell selftest
selftest=ok
[verify-wire] Building Rust verifier
Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.03s
[verify-wire] Generating signed alias fixture from Haskell sign-msg
[verify-wire] Cross-checking verify-topic in Rust
Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.04s
Running `target/debug/ftf-verify verify-topic ftf alias/main`
verified=1
OK 12203f946b72b9c893216e1c974d763c0d37fcccd0d66eb8ac00dacf406b1ed08715 t=1
rejected=0
[verify-wire] Cross-checking resolve-alias in Rust
Finished `dev` profile [unoptimized + debuginfo] target(s) in 0.03s
Running `target/debug/ftf-verify resolve-alias ftf alias/main 'WORLD:alpha'`
quarantine=0
target_hash=12200000000000000000000000000000000000000000000000000000000000000000
[verify-wire] Running trace conformance checks in Haskell
[verify-wire] ok wire conformance
```

## Notes

- This receipt confirms full end-to-end Haskell↔Rust wire conformance on this host.
- Trace assertions include both materialized (`status:"ok"`) and unmaterialized (`status:"pending_fetch"`) dependency semantics.
