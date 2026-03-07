(function () {
  const state = {
    data: null,
    proofs: [],
    selectedView: "verified",
    selected: null,
    frontierT: null,
    uploadedProofs: {},
    lens: {
      realm: "ftf",
      topic: "provenance/demo"
    }
  };

  const els = {
    nav: document.getElementById("viewNav"),
    views: Array.from(document.querySelectorAll(".view-panel")),
    rootInput: document.getElementById("rootInput"),
    topicInput: document.getElementById("topicInput"),
    realmInput: document.getElementById("realmInput"),
    applyLens: document.getElementById("applyLens"),
    replayStrip: document.getElementById("replayStrip"),
    rejectedCount: document.getElementById("rejectedCount"),
    rejectedList: document.getElementById("rejectedList"),
    rootBanner: document.getElementById("rootBanner"),
    scrubber: document.getElementById("timelineScrubber"),
    scrubberLabel: document.getElementById("scrubberLabel"),
    traceSvg: document.getElementById("traceSvg"),
    artifactTable: document.getElementById("artifactTable"),
    eventTable: document.getElementById("eventTable"),
    artifactSearch: document.getElementById("artifactSearch"),
    eventSearch: document.getElementById("eventSearch"),
    aliasChains: document.getElementById("aliasChains"),
    proofCards: document.getElementById("proofCards"),
    proofDoc: document.querySelector("#proofDoc pre"),
    wireDoc: document.getElementById("wireDoc"),
    selectionLabel: document.getElementById("selectionLabel"),
    insTabs: Array.from(document.querySelectorAll(".ins-tab")),
    insPanes: {
      summary: document.getElementById("ins-summary"),
      raw: document.querySelector("#ins-raw pre"),
      notes: document.getElementById("ins-notes"),
      edges: document.getElementById("ins-edges")
    },
    dropzone: document.getElementById("dropzone"),
    fileInput: document.getElementById("fileInput")
  };

  function shortHash(h) {
    if (!h || typeof h !== "string") return "-";
    return h.length > 18 ? `${h.slice(0, 10)}...${h.slice(-4)}` : h;
  }

  function esc(text) {
    return String(text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  function parseEmbedded() {
    const trace = JSON.parse(document.getElementById("sample-trace").textContent);
    const proofs = JSON.parse(document.getElementById("sample-proofs").textContent).map((p) => ({ ...p, source: "embedded" }));
    state.data = normalizeData(trace);
    state.proofs = proofs;
    state.frontierT = maxT(state.data.events, state.data.notes);
  }

  async function fetchJson(path) {
    const res = await fetch(path, { cache: "no-store" });
    if (!res.ok) throw new Error(`${path} -> ${res.status}`);
    return res.json();
  }

  async function fetchText(path) {
    const res = await fetch(path, { cache: "no-store" });
    if (!res.ok) throw new Error(`${path} -> ${res.status}`);
    return res.text();
  }

  async function hydrateHostedData() {
    let manifest;
    try {
      manifest = await fetchJson("docs/observatory-manifest.json");
    } catch (_e) {
      return;
    }

    if (manifest.defaultTrace) {
      try {
        const traceObj = await fetchJson(manifest.defaultTrace);
        state.data = normalizeData(traceObj);
        state.frontierT = maxT(state.data.events, state.data.notes);
      } catch (_e) {
      }
    }

    if (Array.isArray(manifest.proofs)) {
      const embeddedById = Object.fromEntries(state.proofs.map((p) => [p.id, p]));
      const merged = [];
      for (const spec of manifest.proofs) {
        const base = {
          id: spec.id,
          title: spec.title || spec.id,
          establishes: spec.establishes || "",
          command: spec.command || "n/a",
          timestamp: spec.timestamp || "-",
          summary: spec.summary || "",
          source: "embedded",
          content: ""
        };

        const fallback = embeddedById[spec.id] || null;
        if (fallback) Object.assign(base, fallback);
        if (typeof spec.path === "string") {
          try {
            const text = await fetchText(spec.path);
            base.content = text;
            base.source = "fetched";
          } catch (_e) {
          }
        }
        merged.push(base);
      }
      if (merged.length) state.proofs = merged;
    }
  }

  function maxT(events, notes) {
    const ts = [];
    events.forEach((e) => ts.push(Number(e.t || 0)));
    notes.forEach((n) => {
      if (typeof n.t !== "undefined") ts.push(Number(n.t || 0));
    });
    return ts.length ? Math.max(...ts) : 0;
  }

  function normalizeData(raw) {
    const artifacts = Array.isArray(raw.artifacts) ? raw.artifacts : [];
    const events = Array.isArray(raw.events) ? raw.events : [];
    const notes = Array.isArray(raw.notes) ? raw.notes : [];
    const edges = Array.isArray(raw.edges) ? raw.edges : [];
    const aliases = Array.isArray(raw.aliases) ? raw.aliases : [];
    return {
      header: raw.header || { root: "" },
      artifacts,
      events,
      notes,
      edges,
      aliases,
      replay: buildReplay(events, notes)
    };
  }

  function buildReplay(events, notes) {
    const fromEvents = events.map((e) => ({
      t: Number(e.t || 0),
      mh: e.mh,
      kind: e.etype || "event",
      author: e.author || "-",
      verified: true
    }));
    const fromNotes = notes
      .filter((n) => n.mh)
      .map((n) => ({
        t: Number(n.t || 0),
        mh: n.mh,
        kind: n.note_type || "note",
        author: n.author || "-",
        verified: true
      }));
    return fromEvents
      .concat(fromNotes)
      .sort((a, b) => (a.t - b.t) || String(a.mh).localeCompare(String(b.mh)));
  }

  function attachUI() {
    els.nav.addEventListener("click", (e) => {
      const btn = e.target.closest(".view-tab");
      if (!btn) return;
      setView(btn.dataset.view);
    });

    els.insTabs.forEach((tab) => {
      tab.addEventListener("click", () => setInspectorPane(tab.dataset.pane));
    });

    els.applyLens.addEventListener("click", () => {
      const root = els.rootInput.value.trim();
      state.lens.realm = els.realmInput.value.trim() || state.lens.realm;
      state.lens.topic = els.topicInput.value.trim() || state.lens.topic;
      if (root) state.data.header.root = root;
      renderAll();
    });

    els.scrubber.addEventListener("input", () => {
      state.frontierT = Number(els.scrubber.value);
      renderTrace();
    });

    els.artifactSearch.addEventListener("input", renderArtifactTable);
    els.eventSearch.addEventListener("input", renderEventTable);

    ["dragenter", "dragover"].forEach((type) => {
      els.dropzone.addEventListener(type, (e) => {
        e.preventDefault();
        els.dropzone.classList.add("dragover");
      });
    });

    ["dragleave", "drop"].forEach((type) => {
      els.dropzone.addEventListener(type, (e) => {
        e.preventDefault();
        els.dropzone.classList.remove("dragover");
      });
    });

    els.dropzone.addEventListener("drop", (e) => {
      loadFiles(Array.from(e.dataTransfer.files || []));
    });

    els.fileInput.addEventListener("change", (e) => {
      loadFiles(Array.from(e.target.files || []));
      e.target.value = "";
    });
  }

  function setView(view) {
    state.selectedView = view;
    document.querySelectorAll(".view-tab").forEach((b) => b.classList.toggle("is-active", b.dataset.view === view));
    els.views.forEach((v) => v.classList.toggle("is-active", v.id === `view-${view}`));
  }

  function setInspectorPane(name) {
    els.insTabs.forEach((b) => b.classList.toggle("is-active", b.dataset.pane === name));
    Object.entries(els.insPanes).forEach(([k, v]) => {
      if (k === "raw") {
        const parent = v.parentElement;
        parent.classList.toggle("is-active", k === name);
      } else {
        v.classList.toggle("is-active", k === name);
      }
    });
  }

  function selectRecord(type, payload) {
    state.selected = { type, payload };
    els.selectionLabel.textContent = `${type} • ${shortHash(payload.h || payload.mh || payload.id || payload.from || "")}`;

    const summary = [];
    Object.keys(payload).forEach((k) => {
      summary.push(`<dt>${esc(k)}</dt><dd>${esc(typeof payload[k] === "object" ? JSON.stringify(payload[k]) : payload[k])}</dd>`);
    });
    els.insPanes.summary.innerHTML = `<dl class="ins-card">${summary.join("")}</dl>`;
    els.insPanes.raw.textContent = JSON.stringify(payload, null, 2);

    const notes = relatedNotes(type, payload);
    els.insPanes.notes.innerHTML = notes.length
      ? notes.map((n) => `<div><span class="badge ${esc(n.note_type)}">${esc(n.note_type)}</span> ${esc(n.claim || n.reason || n.about || "")}</div>`).join("")
      : "<p>No notes</p>";

    const edges = relatedEdges(type, payload);
    els.insPanes.edges.innerHTML = edges.length
      ? `<ul>${edges.map((e) => `<li>${esc(e.from)} <strong>${esc(e.rel)}</strong> ${esc(e.to)}</li>`).join("")}</ul>`
      : "<p>No edges</p>";
  }

  function relatedNotes(type, payload) {
    if (!state.data) return [];
    const key = type === "event" ? `event:${payload.mh}` : type === "artifact" ? `artifact:${payload.h}` : null;
    if (!key) return [];
    return state.data.notes.filter((n) => n.about === key);
  }

  function relatedEdges(type, payload) {
    if (!state.data) return [];
    const key = type === "event" ? `event:${payload.mh}` : type === "artifact" ? `artifact:${payload.h}` : null;
    if (!key) return [];
    return state.data.edges.filter((e) => e.from === key || e.to === key);
  }

  function renderAll() {
    if (!state.data) return;
    els.rootInput.value = state.data.header.root || "";
    els.topicInput.value = state.lens.topic;
    els.realmInput.value = state.lens.realm;

    renderVerified();
    renderAliases();
    renderTrace();
    renderArtifactTable();
    renderEventTable();
    renderProofs();
    renderWire();

    const max = maxT(state.data.events, state.data.notes);
    els.scrubber.min = 0;
    els.scrubber.max = max;
    if (state.frontierT === null || state.frontierT > max) state.frontierT = max;
    els.scrubber.value = state.frontierT;
    els.scrubberLabel.textContent = `t <= ${state.frontierT}`;
  }

  function renderVerified() {
    const replay = state.data.replay;
    els.replayStrip.innerHTML = replay.map((r) => `
      <article class="replay-card" data-hash="${esc(r.mh)}">
        <div class="k">t=${esc(r.t)} • ${esc(r.kind)}</div>
        <div class="hash">${esc(shortHash(r.mh))}</div>
        <div class="k">author ${esc(shortHash(r.author))}</div>
      </article>
    `).join("");

    els.replayStrip.querySelectorAll(".replay-card").forEach((card) => {
      card.addEventListener("click", () => {
        const mh = card.dataset.hash;
        const event = state.data.events.find((e) => e.mh === mh);
        const note = state.data.notes.find((n) => n.mh === mh);
        if (event) selectRecord("event", event);
        if (note) selectRecord("note", note);
      });
    });

    els.rejectedCount.textContent = "0";
    els.rejectedList.innerHTML = "<p>No rejected messages in current loaded stream.</p>";
  }

  function renderAliases() {
    const groups = {};
    state.data.aliases.forEach((a) => {
      if (!groups[a.id]) groups[a.id] = [];
      groups[a.id].push(a);
    });

    const ids = Object.keys(groups).sort();
    els.aliasChains.innerHTML = ids.length
      ? ids.map((id) => {
        const items = groups[id].sort((a, b) => (a.t || 0) - (b.t || 0));
        return `
          <article class="alias-card">
            <h3>${esc(id)}</h3>
            ${items.map((it) => `
              <div class="alias-item ${esc(it.status || "ok")}">
                <div><strong>${esc(shortHash(it.target))}</strong></div>
                <div class="k">t=${esc(it.t || "-")} • ${esc(it.status || "ok")}</div>
                ${it.reason ? `<div class="k">reason: ${esc(it.reason)}</div>` : ""}
              </div>
            `).join("")}
          </article>
        `;
      }).join("")
      : "<p>No alias claims loaded.</p>";
  }

  function visibleEvents() {
    return state.data.events.filter((e) => Number(e.t || 0) <= state.frontierT);
  }

  function renderTrace() {
    els.scrubberLabel.textContent = `t <= ${state.frontierT}`;

    const events = visibleEvents();
    const produced = new Set();
    const consumed = new Set();
    events.forEach((e) => {
      (e.outputs || []).forEach((h) => produced.add(h));
      (e.inputs || []).forEach((h) => consumed.add(h));
      if (e.artifact) produced.add(e.artifact);
    });

    const artifacts = state.data.artifacts.filter((a) => {
      if (a.h === state.data.header.root) return true;
      return produced.has(a.h) || consumed.has(a.h);
    });

    const eventByMh = Object.fromEntries(events.map((e) => [e.mh, e]));

    const root = state.data.header.root;
    const depths = {};
    depths[root] = 0;
    const producerEventsByOutput = {};
    events.forEach((e) => {
      (e.outputs || []).forEach((out) => {
        if (!producerEventsByOutput[out]) producerEventsByOutput[out] = [];
        producerEventsByOutput[out].push(e);
      });
      if (e.artifact) {
        if (!producerEventsByOutput[e.artifact]) producerEventsByOutput[e.artifact] = [];
        producerEventsByOutput[e.artifact].push(e);
      }
    });

    const queue = [root];
    while (queue.length) {
      const art = queue.shift();
      const base = depths[art] || 0;
      (producerEventsByOutput[art] || []).forEach((evt) => {
        (evt.inputs || []).forEach((inp) => {
          if (typeof depths[inp] === "undefined") {
            depths[inp] = base + 1;
            queue.push(inp);
          }
        });
      });
    }

    artifacts.forEach((a) => {
      if (typeof depths[a.h] === "undefined") depths[a.h] = 1;
    });

    const groups = {};
    artifacts
      .slice()
      .sort((a, b) => String(a.h).localeCompare(String(b.h)))
      .forEach((a) => {
        const d = depths[a.h] || 0;
        if (!groups[d]) groups[d] = [];
        groups[d].push(a);
      });

    const width = 1200;
    const startX = width - 170;
    const gapX = 220;
    const nodePos = {};

    Object.keys(groups).map(Number).sort((a, b) => a - b).forEach((d) => {
      const ys = groups[d];
      ys.forEach((a, idx) => {
        nodePos[`artifact:${a.h}`] = { x: startX - d * gapX, y: 90 + idx * 130 };
      });
    });

    events
      .slice()
      .sort((a, b) => (a.t - b.t) || String(a.mh).localeCompare(String(b.mh)))
      .forEach((e, idx) => {
        const outs = (e.outputs || []).concat(e.artifact ? [e.artifact] : []);
        const outPos = outs.map((h) => nodePos[`artifact:${h}`]).filter(Boolean);
        const inPos = (e.inputs || []).map((h) => nodePos[`artifact:${h}`]).filter(Boolean);
        const ax = outPos.length ? outPos.reduce((s, p) => s + p.x, 0) / outPos.length : 780;
        const bx = inPos.length ? inPos.reduce((s, p) => s + p.x, 0) / inPos.length : ax - 160;
        const ay = outPos.length ? outPos.reduce((s, p) => s + p.y, 0) / outPos.length : 220 + idx * 40;
        const by = inPos.length ? inPos.reduce((s, p) => s + p.y, 0) / inPos.length : ay;
        nodePos[`event:${e.mh}`] = { x: (ax + bx) / 2, y: (ay + by) / 2 + 130 };
      });

    const lines = state.data.edges.filter((edge) => {
      const from = nodePos[edge.from];
      const to = nodePos[edge.to];
      return from && to;
    }).map((edge, i) => {
      const p1 = nodePos[edge.from];
      const p2 = nodePos[edge.to];
      return `<g>
        <line class="trace-edge" data-edge="${i}" x1="${p1.x}" y1="${p1.y}" x2="${p2.x}" y2="${p2.y}" stroke="#5b6570" stroke-width="1.4" marker-end="url(#arrow)" />
      </g>`;
    }).join("");

    const artifactNodes = artifacts.map((a) => {
      const p = nodePos[`artifact:${a.h}`];
      if (!p) return "";
      return `
        <g class="trace-node artifact" data-type="artifact" data-id="${esc(a.h)}" transform="translate(${p.x - 92},${p.y - 26})">
          <rect width="184" height="52" rx="8" fill="#1f2730" stroke="#7f8b96" />
          <rect class="status-ring ${esc(a.status)}" x="-4" y="-4" width="192" height="60" rx="10" fill="none" stroke-width="2" />
          <text class="trace-label" x="12" y="22">${esc(shortHash(a.h))}</text>
          <text class="trace-label" x="12" y="40" fill="#9ea89f">${esc(a.role)} • ${esc(a.status)}</text>
        </g>
      `;
    }).join("");

    const eventNodes = events.map((e) => {
      const p = nodePos[`event:${e.mh}`];
      if (!p) return "";
      const kind = e.etype || "event";
      if (kind === "xform") {
        return `
          <g class="trace-node event" data-type="event" data-id="${esc(e.mh)}" transform="translate(${p.x},${p.y})">
            <path d="M0 -30 L70 0 L0 30 L-70 0 Z" fill="#26313a" stroke="#91a0ad" />
            <text class="trace-label" x="-28" y="-2">xform t=${esc(e.t)}</text>
            <text class="trace-label" x="-42" y="14" fill="#9ea89f">${esc(shortHash(e.mh))}</text>
          </g>
        `;
      }
      return `
        <g class="trace-node event" data-type="event" data-id="${esc(e.mh)}" transform="translate(${p.x - 60},${p.y - 18})">
          <rect width="120" height="36" rx="18" fill="#27333d" stroke="#91a0ad" />
          <text class="trace-label" x="14" y="22">${esc(kind)} t=${esc(e.t)}</text>
        </g>
      `;
    }).join("");

    const noteNodes = state.data.notes.filter((n) => {
      const t = typeof n.t === "undefined" ? 0 : Number(n.t || 0);
      return t <= state.frontierT || typeof n.t === "undefined";
    }).map((n) => {
      const anchor = nodePos[n.about];
      if (!anchor) return "";
      const cls = n.note_type || "note";
      const dx = cls === "revoke" ? 56 : 24;
      const dy = cls === "pending_fetch" ? -52 : -36;
      return `
        <g class="note-chip ${esc(cls)}" data-type="note" data-id="${esc(n.mh || n.about)}" transform="translate(${anchor.x + dx},${anchor.y + dy})">
          <rect width="106" height="24" rx="12" />
          <text x="8" y="16">${esc(cls)}</text>
        </g>
      `;
    }).join("");

    els.traceSvg.innerHTML = `
      <defs>
        <marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="3.5" orient="auto">
          <polygon points="0 0, 8 3.5, 0 7" fill="#6d7882"></polygon>
        </marker>
      </defs>
      <rect width="1200" height="620" fill="#11161b"></rect>
      ${lines}
      ${artifactNodes}
      ${eventNodes}
      ${noteNodes}
      <text class="trace-label" x="20" y="24" fill="#9ea89f">append-only • canonical cbor • sorted by (t, mh)</text>
    `;

    els.traceSvg.querySelectorAll(".trace-node, .note-chip").forEach((node) => {
      node.addEventListener("click", () => {
        const type = node.getAttribute("data-type");
        const id = node.getAttribute("data-id");
        if (type === "artifact") {
          const art = state.data.artifacts.find((a) => a.h === id);
          if (art) selectRecord("artifact", art);
        } else if (type === "event") {
          const evt = eventByMh[id];
          if (evt) selectRecord("event", evt);
        } else if (type === "note") {
          const note = state.data.notes.find((n) => (n.mh || n.about) === id);
          if (note) selectRecord("note", note);
        }
      });
    });

    const stats = {
      artifacts: artifacts.length,
      transforms: events.filter((e) => e.etype === "xform").length,
      notes: state.data.notes.length
    };
    const rootArtifact = state.data.artifacts.find((a) => a.h === state.data.header.root);
    els.rootBanner.innerHTML = `
      <span><strong>Root</strong> <span class="hash">${esc(shortHash(state.data.header.root))}</span></span>
      <span><strong>Status</strong> <span class="badge ${esc((rootArtifact && rootArtifact.status) || "pending_fetch")}">${esc((rootArtifact && rootArtifact.status) || "pending_fetch")}</span></span>
      <span><strong>Artifacts</strong> ${stats.artifacts}</span>
      <span><strong>Transforms</strong> ${stats.transforms}</span>
      <span><strong>Notes</strong> ${stats.notes}</span>
    `;
  }

  function renderArtifactTable() {
    const q = els.artifactSearch.value.trim().toLowerCase();
    const byProd = {};
    const byCons = {};
    state.data.edges.forEach((e) => {
      if (e.rel === "produces" && e.to.startsWith("artifact:")) {
        byProd[e.to.replace("artifact:", "")] = e.from.replace("event:", "");
      }
      if (e.rel === "consumed_by" && e.from.startsWith("artifact:")) {
        const h = e.from.replace("artifact:", "");
        byCons[h] = (byCons[h] || 0) + 1;
      }
    });

    const rows = state.data.artifacts
      .filter((a) => {
        const s = `${a.h} ${a.status} ${a.role}`.toLowerCase();
        return !q || s.includes(q);
      })
      .sort((a, b) => String(a.h).localeCompare(String(b.h)));

    els.artifactTable.innerHTML = rows.map((a) => {
      const producer = byProd[a.h] || "-";
      const firstSeen = state.data.events
        .filter((e) => (e.outputs || []).includes(a.h) || e.artifact === a.h || (e.inputs || []).includes(a.h))
        .map((e) => Number(e.t || 0));
      const t = firstSeen.length ? Math.min(...firstSeen) : "-";
      return `
        <tr data-hash="${esc(a.h)}">
          <td>${esc(shortHash(a.h))}</td>
          <td><span class="badge ${esc(a.status)}">${esc(a.status)}</span></td>
          <td>${esc(shortHash(producer))}</td>
          <td>${esc(byCons[a.h] || 0)}</td>
          <td>${esc(t)}</td>
        </tr>
      `;
    }).join("");

    els.artifactTable.querySelectorAll("tr").forEach((tr) => {
      tr.addEventListener("click", () => {
        const hash = tr.dataset.hash;
        const art = state.data.artifacts.find((a) => a.h === hash);
        if (art) {
          selectRecord("artifact", art);
          setView("trace");
        }
      });
    });
  }

  function renderEventTable() {
    const q = els.eventSearch.value.trim().toLowerCase();
    const rows = state.data.events
      .slice()
      .sort((a, b) => (a.t - b.t) || String(a.mh).localeCompare(String(b.mh)))
      .filter((e) => {
        const summary = `${e.etype} ${e.mh} ${e.author} ${(e.outputs || []).join(" ")} ${(e.inputs || []).join(" ")}`.toLowerCase();
        return !q || summary.includes(q);
      });

    els.eventTable.innerHTML = rows.map((e) => {
      const summary = e.etype === "put"
        ? `artifact ${shortHash(e.artifact)}`
        : `in:${(e.inputs || []).length} out:${(e.outputs || []).length}`;
      return `
        <tr data-hash="${esc(e.mh)}">
          <td>${esc(e.t)}</td>
          <td>${esc(e.etype)}</td>
          <td>${esc(shortHash(e.mh))}</td>
          <td>${esc(shortHash(e.author || ""))}</td>
          <td>${esc(summary)}</td>
        </tr>
      `;
    }).join("");

    els.eventTable.querySelectorAll("tr").forEach((tr) => {
      tr.addEventListener("click", () => {
        const hash = tr.dataset.hash;
        const evt = state.data.events.find((e) => e.mh === hash);
        if (evt) {
          selectRecord("event", evt);
          setView("trace");
        }
      });
    });
  }

  function renderProofs() {
    const proofs = state.proofs;
    els.proofCards.innerHTML = proofs.map((p, idx) => `
      <article class="proof-card ${idx === 0 ? "is-active" : ""}" data-id="${esc(p.id)}">
        <h3>${esc(p.title)}</h3>
        <p>${esc(p.establishes)}</p>
        <div class="k">${esc(p.timestamp)}</div>
        <div class="k">${esc(p.command)}</div>
        <div class="k source-label">source: ${esc(p.source || "embedded")}</div>
      </article>
    `).join("");

    if (proofs[0]) {
      els.proofDoc.textContent = proofs[0].content || proofs[0].summary;
    }

    els.proofCards.querySelectorAll(".proof-card").forEach((card) => {
      card.addEventListener("click", () => {
        const id = card.dataset.id;
        const proof = proofs.find((p) => p.id === id);
        if (!proof) return;
        els.proofCards.querySelectorAll(".proof-card").forEach((c) => c.classList.remove("is-active"));
        card.classList.add("is-active");
        els.proofDoc.textContent = proof.content || proof.summary;
      });
    });
  }

  function renderWire() {
    const wire = state.proofs.find((p) => p.id === "wire-conformance.latest.md");
    if (!wire) {
      els.wireDoc.innerHTML = "<p>No wire conformance receipt loaded.</p>";
      return;
    }
    els.wireDoc.innerHTML = `
      <h3>${esc(wire.title)}</h3>
      <p>${esc(wire.establishes)}</p>
      <p><strong>Command</strong> <code>${esc(wire.command)}</code></p>
      <p><strong>Timestamp</strong> ${esc(wire.timestamp)}</p>
      <p><strong>Source</strong> ${esc(wire.source || "embedded")}</p>
      <p><strong>Summary</strong> ${esc(wire.summary)}</p>
      <pre>${esc(wire.content || "")}</pre>
    `;
  }

  async function loadFiles(files) {
    if (!files.length) return;
    for (const file of files) {
      const text = await file.text();
      const name = file.name.toLowerCase();

      if (name.endsWith(".ndjson")) {
        const lines = text.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
        const records = lines.map((l) => {
          try {
            return JSON.parse(l);
          } catch (_e) {
            return null;
          }
        }).filter(Boolean);

        const traceKinds = records.filter((r) => String(r.kind || "").startsWith("trace."));
        if (traceKinds.length) {
          state.data = normalizeData(ndjsonToTrace(records));
          state.frontierT = maxT(state.data.events, state.data.notes);
        }
      } else if (name.endsWith(".json")) {
        try {
          const obj = JSON.parse(text);
          if (obj && obj.header && Array.isArray(obj.events)) {
            state.data = normalizeData(obj);
            state.frontierT = maxT(state.data.events, state.data.notes);
          }
        } catch (_e) {
        }
      } else if (name.endsWith(".md") || name.endsWith(".txt")) {
        state.uploadedProofs[file.name] = text;
        const existing = state.proofs.find((p) => p.id === file.name);
        if (existing) {
          existing.content = text;
          existing.source = "dropped";
        } else {
          state.proofs.push({
            id: file.name,
            title: file.name,
            establishes: "Loaded from local file drop",
            command: "n/a",
            timestamp: new Date().toISOString(),
            summary: "User-loaded receipt",
            source: "dropped",
            content: text
          });
        }
      }
    }
    renderAll();
  }

  function ndjsonToTrace(records) {
    const result = { header: {}, artifacts: [], events: [], notes: [], edges: [], aliases: [] };
    records.forEach((r) => {
      if (r.kind === "trace.header") result.header = r;
      if (r.kind === "trace.artifact") result.artifacts.push(r);
      if (r.kind === "trace.event") result.events.push(r);
      if (r.kind === "trace.note") result.notes.push(r);
      if (r.kind === "trace.edge") result.edges.push(r);
    });
    if (!result.header.root && result.artifacts.length) {
      const root = result.artifacts.find((a) => a.role === "root") || result.artifacts[0];
      result.header.root = root.h;
    }
    return result;
  }

  async function init() {
    parseEmbedded();
    await hydrateHostedData();
    attachUI();
    renderAll();
    setView("trace");
    setInspectorPane("summary");

    const rootArtifact = state.data.artifacts.find((a) => a.role === "root") || state.data.artifacts[0];
    if (rootArtifact) selectRecord("artifact", rootArtifact);
  }

  init();
})();
