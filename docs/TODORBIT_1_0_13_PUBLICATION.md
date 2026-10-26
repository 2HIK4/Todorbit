# v1.0.13 experimental pre-release publication — 2026-10-26

The owner now explicitly authorizes release preparation, merging to main,
tagging, GitHub **pre-release** publication and official Pages download updates.
This supersedes the earlier owner publication hold in the private/engineering
reports. It does not authorize Cloud changes, a domain purchase, Sandbox work
or changes to the personal installed app/profile. Historical test limits remain.

## Evidence reuse and exact artifacts

App/native/installer/updater/build/test/config sources and version remain
identical to `8d667df529319596ad4c43824104410a4cc5a0ac`, version **1.0.13+14**.
Reuse its 287 tests, clean analysis, native/Windows builds, real Google recovery,
package startup, portable helper update/rollback and
[passing CI](https://github.com/2HIK4/Todorbit/actions/runs/40342429612).
Do not repeat those completed checks for documentation/website-only changes.

Publish the exact enabled packages from
`.buildlog/private-engineering-final-20261026-174228/packages/`. CI candidates
are disabled and must not be substituted. The source-tree default config stays
disabled/empty; enabled parameters are supplied during the reviewed local build.
Ordinary users receive the compiled configuration and do not import JSON.

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| Todorbit-1.0.13-win-x64-setup.exe | 47,132,241 | `436207401892c97fbd800842c6106e851e7923945c1f5145a9f3f8fbaf3a24e0` |
| Todorbit-1.0.13-win-x64-portable.zip | 62,274,586 | `27dcee912a73072f5be28587dc7f0107115e07d1edf1ea03c005602eb882c481` |

Final local artifact checks PASS: both recorded sizes/digests, manifest and
sidecars, portable CRC (37 entries), every extracted file equals its ZIP entry,
enabled receipt bound to the tested config/runner/AOT, and known private-file
guards. PE versions match 1.0.13 (main 1.0.13+14; widget 1.0.13.0). No build,
Google grant, token store or user database is changed for publication.

## Google policy scope and limitations

Google's [verification help](https://support.google.com/cloud/answer/13463073)
explicitly states that apps using only non-sensitive scopes do not have to
complete app verification; displaying a name/logo requires brand verification.
The [Drive guide](https://developers.google.com/workspace/drive/api/guides/api-specific-auth)
classifies `drive.appdata` as non-sensitive. This specific guidance means
unverified branding alone is not established as a prohibition on this enabled
experimental pre-release. It does **not** certify complete policy compliance.

The [OAuth policies](https://developers.google.com/identity/protocols/oauth2/policies)
and [production guidance](https://developers.google.com/identity/protocols/oauth2/production-readiness/policy-compliance)
also describe production branding, an owned verified homepage domain and
separate deployment tiers. These publisher obligations remain unresolved;
GitHub Pages publication does not establish domain verification. No new client,
scope, project or tier is created, and no restriction or warning is bypassed.
The current existing project/client remains unchanged. Real tested access is
technical evidence only. The release and website explicitly label Drive
experimental, with no Google approval or universal account promise. A stable
production-readiness pass is not claimed.

Clean-user/VM checks are **SKIPPED by owner decision**. Registered installation,
manual GUI/input/DPI and clean-machine trust remain unverified. The packages are
unsigned. No Sandbox action is required. The personal install/data and Google
Cloud settings remain untouched. See the release notes for backup limitations.

## Publication verification

Pending publication: verify the public release is non-draft/pre-release,
download all five assets anonymously, compare SHA-256/sidecars/manifest and the
enabled receipt, check real updater selection from 1.0.12 for both package
types without launching an update, then deploy and verify Pages content/links.
Final bounded evidence is kept under ignored
`.buildlog/release-1.0.13-20261026/`.
