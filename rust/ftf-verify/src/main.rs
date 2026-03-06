use ed25519_dalek::{Signature, VerifyingKey};
use hex::FromHex;
use minicbor::Encoder;
use serde::Deserialize;
use sha2::{Digest, Sha256};
use std::cmp::Ordering;
use std::collections::HashMap;
use std::io::{self, BufRead};
use thiserror::Error;

const DOMAIN_PREFIX: &[u8] = b"ftf-msg-v1\0";

#[derive(Debug, Error)]
enum FtfError {
    #[error("invalid hex in field {0}: {1}")]
    BadHex(&'static str, String),
    #[error("ed25519 key error: {0}")]
    Key(String),
    #[error("ed25519 signature error: {0}")]
    Sig(String),
    #[error("json parse error on line {0}: {1}")]
    Json(usize, String),
}

#[derive(Debug, Deserialize, Clone)]
struct MsgJson {
    v: u64,
    realm: String,
    topic: String,
    #[serde(default)]
    prev: Option<String>,
    t: u64,
    author: String,
    #[serde(default)]
    caps: Vec<String>,
    body: BodyJson,
    #[serde(default)]
    witness: Option<String>,
    sig: String,
}

#[derive(Debug, Deserialize, Clone)]
#[serde(tag = "kind")]
enum BodyJson {
    #[serde(rename = "alias_claim")]
    AliasClaim {
        id: String,
        target_hash: String,
        #[serde(default)]
        prev_alias_hash: Option<String>,
        #[serde(default)]
        note: Option<String>,
    },
}

#[derive(Debug, Clone)]
struct Msg {
    v: u64,
    realm: String,
    topic: String,
    prev: Option<Vec<u8>>,
    t: u64,
    author_pk: [u8; 32],
    caps: Vec<String>,
    body: Body,
    witness: Option<Vec<u8>>,
    sig: [u8; 64],
}

#[derive(Debug, Clone)]
enum Body {
    AliasClaim {
        id: String,
        target_hash: Vec<u8>,
        prev_alias_hash: Option<Vec<u8>>,
        note: Option<String>,
    },
}

#[derive(Debug)]
struct VerifiedItem {
    mh: Vec<u8>,
    msg: Msg,
}

fn hex_bytes(field: &'static str, s: &str) -> Result<Vec<u8>, FtfError> {
    Vec::from_hex(s).map_err(|e| FtfError::BadHex(field, e.to_string()))
}

fn hex_arr<const N: usize>(field: &'static str, s: &str) -> Result<[u8; N], FtfError> {
    let v = hex_bytes(field, s)?;
    if v.len() != N {
        return Err(FtfError::BadHex(
            field,
            format!("expected {N} bytes, got {}", v.len()),
        ));
    }
    let mut a = [0u8; N];
    a.copy_from_slice(&v);
    Ok(a)
}

fn varint_u64(mut n: u64) -> Vec<u8> {
    let mut out = Vec::new();
    loop {
        let byte = (n & 0x7f) as u8;
        n >>= 7;
        if n == 0 {
            out.push(byte);
            break;
        } else {
            out.push(byte | 0x80);
        }
    }
    out
}

fn multihash_sha2_256(preimage: &[u8]) -> Vec<u8> {
    let digest = Sha256::digest(preimage);
    let mut mh = Vec::with_capacity(2 + 32);
    mh.extend_from_slice(&varint_u64(0x12));
    mh.extend_from_slice(&varint_u64(32));
    mh.extend_from_slice(&digest);
    mh
}

fn cbor_encode_msg(msg: &Msg, blank_sig: bool) -> Vec<u8> {
    let mut buf = Vec::new();
    let mut enc = Encoder::new(&mut buf);

    enc.array(10).unwrap();
    enc.u64(msg.v).unwrap();
    enc.str(&msg.realm).unwrap();
    enc.str(&msg.topic).unwrap();

    match &msg.prev {
        None => enc.null().unwrap(),
        Some(b) => enc.bytes(b).unwrap(),
    };

    enc.u64(msg.t).unwrap();
    enc.bytes(&msg.author_pk).unwrap();

    enc.array(msg.caps.len() as u64).unwrap();
    for c in &msg.caps {
        enc.str(c).unwrap();
    }

    cbor_encode_body(&mut enc, &msg.body);

    match &msg.witness {
        None => enc.null().unwrap(),
        Some(b) => enc.bytes(b).unwrap(),
    };

    if blank_sig {
        enc.bytes(&[]).unwrap();
    } else {
        enc.bytes(&msg.sig).unwrap();
    }

    buf
}

fn cbor_encode_body(enc: &mut Encoder<&mut Vec<u8>>, body: &Body) {
    match body {
        Body::AliasClaim {
            id,
            target_hash,
            prev_alias_hash,
            note,
        } => {
            enc.array(5).unwrap();
            enc.u64(6).unwrap();
            enc.str(id).unwrap();
            enc.bytes(target_hash).unwrap();
            match prev_alias_hash {
                None => enc.null().unwrap(),
                Some(b) => enc.bytes(b).unwrap(),
            };
            match note {
                None => enc.null().unwrap(),
                Some(s) => enc.str(s).unwrap(),
            };
        }
    }
}

fn mh_msg(msg: &Msg) -> Vec<u8> {
    let cbor = cbor_encode_msg(msg, true);
    let mut pre = Vec::with_capacity(DOMAIN_PREFIX.len() + cbor.len());
    pre.extend_from_slice(DOMAIN_PREFIX);
    pre.extend_from_slice(&cbor);
    multihash_sha2_256(&pre)
}

fn verify_sig(author_pk: &[u8; 32], mh: &[u8], sig: &[u8; 64]) -> Result<(), FtfError> {
    let vk = VerifyingKey::from_bytes(author_pk).map_err(|e| FtfError::Key(e.to_string()))?;
    let sig = Signature::from_bytes(sig);
    vk.verify_strict(mh, &sig)
        .map_err(|e| FtfError::Sig(e.to_string()))
}

fn cmp_bytes(a: &[u8], b: &[u8]) -> Ordering {
    a.iter().cmp(b.iter())
}

#[derive(Debug)]
enum Reject {
    BadSig(String),
    MissingPrev,
    PrevRealmTopicMismatch,
    NonMonotoneT,
}

fn compute_verified(messages: &[Msg]) -> (Vec<VerifiedItem>, Vec<(Vec<u8>, Reject)>) {
    let mut by_mh: HashMap<Vec<u8>, Msg> = HashMap::new();
    for m in messages {
        by_mh.insert(mh_msg(m), m.clone());
    }

    let mut oks = Vec::new();
    let mut bads = Vec::new();

    for (mh, m) in &by_mh {
        if let Err(e) = verify_sig(&m.author_pk, mh, &m.sig) {
            bads.push((mh.clone(), Reject::BadSig(format!("{e}"))));
            continue;
        }

        if let Some(prev_mh) = &m.prev {
            let Some(prev) = by_mh.get(prev_mh) else {
                bads.push((mh.clone(), Reject::MissingPrev));
                continue;
            };

            if prev.realm != m.realm || prev.topic != m.topic {
                bads.push((mh.clone(), Reject::PrevRealmTopicMismatch));
                continue;
            }
            if m.t <= prev.t {
                bads.push((mh.clone(), Reject::NonMonotoneT));
                continue;
            }
        }

        oks.push(VerifiedItem {
            mh: mh.clone(),
            msg: m.clone(),
        });
    }

    oks.sort_by(|a, b| {
        let ta = a.msg.t;
        let tb = b.msg.t;
        if ta != tb {
            ta.cmp(&tb)
        } else {
            cmp_bytes(&a.mh, &b.mh)
        }
    });

    (oks, bads)
}

#[derive(Debug)]
struct AliasEntry {
    head: Vec<u8>,
    target: Vec<u8>,
}

#[derive(Debug)]
struct AliasQuarantine {
    mh: Vec<u8>,
    why: String,
}

fn resolve_aliases(replay: &[VerifiedItem]) -> (HashMap<String, AliasEntry>, Vec<AliasQuarantine>) {
    let mut state: HashMap<String, AliasEntry> = HashMap::new();
    let mut q: Vec<AliasQuarantine> = Vec::new();

    for item in replay {
        match &item.msg.body {
            Body::AliasClaim {
                id,
                target_hash,
                prev_alias_hash,
                note: _,
            } => match state.get(id) {
                None => {
                    if prev_alias_hash.is_some() {
                        q.push(AliasQuarantine {
                            mh: item.mh.clone(),
                            why: "alias first claim must have prev_alias_hash = null".into(),
                        });
                        continue;
                    }
                    state.insert(
                        id.clone(),
                        AliasEntry {
                            head: item.mh.clone(),
                            target: target_hash.clone(),
                        },
                    );
                }
                Some(cur) => {
                    if prev_alias_hash.as_deref() != Some(cur.head.as_slice()) {
                        q.push(AliasQuarantine {
                            mh: item.mh.clone(),
                            why: "prev_alias_hash mismatch / fork => quarantine".into(),
                        });
                        continue;
                    }
                    state.insert(
                        id.clone(),
                        AliasEntry {
                            head: item.mh.clone(),
                            target: target_hash.clone(),
                        },
                    );
                }
            },
        }
    }

    (state, q)
}

fn parse_msg(line_no: usize, line: &str) -> Result<Msg, FtfError> {
    let j: MsgJson = serde_json::from_str(line).map_err(|e| FtfError::Json(line_no, e.to_string()))?;

    let prev = match j.prev {
        None => None,
        Some(h) => Some(hex_bytes("prev", &h)?),
    };
    let witness = match j.witness {
        None => None,
        Some(h) => Some(hex_bytes("witness", &h)?),
    };

    let author_pk = hex_arr::<32>("author", &j.author)?;
    let sig = hex_arr::<64>("sig", &j.sig)?;

    let body = match j.body {
        BodyJson::AliasClaim {
            id,
            target_hash,
            prev_alias_hash,
            note,
        } => Body::AliasClaim {
            id,
            target_hash: hex_bytes("target_hash", &target_hash)?,
            prev_alias_hash: match prev_alias_hash {
                None => None,
                Some(h) => Some(hex_bytes("prev_alias_hash", &h)?),
            },
            note,
        },
    };

    Ok(Msg {
        v: j.v,
        realm: j.realm,
        topic: j.topic,
        prev,
        t: j.t,
        author_pk,
        caps: j.caps,
        body,
        witness,
        sig,
    })
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut args = std::env::args().skip(1).collect::<Vec<_>>();
    if args.is_empty() {
        eprintln!("usage:");
        eprintln!("  verify-topic <realm> <topic>        (reads NDJSON from stdin)");
        eprintln!("  resolve-alias <realm> <aliasTopic> <logical_id>   (reads NDJSON from stdin)");
        std::process::exit(2);
    }

    let cmd = args.remove(0);
    let stdin = io::stdin();
    let mut messages: Vec<Msg> = Vec::new();

    for (i, line) in stdin.lock().lines().enumerate() {
        let ln = i + 1;
        let line = line?;
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }
        let msg = parse_msg(ln, trimmed).map_err(|e| {
            eprintln!("{e}");
            e
        })?;
        messages.push(msg);
    }

