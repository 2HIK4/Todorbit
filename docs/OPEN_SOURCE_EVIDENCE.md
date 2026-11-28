# Todorbit open-source evidence

Snapshot taken **November 28, 2026**. Todorbit is an independently maintained, MIT-licensed local-first planner for Windows x64 and Android. The [feature catalogue](FEATURES.md), [platform support](PLATFORM_SUPPORT.md), and [contributor guide](../CONTRIBUTING.md) describe the product and where to work on it.

## Source and releases

- [Beta 30](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.30) is an Experimental prerelease from [commit `253f4ed`](https://github.com/2HIK4/Todorbit/commit/253f4ed560018bfbb9acc9f1e110c823c77041d1), build 53, SQLite schema 29, and sync protocol 2.
- The hosted [Windows run](https://github.com/2HIK4/Todorbit/actions/runs/46066659736), [Android run](https://github.com/2HIK4/Todorbit/actions/runs/46066664484), and [Android 16 KiB upgrade run](https://github.com/2HIK4/Todorbit/actions/runs/46068388702) passed for the Beta 30 source. The 16 KiB run exercised a synthetic Beta 29 to Beta 30 state-preserving upgrade. An unrelated Beta 26 job was skipped.
- The November 28 audit downloaded all 11 attached Beta 30 files and matched their computed SHA-256 digests to GitHub metadata. The two Windows binaries and three Android APKs also matched their platform checksum manifests. All three APKs used the same signing certificate as the Beta 29 ARM64 sample and passed the available APK/ELF 16 KiB static checks. Windows app and setup binaries were unsigned.
- The [publication receipt](https://github.com/2HIK4/Todorbit/blob/60a6fd6efa724d6541f3e847d1525ecfa78adaf7/docs/TODORBIT_BETA_30_CANDIDATE.md) and [acceptance backlog](https://github.com/2HIK4/Todorbit/blob/60a6fd6efa724d6541f3e847d1525ecfa78adaf7/docs/DEFERRED_VERIFICATION.md) record the tested behavior and remaining physical-device, live Drive, and manual checks.

## Public activity

| Measure | Observed |
| --- | --- |
| Public repository creation | October 20, 2026 |
| Published GitHub releases | 42 Experimental prereleases. The Stable latest-release API returned 404. |
| Uploaded Windows and Android binaries across releases | 129 executable, APK, or ZIP assets |
| Cumulative downloads across those binary assets | 501 at observation, including possible repeat downloads and maintainer verification |
| Beta 30 binary downloads | Windows installer 3, portable ZIP 3, Android ARM64 2, universal 3, x86-64 3 |
| Public contribution history | One GitHub-attributed contributor. Four merged PRs authored by the maintainer and zero external merged PR authors at observation. |
| Community Standards | GitHub API reported 100%. Three issue templates are present on the default branch. The API did not return an issue-template link. |

Counts come from [public release metadata](https://api.github.com/repos/2HIK4/Todorbit/releases?per_page=100), [repository metadata](https://api.github.com/repos/2HIK4/Todorbit), [contributors](https://github.com/2HIK4/Todorbit/graphs/contributors), [pull requests](https://github.com/2HIK4/Todorbit/pulls?q=is%3Apr), and [Community Standards](https://github.com/2HIK4/Todorbit/community). Downloads are file requests. Distinct users and active usage are unknown.

## Engineering and contribution

The tagged [architecture map](https://github.com/2HIK4/Todorbit/blob/v1.0.19-beta.30/docs/ARCHITECTURE_MAP.md) and [TDAT guide](https://github.com/2HIK4/Todorbit/blob/v1.0.19-beta.30/docs/DEVELOPER_AUTOMATION_TOOLKIT.md) describe source boundaries, test selection, and disposable fixtures. See the [test ledger](https://github.com/2HIK4/Todorbit/blob/60a6fd6efa724d6541f3e847d1525ecfa78adaf7/docs/TEST_RUN_LEDGER.md) for published receipts. The [contributor tasks](CONTRIBUTOR_TASKS.md) and [roadmap](ROADMAP.md) identify where outside testing and engineering work can help.
