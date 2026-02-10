# Troubleshooting

## Technical requirements

Environment requirements for local build and CI:

- **macOS** — 12+
- **Xcode** — 14+ (16.x recommended)
- **iOS deployment target** — 16.0 (from Podfile)
- **Ruby** — 3.3+
- **Bundler** — for gems
- **CocoaPods** — 1.16+

---

## Common issues (Этап → Ошибка → Фикс)

### Bundler — platform not in lockfile

- **Этап:** `bundle install` (CI, e.g. Build IPA job).
- **Ошибка:**
  ```
  Your bundle only supports platforms ["x86_64-darwin"] but your local platform is
  arm64-darwin-23. Add the current platform to the lockfile with
  `bundle lock --add-platform arm64-darwin-23` and try again.
  Error: The process '.../bundle' failed with exit code 16
  ```
- **Фикс:** On any machine run `bundle lock --add-platform arm64-darwin-23`, commit `Gemfile.lock`. Optionally add both: `bundle lock --add-platform x86_64-darwin` and `bundle lock --add-platform arm64-darwin-23`. Re-run the workflow.

### Bundler — empty CHECKSUMS in lockfile

- **Этап:** `bundle install` (CI).
- **Ошибка:**
  ```
  Your lockfile has an empty CHECKSUMS entry for "rake", but can't be updated
  because frozen mode is set.

  Run `bundle install` elsewhere and add the updated Gemfile.lock to version
  control.

  If this is a development machine, remove the Gemfile.lock freeze by running
  `bundle config set frozen false`.
  Error: The process '.../bundle' failed with exit code 16
  ```
- **Фикс:** Locally run `bundle lock --add-checksums` or `bundle install` (with network), commit the updated `Gemfile.lock`. Do not disable frozen mode in CI. Re-run the workflow.

### Build IPA — CocoaPods / Xcodeproj object version

- **Этап:** Build IPA → Fastlane lane (e.g. `build_for_testflight`) → CocoaPods step (“Analyzing dependencies”, `pod install`).
- **Ошибка:**
  ```
  ArgumentError - [Xcodeproj] Unable to find compatibility version string for object version `71`.
  /vendor/bundle/.../gems/xcodeproj-1.27.0/lib/xcodeproj/project.rb:85:in `initialize'
  ...
  [!] Oh no, an error occurred.
  ```
- **Фикс:** The project was saved with Xcode 26 (or newer) and has `objectVersion = 71` in `*.xcodeproj/project.pbxproj`; the xcodeproj gem 1.27.x only knows compatibility strings up to object version 77. In `IceVault.xcodeproj/project.pbxproj` set `objectVersion = 77` (replace `71`). Commit the change and re-run the workflow. If you prefer not to edit the file by hand: in Xcode open the project → File Inspector (⌘⌥0) → Project Document → set format to a version that produces object version 56 or 77.

### Build IPA — App Store Connect API key: invalid curve name

- **Этап:** Build IPA → Fastlane lane after CocoaPods (e.g. when using Match or TestFlight steps that need ASC API key).
- **Ошибка:**
  ```
  invalid curve name (OpenSSL::PKey::ECError)
  .../spaceship/lib/spaceship/connect_api/token.rb:71:in `initialize'
  ```
- **Фикс:**
  1. **Secrets in GitHub:** The workflow expects secrets named **`APPSTORE_KEY_ID`**, **`APPSTORE_ISSUER_ID`**, **`APPSTORE_P8`** (Settings → Secrets and variables → Actions). If you created `ASC_KEY_ID` / `ASC_KEY` etc., the env vars will be empty and OpenSSL will fail with "invalid curve name".
  2. Secrets: APPSTORE_KEY_ID, APPSTORE_ISSUER_ID, APPSTORE_P8

### Build IPA — Match: error cloning certificates repo

