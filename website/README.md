# Todorbit website

Dependency-free static site in `dist/`, hosted by GitHub Pages from this
repository. The owner explicitly approved website publication on 2026-10-26.
Application releases and Google Cloud configuration are outside this deployment.

- Homepage, product, downloads and support: `dist/index.html`
- Privacy Policy: `dist/privacy.html`
- Terms of Service: `dist/terms.html`
- Shared responsive light/dark CSS, existing brand and screenshot: `dist/assets/`

The site links **v1.0.13**, the published owner-approved experimental
Windows x64 pre-release. Google Drive is enabled; branding verification, full
public OAuth policy compliance and broad account eligibility remain unresolved.
Update pinned version/download URLs only after a later release is published.
No analytics, external fonts, forms, JavaScript or cookies are added.

## v1.0.13 deployment (2026-10-26)

- [Deployment 40355725550](https://github.com/2HIK4/Todorbit/actions/runs/40355725550)
  passed validation and deployment at **83fad4b** on main after GitHub publication.
- Anonymous canonical homepage/all eight files match source; all nine external
  links pass. Both download links match actual v1.0.13 release assets.
- Homepage, privacy and terms describe enabled experimental Drive with no
  Google approval or universal account claim. Screenshot remains accurately
  captioned v1.0.12. CSS/layout/assets are unchanged. Rendered QA is unverified.
- See [publication record](../docs/TODORBIT_1_0_13_PUBLICATION.md). Earlier
  deployment/domain investigation below remains historical evidence.

## Validation

```powershell
python website/verify.py
python website/verify_live.py
```

Static checks cover local links/anchors, headings, image metadata, theme
contrast, static content, responsive breakpoints and keyboard-focus rules.
The live check anonymously fetches all deployed files over HTTPS, compares
their bytes with `dist/` (normalizing Windows text line endings as Git does),
checks external links and download URLs, and confirms
the download version against the latest actual public release, including
pre-releases. It requires internet access and no credentials.

For rendered review, serve `dist/` with a local HTTP server. Inspect desktop,
375/768 px widths, light/dark OS themes, keyboard focus and 200% zoom.
Browser/native UI infrastructure was unavailable during publication; rendered
appearance, physical zoom and screen-reader interactions remain unverified.

## Deployment

Pages uses **GitHub Actions**, publishing only `website/dist/`. Pushes and PRs
validate; deployment requires manual workflow dispatch on `main` with
`publish_approved=true`. This preserves explicit website publishing approval.

```powershell
gh workflow run pages.yml --repo 2HIK4/Todorbit --ref main -f publish_approved=true
```

Review and validate source before dispatch. No application packaging or release
publication is part of this workflow.

### Verified deployment (2026-10-26)

- Published source: `5d77f37fdf3aed746ff223dab824f71da2841e71`, website-only
  fast-forward of `main` from `7965205`. Application source, native code,
  packaging, version and existing Windows workflow are unchanged.
- [Approved deployment run](https://github.com/2HIK4/Todorbit/actions/runs/40317545954)
  passed validation and deployment. Pages API confirms public Actions hosting
  at `https://2hik4.github.io/Todorbit/`, with HTTPS enforced.
- Anonymous HTTPS GET checks passed for the canonical homepage, all three
  HTML files, four assets and `.nojekyll`. Their public bytes match the deployed
  source (Git text line endings normalized). All nine external HTTPS links
  returned 200 on HEAD, including installer and ZIP, without GitHub credentials.
- Public release metadata confirmed v1.0.12 and both download URLs matched its
  actual published assets. No app release/tag was created or edited.
- Static navigation/anchor, responsive/accessibility CSS and theme-contrast
  checks passed locally and in Actions. Rendered browser checks remain
  unverified because no browser is connected. The successful HTTP checks do
  not establish visual layout or screen-reader behavior.

## Google OAuth domain investigation (2026-10-26)

The hosting URLs are:

- Homepage: `https://2hik4.github.io/Todorbit/`
- Privacy: `https://2hik4.github.io/Todorbit/privacy.html`
- Terms: `https://2hik4.github.io/Todorbit/terms.html`

These are website addresses, not evidence of Google OAuth approval. No Google
Cloud setting or Search Console property was changed.

[Search Console](https://support.google.com/webmasters/answer/9008080?hl=en)
supports HTML-tag/file verification of a URL-prefix property such as
`https://2hik4.github.io/Todorbit/`. An authorized Google account must obtain
the real verification tag/file first. The tag can be placed in `index.html`'s
`head`, or the supplied file at Google's exact requested location, then
published and verified. Keep it in place afterwards. No fake token is included.

However, Google's current [OAuth Domain Verification guide](https://support.google.com/cloud/answer/13804266?hl=en)
explicitly requires a **DNS-level Domain property**, rather than a URL-prefix
property, for remediation of unverified authorized domains. GitHub Pages users
do not control DNS TXT records for `2hik4.github.io`. Thus HTML verification
alone is not a documented route to satisfy that OAuth requirement. Earlier
preparation treated this as an open HTML-verification experiment; this more
specific official guidance narrows that conclusion.

The hostname to consider is **`2hik4.github.io`**, only if Google explicitly
accepts this hosting arrangement. It is **not a verified/accepted Authorized
Domain**. Never enter `github.com`, `github.io`, a full URL or `/Todorbit/` as
the Authorized Domain. Google's [Branding guide](https://support.google.com/cloud/answer/15549049?hl=en)
requires verified ownership and a Top Private Domain. Without Google's
acceptance/exception, use an owned domain whose DNS can be verified. GitHub
Pages hosting can remain free; an already-owned suitable domain avoids a new
purchase. No domain purchase, DNS change or account-root site edit is authorized
by this website deployment.

The domain/brand verification route remains unresolved. The owner subsequently
approved an enabled **experimental v1.0.13 pre-release** under the more specific
non-sensitive-scope guidance; see [publication record](../docs/TODORBIT_1_0_13_PUBLICATION.md).
Neither release publication nor these URLs establish full public policy compliance.
