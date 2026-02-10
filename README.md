# iOS Build CI — Fastlane & GitHub Actions

This repository contains build and deployment logic for iOS apps: Fastlane lanes (code signing, IPA build, TestFlight upload) and GitHub Actions workflows. It is intended to be used from your application repository or as a reference when setting up CI in a separate repo.

## Project structure

| Path | Description |
|------|--------------|
| **fastlane/** | Fastfile, iOS lanes (`build_for_testflight`, `build_upload_testflight`, `upload_testflight_only`), Match config, empty-password patch |
| **fastlane/lanes/ios.rb** | iOS-specific lanes: load ASC API key, match + signing + build, TestFlight upload |
| **.github/workflows/** | Workflow definitions: full flow (build + upload) and build-only |
| **Gemfile** / **Gemfile.lock** | Ruby dependencies (fastlane, cocoapods, xcodeproj) |
| **Docks/** | Documentation; see [Docks/TROUBLESHOOTING.md](Docks/TROUBLESHOOTING.md) for troubleshooting |

## Build process

The pipeline consists of the following stages:

1. **Environment setup** — Ruby/Bundler and Fastlane are used; workflows run from the app repo root so that `fastlane/` and project files (e.g. `ProjectName.xcodeproj`, `Podfile`) are available.
2. **Dependencies** — `bundle install` and CocoaPods (`cocoapods` in Fastfile) install Ruby gems and iOS pods. DerivedData is cleaned before build to avoid stale caches.
3. **Certificates (Match)** — Match syncs code signing identities and provisioning profiles from a private Git repo. Requires `MATCH_PASSWORD`, `MATCH_GIT_URL`, and (in CI) `GH_PAT` or `MATCH_GIT_BASIC_AUTHORIZATION`.
4. **Code signing** — `sync_code_signing` and `update_code_signing_settings` apply the Match profiles to the main app target and the notifications extension. Team ID and bundle identifier come from environment variables.
5. **Build IPA** — `build_app` compiles the app and exports an IPA. Build number is incremented from `LAST_UPLOADED_BUILD_NUMBER`. Output paths are written to `ipa_path.txt` and `build_number.txt` for CI.
6. **Upload to TestFlight** — Optional step: `upload_to_testflight` uploads the IPA to App Store Connect. Requires App Store Connect API key (key ID, issuer ID, .p8 content) and `APPLE_APP_ID`.

In GitHub Actions, the full flow is split into two jobs (**Build IPA** and **Upload to TestFlight**) so you can re-run only the upload job if the build already succeeded.

## Configuration

For **local runs**, set environment variables (or use a `.env` file) as needed by the lanes: `BUNDLE_IDENTIFIER`, `TEAM_ID` / `APPLE_TEAM_ID`, `XC_TARGET_NAME`, `MATCH_GIT_URL`, `MATCH_PASSWORD`, and for TestFlight upload: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY`, `APPLE_APP_ID`.

For **GitHub Actions**, configure repository Secrets and Variables:

- **Secrets:** `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`, `APPSTORE_P8`, `GH_PAT`, `MATCH_PASSWORD`
- **Variables:** `APPLE_TEAM_ID`, `BUNDLE_IDENTIFIER`, `XC_TARGET_NAME` (must match the app target, e.g. `ProjectName`), `MATCH_GIT_URL`, `LAST_UPLOADED_BUILD_NUMBER`, `APPLE_APP_ID`

Workflows map these to the env names expected by Fastlane (e.g. `APPSTORE_*` → `ASC_*`). For a full list and troubleshooting of secrets/variables, see [Docks/TROUBLESHOOTING.md](Docks/TROUBLESHOOTING.md) and [.github/README.md](.github/README.md).

## Usage

### Local (from the application repo root)

Ensure you are in the app repository root (where `ProjectName.xcodeproj` and `Podfile` are). Fastlane expects to run from that directory (project root is the parent of the `fastlane/` folder).

```bash
bundle install
bundle exec fastlane build_for_testflight   # build only; writes ipa_path.txt, build_number.txt
bundle exec fastlane ios build_upload_testflight  # build + upload to TestFlight
```

### CI (GitHub Actions)

- **Full flow:** run the workflow that includes **Build IPA** and **Upload to TestFlight** (e.g. `workflows/ios_single_flow.yml` via `workflow_dispatch`).
- **Build only:** run the build-only workflow; the IPA is uploaded as a workflow artifact.
- To re-run only **Upload to TestFlight**, use “Re-run job” for that job in the Actions run (no need to rebuild).

If this repo is used from a **separate** repository:

1. Copy the **contents** of this repo to the **root** of the new repo (so `.github/`, `fastlane/`, `Gemfile`, `Gemfile.lock` are at the repo root).
2. Adjust workflows: they assume a single repo (checkout + run fastlane from workspace). In the new repo you may need to check out the **application repository** and run `bundle exec fastlane ...` from the app directory, or keep fastlane in the app repo and use this repo only for workflow definitions and docs.
3. Fastlane lanes must run from the **app project root** (where the `.xcodeproj` and `Podfile` live).
4. Configure the same Secrets and Variables in the new repo (or in the app repo if workflows run there). See [.github/README.md](.github/README.md) for the list.

## Links

- [Docks/TROUBLESHOOTING.md](Docks/TROUBLESHOOTING.md) — typical errors, fixes, and configuration details
- [.github/README.md](.github/README.md) — workflow structure and required CI configuration