- **Этап:** Build IPA → Fastlane lane `build_for_testflight` → step **match** (clone certificates repo).
- **Ошибки (оба решаются настройкой секретов и переменных):**

  1. **Пустой URL:**
     ```
     fatal: The empty string is not a valid path
     Error cloning certificates git repo...
     git clone '' /var/folders/.../T/...
     ```
  2. **Репозиторий не найден (неверный формат URL):**
     ```
     fatal: repository 'GolubWork/IOS-IceVault-Certificates' does not exist
     Error cloning certificates git repo, please make sure you have read access to the repository
     ```

- **Фикс:** In GitHub repo **Settings → Secrets and variables → Actions** add:

  1. **Secret** `GH_PAT` — GitHub Personal Access Token with read access to the Match certificates repo.
  2. **Variable** `MATCH_GIT_URL` — full HTTPS URL of the Match certificates repo (e.g. `https://github.com/GolubWork/IOS-IceVault-Certificates.git`).  
     Short form `owner/repo` is auto-normalized to `https://github.com/owner/repo.git` in `fastlane/MatchFile`; if you still see "repository '...' does not exist", use the full URL or check that the repo exists and `GH_PAT` has access.

  Without `MATCH_GIT_URL` (or if it is empty) you get "empty string is not a valid path". Without `GH_PAT`, auth for cloning fails. Re-run the workflow after fixing both.

### Build IPA — Match: '' is not a valid filter (Apple Developer Portal)

- **Этап:** Build IPA → Fastlane lane `build_for_testflight` → step **match** (after cloning repo, when verifying with Apple Developer Portal).
- **Ошибка:**
  ```
  An error occurred while verifying your certificates and profiles with the Apple Developer Portal.
  A parameter has an invalid value - '' is not a valid filter
  ```
  In the match summary you may see `app_identifier | ["", ".notifications"]` (first element empty).
- **Причина:** Variable **`BUNDLE_IDENTIFIER`** (and often **`APPLE_TEAM_ID`**) are not set in the repo, so Match sends an empty filter to the Apple API.
- **Фикс:** In GitHub **Settings → Secrets and variables → Actions → Variables** set:
  - **`BUNDLE_IDENTIFIER`** — your app bundle ID (e.g. `com.yourcompany.IceVault`).
  - **`APPLE_TEAM_ID`** — your Apple Team ID (10 characters).

  Ensure the "Build for TestFlight" step receives these (workflow-level `env` or step-level `env`). Re-run the workflow after adding both variables.

### Build IPA — code signing not applied to main target / ipa_path.txt missing

- **Этап:** Build IPA → Fastlane lane `build_for_testflight` (after Match, during `update_code_signing_settings` or "Prepare IPA for artifact").
- **Ошибки:**
  - In the lane summary: `targets | []` (empty), "None of the specified targets has been modified", then Xcode fails with "No profile for team …" or "No Accounts".
  - Next step: `cat: ipa_path.txt: No such file or directory`.
- **Причина:** Variable **`XC_TARGET_NAME`** is not set in the repo, so the lane does not know which target to configure for code signing and the IPA path may not be written correctly.
- **Фикс:** In GitHub **Settings → Secrets and variables → Actions → Variables** add variable **`XC_TARGET_NAME`** with value **`IceVault`** (the scheme and main app target name). Re-run the workflow.

### Fastlane — Fastfile not found at lanes/ios

- **Этап:** CI step that runs Fastlane (e.g. `bundle exec fastlane build_for_testflight`).
- **Ошибка:**
  ```
  [!] Could not find Fastfile at path '.../fastlane/./lanes/ios'
  Error: Process completed with exit code 1.
  ```
- **Фикс:** In `fastlane/Fastfile` use `import "./lanes/ios.rb"` (with `.rb`). Run Fastlane from repo root; use the lane by name only (e.g. `bundle exec fastlane build_for_testflight`), not `fastlane ios ...`. In GitHub Actions set `working-directory` to the repo root for the step. Re-run the workflow.

### Build IPA — Match: maximum number of Distribution certificates

- **Этап:** Build IPA → Fastlane lane `build_for_testflight` → step **match** (creating or verifying Distribution certificate with Apple).
- **Ошибка:**
  ```
  Could not create another Distribution certificate, reached the maximum number of available Distribution certificates.
  (Apple API: "You already have a current Distribution certificate or a pending certificate request.")
  ```
