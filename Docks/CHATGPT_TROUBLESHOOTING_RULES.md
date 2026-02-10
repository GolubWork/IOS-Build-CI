# ChatGPT rules: iOS Build CI — Troubleshooting lookup

**Purpose of this file:** When the user sends you an error from this iOS build/CI project, use this file as the first source of fixes. Search for a matching problem below; if found, suggest that fix. If no match is found, suggest a fix by analogy with similar problems from this list. For full details and Russian text, see `Docks/TROUBLESHOOTING.md`.

**How to use:**
1. User pastes an error (log, stack trace, or message).
2. Look for a matching **Error pattern** or **Stage** in the sections below.
3. If you find a match → reply with the **Fix** from this file and point to TROUBLESHOOTING.md for details.
4. If no match → propose a fix by analogy (same stage, same kind of tool: Bundler, Match, Fastlane, Xcode, etc.) and suggest adding the new case to TROUBLESHOOTING.md.

---

## Error → Fix quick reference

### 2.1. Подготовка окружения (Environment)

| Error pattern | Fix |
|---------------|-----|
| `Could not find Fastfile at path '.../fastlane/./lanes/ios'` | In `fastlane/Fastfile` use `import "./lanes/ios.rb"` (with `.rb`). Run Fastlane from repo root; call lane by name only (e.g. `bundle exec fastlane build_for_testflight`), not `fastlane ios ...`. In GitHub Actions set `working-directory` to repo root. Restart workflow. |

---

### 2.2. Установка зависимостей (Dependencies)

| Error pattern | Fix |
|---------------|-----|
| `Your bundle only supports platforms ["x86_64-darwin"] but your local platform is arm64-darwin-23` | Run `bundle lock --add-platform arm64-darwin-23` (optionally also `x86_64-darwin`), commit `Gemfile.lock`, restart workflow. |
| `Your lockfile has an empty CHECKSUMS entry for "..."` / `can't be updated because frozen mode is set` | Locally run `bundle lock --add-checksums` or `bundle install` (with network), commit updated `Gemfile.lock`. Do not disable frozen mode in CI. Restart workflow. |
| `[Xcodeproj] Unable to find compatibility version string for object version '71'` | Project was saved in Xcode 26+ (`objectVersion = 71`). In `*.xcodeproj/project.pbxproj` set `objectVersion = 77`, or in Xcode set Project Document format to a version that gives 56 or 77. Commit and restart. |

---

### 2.3. Настройка сертификатов (Match)

| Error pattern | Fix |
|---------------|-----|
| `fatal: The empty string is not a valid path` / `git clone ''` / `Error cloning certificates git repo` | Add GitHub Actions: **Secret** `GH_PAT` (PAT with read access to certs repo), **Variable** `MATCH_GIT_URL` (full HTTPS URL of Match repo, e.g. `https://github.com/owner/ProjectName-Certificates.git`). Restart workflow. |
| `fatal: repository '...' does not exist` (Match repo) | Same as above: set `MATCH_GIT_URL` to full URL and ensure `GH_PAT` has access to that repo. |
| `'' is not a valid filter` (Apple Developer Portal) / `app_identifier \| ["", ".notifications"]` | Set **Variables**: `BUNDLE_IDENTIFIER` (app bundle ID), `APPLE_TEAM_ID` (10 chars). Ensure workflow step receives them via `env`. Restart workflow. |
| `Could not create another Distribution certificate, reached the maximum number` | In Apple Developer Portal → Certificates → revoke unused **Distribution** (and if needed Development) certificates. Or use Match in **readonly** if certs repo already has valid certs. Restart workflow. |
| `invalid curve name (OpenSSL::PKey::ECError)` (App Store Connect API key) | Use exact secret names in GitHub Actions: `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`, `APPSTORE_P8`. Wrong names (e.g. `ASC_KEY_ID`) leave env empty and cause this error. |

---

### 2.4. Code Signing

| Error pattern | Fix |
|---------------|-----|
| `targets \| []` / "None of the specified targets has been modified" / "No profile for team" / "No Accounts" | Add **Variable** `XC_TARGET_NAME` (e.g. `ProjectName` — main app target/scheme name). Restart workflow. |
| `cat: ipa_path.txt: No such file or directory` | Same as above: set `XC_TARGET_NAME` so the lane knows which target to sign and can write `ipa_path.txt`. |

---

### 2.5. Сборка (Build)

*(No specific entries yet; suggest by analogy with same stage/tool.)*

---

### 2.6. Загрузка в TestFlight

*(No specific entries yet; suggest by analogy.)*

---

### Локальная разработка (IDE / Git)

| Error pattern | Fix |
|---------------|-----|
| Git does not show changes; repo root not detected (e.g. Rider) | Open the parent folder (containing the project) as the project so repo root is correct. Or: Settings → Version Control, add directory with `.git` as VCS root. File → Synchronize or Invalidate Caches / Restart if needed. |

---

### CI (GitHub Actions) — секреты и переменные

**Secrets (exact names):** `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`, `APPSTORE_P8` (Base64), `GH_PAT`, `MATCH_PASSWORD` (optional; empty works only if Match repo was created with empty passphrase).

**Variables:** `APPLE_TEAM_ID`, `BUNDLE_IDENTIFIER`, **`XC_TARGET_NAME`** (required, e.g. `ProjectName` — main app target/scheme), `MATCH_GIT_URL`, `LAST_UPLOADED_BUILD_NUMBER`, `APPLE_APP_ID`.

If the error is about missing or invalid credentials/signing, check these names first.

---

### Match / сертификаты (другое)

| Situation | Fix |
|-----------|-----|
| No `MATCH_PASSWORD` secret / empty password | Lane uses empty password if secret is unset. Repo must have been created (or re-encrypted via `fastlane match change_password`) with empty passphrase. To migrate: `fastlane match change_password` and set new password to empty; then you can remove `MATCH_PASSWORD` from GitHub. |

---

## Summary for matching

- **Fastfile / lanes/ios** → import path `.rb`, run from root, `working-directory`.
- **Bundler platform** → `bundle lock --add-platform arm64-darwin-23`, commit lockfile.
- **Bundler CHECKSUMS** → `bundle lock --add-checksums` or `bundle install` locally, commit lockfile.
- **Xcodeproj object version 71** → set `objectVersion = 77` in project.pbxproj (or Xcode project format).
- **Match clone empty / repo not exist** → `GH_PAT` + `MATCH_GIT_URL` (full URL).
- **Match '' is not a valid filter** → `BUNDLE_IDENTIFIER` + `APPLE_TEAM_ID`.
- **Match max Distribution certificates** → Revoke certs in Apple Developer or use Match readonly.
- **App Store key invalid curve** → Secrets: `APPSTORE_KEY_ID`, `APPSTORE_ISSUER_ID`, `APPSTORE_P8`.
- **Code signing / ipa_path.txt** → Variable `XC_TARGET_NAME` (e.g. `ProjectName`).
- **IDE Git not showing changes** → Correct VCS root / open parent folder.

When in doubt, suggest checking `Docks/TROUBLESHOOTING.md` and the exact secret/variable names in GitHub Actions.
