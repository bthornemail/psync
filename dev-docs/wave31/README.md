# Wave31 Device Parity Fixtures (psync)

This folder mirrors the Wave31 host parity contract with local fixtures for firmware integration work.

## Layout

- `inputs/`: canonical surface/emitter inputs and UART binaries
- `golden/`: expected Wave31 artifact outputs
- `must-reject/`: binary vectors that must fail closed

## Local checks

```bash
bash scripts/wave31-device-parity-golden.sh
bash scripts/wave31-device-parity-must-reject.sh
bash scripts/check-wave31-device-parity-contract.sh
```

Set `METAVERSE_KIT_DIR` if your metaverse-kit path differs from `/home/main/devops/metaverse-kit`.
