# Wave31 ESP32 Firmware Lane (Scaffold)

This directory is the bounded scaffold for Wave31 PR-4 firmware implementation.

Scope for firmware implementation:

- decode Wave30 UART packets (`none` and `crc8-xor-v0` modes)
- reconstruct emitter frames deterministically
- emit canonical artifacts:
  - `wave31.hardware_decode_receipt.v0`
  - `wave31.frame_verify_result.v0`
- enforce fail-closed behavior for must-reject corpus classes

This scaffold intentionally contains no firmware code yet.