- **Причина:** In the Apple Developer account the limit of Distribution certificates for the team is already reached, or there is an existing (or pending) certificate and Match is trying to create another one.
- **Фикс:** **Clear the already created certificates in the Apple Developer account** so that Match can create a new one, or reuse the existing one from the Match git repo.  
  1. Open [Apple Developer Portal](https://developer.apple.com/account) → **Certificates, Identifiers & Profiles** → **Certificates**.
  2. Find **Distribution** (Apple Distribution) certificates for your Team and **Revoke** the ones you no longer need (or that were created for other apps/teams). Apple allows only a limited number of Distribution certificates per team (e.g. 3); revoking frees a slot.
  3. Optionally revoke unused **Development** certificates if you hit limits there.
  4. If the Match git repo already contains valid certs and profiles for this app, you can run Match in **readonly** mode so it does not try to create new certs (use existing ones from the repo).  
  After revoking, re-run the workflow. If you use a fresh Match repo with no certs yet, Match will create a new Distribution certificate after the cleanup.



### IDE / Git — not showing changes (e.g. Git-Rider)

- **Этап:** Local work in Rider (or similar) with VCS.
- **Ошибка:** Git does not show changes; repository root is not detected.
- **Фикс:** Open the parent directory (the folder that contains the project) as the project so the repo root is correct. Or in Rider: Settings → Version Control, add the directory where `.git` lives as VCS root. Use File → Synchronize or Invalidate Caches / Restart if needed.

---

## CI (GitHub Actions)

**Secrets** (Settings → Secrets and variables → Actions → Secrets; names must match exactly):

- `APPSTORE_KEY_ID` — App Store Connect API key ID (passed to env as ASC_KEY_ID)
- `APPSTORE_ISSUER_ID` — App Store Connect issuer ID (passed as ASC_ISSUER_ID)
- `APPSTORE_P8` — App Store Connect .p8 key content, **Base64-encoded** (passed as ASC_KEY)
- `GH_PAT` — GitHub PAT for Match repo access
- `MATCH_PASSWORD` — Match certificates passphrase. **Optional:** if not set, an empty password is used; this works only when the Match certs repo was created (or re-encrypted) with an empty passphrase.

**Variables** (Settings → Secrets and variables → Actions → Variables):

- `APPLE_TEAM_ID`
- `BUNDLE_IDENTIFIER`
- **`XC_TARGET_NAME`** — **required.** Set to **`IceVault`** (scheme and main app target name). If this variable is missing or empty, the Build IPA job will fail: code signing will not be applied to the main target (`targets | []`) and `ipa_path.txt` may be missing. See subsection *Build IPA — code signing not applied to main target / ipa_path.txt missing* above.
- `MATCH_GIT_URL` — Match certificates repo URL
- `LAST_UPLOADED_BUILD_NUMBER` — last uploaded build number (updated after upload)
- `APPLE_APP_ID` — numeric Apple app ID (for upload_to_testflight)

---

## Other

### Build & sign

*(Add specific errors and solutions as they occur: этап → ошибка → фикс.)*

### TestFlight upload

*(Add specific errors and solutions as they occur: этап → ошибка → фикс.)*

### Match / certificates

- **Empty password (no MATCH_PASSWORD secret):** The lane sets `MATCH_PASSWORD` to `""` when the secret is not set and applies a patch so the Match gem accepts empty password for encryption. Decryption and encryption will succeed only if the certificates repo was created with an empty passphrase (e.g. `fastlane match appstore` and press Enter when asked for password). To switch an existing repo to empty password: `fastlane match change_password` and set the new password to empty. You can remove the `MATCH_PASSWORD` secret from GitHub Actions.

*(Add other errors and solutions as they occur: этап → ошибка → фикс.)*

### Firebase / GoogleService

*(Add specific errors and solutions as they occur: этап → ошибка → фикс.)*
