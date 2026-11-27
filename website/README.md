# Todorbit website

Dependency-free static site in `dist/`, hosted cleanly on GitHub Pages from this repository (`main` branch via `.github/workflows/pages.yml` when `publish_approved=true`). Application releases and Google Cloud configuration are outside website deployment.

- Homepage, product highlights, Windows & Android downloads, and community links: `dist/index.html`
- Privacy Policy: `dist/privacy.html`
- Terms of Service: `dist/terms.html`
- Shared responsive light/dark CSS and local visual assets (`todorbit-today.png`, `todorbit-android.png`, `orbit.svg`): `dist/assets/`

## Current status

- **Current baseline**: Links the **v1.0.19-beta.30** experimental Windows x64 packages (`setup.exe`, `portable.zip`), Android APK (`universal`), and published `SHA256SUMS.txt` checksum files, using genuine synthetic Windows (`1264×681`) and Android (`390×844`) captures.
- **Published site note**: GitHub Pages (`https://2hik4.github.io/Todorbit/`) deploys only via explicit maintainer `workflow_dispatch` on `main` (`publish_approved=true`) and serves the latest owner-approved deployment until a new `main` docs/website PR is merged and approved.
- **Privacy & constraints**: Google Drive Sync and encrypted snapshots remain experimental; branding verification and broad public OAuth compliance remain unresolved. The static site adds zero analytics, cookies, forms, JavaScript, or external fonts.

## Validation

```powershell
# Static accessibility, contrast, CSP, and link validation
python website/verify.py

# Preview validation against live GitHub release packages & SHA-256 checksums
python website/verify_live.py --preview

# Post-deployment byte-for-byte check against GitHub Pages
python website/verify_live.py
```

Static checks verify semantic headings, ARIA landmarks, image dimensions/alt attributes, CSP/static-only HTML, WCAG AA contrast across dark and light color schemes, and CSS responsive rules (`focus-visible`, `prefers-reduced-motion`, breakpoints).

**Limitations**: Rendered desktop/mobile browser layout QA and interactive screen-reader testing require manual browser inspection against a local HTTP server (`python -m http.server --directory website/dist 8080`).

## Deployment

`.github/workflows/pages.yml` runs `python website/verify.py`, deploys `website/dist/` via `actions/deploy-pages`, and runs `python website/verify_live.py` only on explicit `workflow_dispatch` with `publish_approved=true` from `main`.
