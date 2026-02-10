# GitHub CI for IceVault

## Structure

- **workflows/** — two workflows (each can be re-run independently; the full flow is split into jobs so you can re-run a single job, e.g. only "Upload to TestFlight"):
  - `ios_single_flow.yml` — full flow: build IPA → upload to TestFlight (two jobs: **Build IPA**, **Upload to TestFlight**)
  - `ios_build_only.yml` — build IPA only (no upload)
- **actions/** — none (no custom composite actions)

## Workflows

| File | Trigger | Jobs / stages | Purpose |
|------|---------|----------------|---------|
| `workflows/ios_single_flow.yml` | Manual (`workflow_dispatch`) | 1. **Build IPA** → 2. **Upload to TestFlight** | Full release: build then upload. You can re-run only the **Upload to TestFlight** job if the build succeeded but upload failed. |
| `workflows/ios_build_only.yml` | Manual (`workflow_dispatch`) | 1. **Build IPA** | Build and sign only; IPA is uploaded as a workflow artifact. No TestFlight upload. |

Re-running: in the Actions tab, open a run and use **Re-run job** for the failed job (e.g. re-run only "Upload to TestFlight" without rebuilding).

## Required configuration

- **Secrets:** `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`, `APPSTORE_P8`, `GH_PAT`, `MATCH_PASSWORD`
- **Variables:** `APPLE_TEAM_ID`, `BUNDLE_IDENTIFIER`, **`XC_TARGET_NAME`** (must be `IceVault`), `MATCH_GIT_URL`, `LAST_UPLOADED_BUILD_NUMBER`, `APPLE_APP_ID`

After renaming the app to IceVault, ensure **Variables → XC_TARGET_NAME** is set to `IceVault` (not BaseApp).

See [Docs/TROUBLESHOOTING.md](../Docs/TROUBLESHOOTING.md) and [README.md](../README.md) for full CI/CD details.
