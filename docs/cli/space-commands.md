# Space Commands

Status: draft operator reference for `v0.2.0`.  
Normative protocol behavior remains in `PROTOCOL.md`.

## `ftf space new <name>`

- Args: `<name>`
- Flags: `--mnemonic`, `--no-mnemonic`, `--realm <realm>`, `--path <dir>`
- Output:
  - `Space: <name>`
  - `Realm: <realm>`
  - `Mnemonic: <words>` when enabled
  - `Space ID: <mh>`
  - `Created: <path>`
- Side effects:
  - creates `.ftf/spaces/<name>/`
  - creates `space.json`
  - initializes `topics/`, `cas/`, `keys/`
- Failure modes:
  - space already exists
  - invalid realm
  - path not writable
  - key generation failure

## `ftf space show <name>`

- Args: `<name>`
- Flags: none
- Output:
  - realm
  - space id
  - member count
  - topic count
  - CAS object count
  - active identity
- Side effects: none
- Failure modes:
  - space not found
  - invalid/corrupt `space.json`

## `ftf space ls`

- Args: none
- Flags: none
- Output:
  - one row per space
  - `name realm members`
- Side effects: none
- Failure modes:
  - unreadable `.ftf/spaces`

## `ftf space export <name>`

- Args: `<name>`
- Flags: `--public`, `--bundle`, `--member <id>`
- Output:
  - export bundle to stdout or file path
- Side effects:
  - reads local space metadata
- Failure modes:
  - space not found
  - member not found
  - invalid export mode combination

## `ftf space import <file>`

- Args: `<file>`
- Flags: none
- Output:
  - imported space or bundle summary
- Side effects:
  - creates or updates local space files
- Failure modes:
  - file missing
  - invalid bundle format
  - realm/space collision

## `ftf identity new`

- Args: none
- Flags: `--mnemonic`, `--no-mnemonic`, `--out <path>`
- Output:
  - mnemonic when enabled
  - public key
  - peer id
- Side effects:
  - writes key material when `--out` is used
- Failure modes:
  - key generation failure
  - output path not writable

## `ftf identity derive`

- Args: none
- Flags: `--space <space>`, `--path <hd-path>`, `--role <role>`
- Output:
  - derived public key
  - peer id
  - derivation path used
- Side effects:
  - may write derived member identity into local keys store
- Failure modes:
  - space not found
  - invalid derivation path
  - unknown role
  - missing root material

## `ftf identity show`

- Args: none
- Flags: `--space <space>`
- Output:
  - active member id
  - public key
  - peer id
- Side effects: none
- Failure modes:
  - space not found
  - no active identity configured

## `ftf identity use`

- Args: none
- Flags: `--space <space>`, `--member <id>`
- Output:
  - active signer confirmation
- Side effects:
  - updates `active_member` in `space.json`
- Failure modes:
  - space not found
  - member not found

## `ftf space member add <space> <name>`

- Args: `<space> <name>`
- Flags: `--pubkey <hex>`, `--role <role>`
- Output:
  - member id
  - role
  - pubkey fragment
- Side effects:
  - updates `members.json`
- Failure modes:
  - space not found
  - invalid pubkey
  - duplicate member id

## `ftf space invite <space>`

- Args: `<space>`
- Flags: `--role <role>`, `--out <path>`
- Output:
  - signed invitation bundle
- Side effects:
  - reads local space metadata
  - writes bundle when `--out` is used
- Failure modes:
  - space not found
  - unsupported role
  - output path not writable

## `ftf put <path>`

- Args: `<path>`
- Flags: `--space <space>`, `--topic <topic>`, `--name <label>`, `--tag <tag>`
- Output:
  - `artifact: <mh>`
  - `event: <mh>`
  - `topic: <topic>`
- Side effects:
  - stores blob in space CAS
  - appends signed `put` to topic log
- Failure modes:
  - file missing
  - space not found
  - no active identity
  - CAS write failure

## `ftf xform <label>`

