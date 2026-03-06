# Repository Guidelines

## Project Structure & Module Organization
This repository is documentation-first with a small static web surface.

- Root `*.md`: core design notes, theory, and protocol drafts (primary authored content).
- `public/`: browser-facing artifacts (`index.html`, `script.js`, `styles.css`, SVG assets).
- `public/docs/`: long-form generated/reference docs used by the public site.

Keep new conceptual documents at the repo root unless they are strictly web-consumption assets, in which case place them in `public/` or `public/docs/`.

## Build, Test, and Development Commands
No dedicated build system is required for normal edits.

- `python3 -m http.server 8000 -d public`: run the static site locally.
- `rg --files`: quick inventory of tracked files.
- `git diff --check`: catch whitespace and conflict-marker issues before commit.

If you add tooling (lint/test scripts), document it here and in the PR.

## Coding Style & Naming Conventions
- Markdown: short sections, descriptive headings, fenced code blocks for commands/examples.
- JavaScript/CSS/HTML: keep style consistent with existing `public/` files (simple, readable, minimal dependencies).
- Indentation: 2 spaces for web assets; wrap long prose lines for readability.
- File names: preserve current descriptive naming style for research notes; use kebab-case for new web assets when practical.

## Testing Guidelines
There is no formal automated test suite in this repo today.

For content/UI changes:
- Serve `public/` locally and verify pages load without console errors.
- Validate links and referenced file paths in modified docs.
- For protocol examples, ensure command snippets are runnable as written.

When adding logic-heavy JavaScript, include a minimal reproducible validation step in the PR description.

## Commit & Pull Request Guidelines
Follow the existing history style:
- Prefer concise, imperative commit subjects.
- Conventional prefixes are encouraged when applicable: `feat:`, `fix:`, `docs:`.

PRs should include:
- Scope summary (what changed and why).
- Paths touched (for example: `public/script.js`, `axiom-faces.md`).
- Verification performed (local server check, manual UI pass, link/path validation).
- Screenshots only when UI output changed.

## Security & Boundary Notes
Treat `public/` as projection/presentation output only. Do not introduce hidden mutation channels or implicit authority/state semantics in client-side code.
