# Todorbit Android 1.0.19-beta.24 (Build 47)

Production-signed experimental Android candidate for GitHub distribution.

## Changes

- **Multi-File Ingestion Hardening**: Synchronized manifest update batches in `ShareReceiverActivity.kt`, ensuring all files in multi-stream share intents are preserved in the durable manifest.
- **Content Scheme Validation**: Rejected non-content URI schemes and restricted access to external file providers.
- **Sync & Rollback Interoperability**: Ensured local `detailPresentation` preference does not pollute cloud sync batches or cause parsing errors on paired devices.
- **Navigation & Unsaved Edits**: Integrated unsaved-change confirmation guards across event and task editor flows.
- **Detail Presentation**: Full page detail views display live timer duration counters and clean back-navigation.

## Android Specifications

- **Package Name**: `io.github.hik4.todorbit`
- **Version Name**: `1.0.19-beta.24`
- **Version Code**: `47`
- **Target SDK**: API 36
- **Min SDK**: API 26
- **Architecture**: `arm64-v8a`, `x86_64`
- **16-KiB Page Alignment**: Verified across all 8 native `.so` ELF libraries.