- Args: `<label>`
- Flags:
  - `--space <space>`
  - `--input <hash-or-path>` (repeatable)
  - `--output <hash-or-path>` (repeatable)
  - `--tool <hash>`
  - `--params <file>`
  - `--receipt <file>`
  - `--topic <topic>`
- Output:
  - output artifact hashes
  - event hash
  - topic
- Side effects:
  - stores local output blobs when paths are provided
  - appends signed `xform` to topic log
- Failure modes:
  - missing input/output
  - unresolved path/hash
  - invalid tool/params/receipt hash
  - no active identity

## `ftf attest <hash-or-path-or-alias>`

- Args: `<hash-or-path-or-alias>`
- Flags:
  - `--space <space>`
  - `--claim <claim>`
  - `--evidence <hash>` (repeatable)
  - `--evidence-file <path>` (repeatable)
  - `--topic <topic>`
- Output:
  - resolved target
  - event hash
  - claim
- Side effects:
  - appends signed `attest` to topic log
- Failure modes:
  - unresolved target
  - missing `--claim`
  - invalid evidence hash/path
  - no active identity

## `ftf revoke <hash-or-path-or-alias>`

- Args: `<hash-or-path-or-alias>`
- Flags:
  - `--space <space>`
  - `--reason <reason>`
  - `--superseded-by <hash>`
  - `--topic <topic>`
- Output:
  - resolved target
  - event hash
  - reason
- Side effects:
  - appends signed `revoke` to topic log
- Failure modes:
  - unresolved target
  - missing `--reason`
  - invalid `--superseded-by`
  - no active identity

## `ftf alias set <logical-id> <hash>`

- Args: `<logical-id> <hash>`
- Flags: `--space <space>`, `--topic <topic>`
- Output:
  - logical id
  - target hash
  - alias event hash
- Side effects:
  - appends signed `alias_claim` to alias topic
- Failure modes:
  - invalid hash
  - space not found
  - no active identity

## `ftf alias get <logical-id>`

- Args: `<logical-id>`
- Flags: `--space <space>`
- Output:
  - target hash or `not_found`
  - resolution/quarantine summary
- Side effects: none
- Failure modes:
  - space not found
  - alias topic unreadable

## `ftf alias ls`

- Args: none
- Flags: `--space <space>`
- Output:
  - logical id rows with target/status
- Side effects: none
- Failure modes:
  - space not found
  - alias topic unreadable

## `ftf trace <hash-or-alias-or-path>`

- Args: `<hash-or-alias-or-path>`
- Flags: `--space <space>`, `--topic <topic>`, `--pretty`
- Output:
  - NDJSON by default
  - terminal tree with `--pretty`
- Side effects: none
- Failure modes:
  - unresolved target
  - root artifact not found in verified `put`/`xform` outputs
  - topic unreadable

## `ftf verify`

- Args: none
- Flags: `--space <space>`, `--topic <topic>`, `--strict`, `--json`, `--check-cas`
- Output:
  - verified count
  - rejected count
  - alias validity summary when applicable
- Side effects: none
- Failure modes:
  - space not found
  - topic unreadable
  - invalid topic stream format

## `ftf sync pull <space> <bundle-or-peer>`

- Args: `<space> <bundle-or-peer>`
- Flags: none
- Output:
  - imported heads/topics summary
- Side effects:
  - updates local topics/CAS from bundle or peer source
- Failure modes:
  - space not found
  - source unreadable
  - invalid bundle format

## `ftf sync push <space> <bundle-or-peer>`

- Args: `<space> <bundle-or-peer>`
- Flags: none
- Output:
  - exported heads/topics summary
- Side effects:
  - writes bundle or sends data to peer transport wrapper
- Failure modes:
  - space not found
  - destination unwritable

## `ftf sync heads <space>`

- Args: `<space>`
- Flags: none
- Output:
  - current topic heads
- Side effects: none
- Failure modes:
  - space not found
  - topics unreadable
