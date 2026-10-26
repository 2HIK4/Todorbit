# Todorbit website — prepared, not published

Handwritten, dependency-free static site in `dist/`, for GitHub Pages in this
repository. No Site registration, remote hosting mutation, deployment, Google
production change or public app release is authorized by its preparation.

- Homepage/product/download/support: `dist/index.html`
- Privacy Policy: `dist/privacy.html`
- Terms of Service: `dist/terms.html`
- Shared responsive light/dark CSS and public existing brand/screenshot assets:
  `dist/assets/`

The site links **v1.0.12**, the actual current public Windows x64 pre-release,
and clearly says Google Drive is not generally available. Update the pinned
version and download URLs only after a later release is actually published.
No invented testimonials, sample product data, analytics, external fonts, forms,
JavaScript, account flow or cookies are added. The existing screenshot is labeled
v1.0.12 and is not a screenshot of the cloud candidate.

## Local review

```powershell
python website/verify.py
python -m http.server 8765 --bind 127.0.0.1 --directory website/dist
```

Open `http://127.0.0.1:8765/`, `privacy.html` and `terms.html`. Review desktop
and 375/768 px widths, light/dark OS themes, keyboard focus, 200% zoom, links
and text wrapping. Static checks cover local links, headings/landmarks, image
metadata, theme contrast, no active third-party resources and breakpoint/focus/
reduced-motion rules; they do not establish rendered browser appearance.
Owner approval of policy/terms wording is still required before publication.

## Publication, only after explicit owner approval

The proposed project-site URL is `https://2hik4.github.io/Todorbit/`. It is
**not a verified live site**. The repository Pages API returned 404 during this
session; this does not prove all account-level Pages/domain configuration is
absent. No Pages setting was changed.

1. Approve the exact content and intended domain. After approval, merge the
   site source/workflow into the intended branch without force-pushing.
2. Repository **Settings > Pages > Build and deployment > Source: GitHub
   Actions**. Review/protect the `github-pages` environment with an owner
   reviewer where the account plan supports it.
3. Run **Website preview checks and approved deployment** manually from
   Actions, selecting the reviewed commit and setting `publish_approved` to
   true only after approval. There is **no push-triggered deployment**; a PR
   runs validation only. Do not run deployment during release preparation.
4. Verify all three public URLs, links, TLS and the displayed download version.
   Test incognito with no login. Use the exact published homepage/privacy/terms
   URLs in Google Auth Platform Branding only after domain eligibility is
   established. Do not interpret GitHub Pages deployment as Google approval.

See [Google OAuth domain and owner checklist](../docs/GOOGLE_DRIVE_RELEASE_READINESS.md).
The prepared site can also be hosted on an owned custom domain without code
changes. No `CNAME`, domain purchase, DNS record or fake Google ownership token
has been added.