    let (verified, rejected) = compute_verified(&messages);

    match cmd.as_str() {
        "verify-topic" => {
            if args.len() != 2 {
                eprintln!("verify-topic <realm> <topic>");
                std::process::exit(2);
            }
            let realm = &args[0];
            let topic = &args[1];

            let mut vcount = 0usize;
            for it in &verified {
                if it.msg.realm == *realm && it.msg.topic == *topic {
                    vcount += 1;
                }
            }
            println!("verified={vcount}");
            for it in &verified {
                if it.msg.realm == *realm && it.msg.topic == *topic {
                    println!("OK {} t={}", hex::encode(&it.mh), it.msg.t);
                }
            }
            println!("rejected={}", rejected.len());
            for (mh, rr) in rejected {
                if let Reject::BadSig(reason) = &rr {
                    let _ = reason.len();
                }
                println!("BAD {} reason={:?}", hex::encode(mh), rr);
            }
        }
        "resolve-alias" => {
            if args.len() != 3 {
                eprintln!("resolve-alias <realm> <aliasTopic> <logical_id>");
                std::process::exit(2);
            }
            let realm = &args[0];
            let alias_topic = &args[1];
            let logical_id = &args[2];

            let replay: Vec<VerifiedItem> = verified
                .into_iter()
                .filter(|it| it.msg.realm == *realm && it.msg.topic == *alias_topic)
                .collect();

            let (state, q) = resolve_aliases(&replay);
            println!("quarantine={}", q.len());
            for item in q {
                println!("Q {} why={}", hex::encode(item.mh), item.why);
            }

            match state.get(logical_id) {
                None => println!("not_found"),
                Some(e) => {
                    println!("target_hash={}", hex::encode(&e.target));
                }
            }
        }
        _ => {
            eprintln!("unknown cmd: {cmd}");
            std::process::exit(2);
        }
    }

    Ok(())
}
