# @psync/core

Reusable PSYNC protocol core module.

## Structure

- `src/types.ts`: protocol and snapshot types
- `src/engine.ts`: deterministic state transition engine
- `src/projections.ts`: projection strategies (includes `defaultProjection`)
- `src/codec.ts`: snapshot export/import + validation
- `src/index.ts`: public exports
- `test/*.test.ts`: module unit tests

## Consumers

Current consumer: `led-sphere/src/App.tsx` via Vite/TS alias `@psync/core`.
# psync
