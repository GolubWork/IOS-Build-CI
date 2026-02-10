# iOS Build CI — Fastlane & GitHub Actions for IceVault

This folder contains all logic for building and deploying the IceVault iOS app: Fastlane lanes (signing, build, TestFlight) and GitHub Actions workflows.

## Contents

- **fastlane/** — Fastfile, iOS lanes (`build_for_testflight`, `build_upload_testflight`), Match config, empty-password patch
- **.github/** — workflow definitions and CI documentation
- **Gemfile** / **Gemfile.lock** — Ruby deps (fastlane, cocoapods, xcodeproj)

## Using this in a separate repository

1. Create a new repo and copy the **contents** of this folder to the **root** of the new repo (so `.github/`, `fastlane/`, `Gemfile`, `Gemfile.lock` are at the repo root).
2. Update workflows: they currently assume a single repo (checkout + run fastlane from workspace). In the new repo you will need to:
   - Check out the **application repository** (IceVault) in the workflow.
   - Either copy this repo’s `fastlane/` (and optionally Gemfile) into the app checkout and run `bundle exec fastlane ...` from the app directory, or keep fastlane in the app repo and use this repo only for workflow definitions and docs.
3. Fastlane lanes expect to run from the **app project root** (where `IceVault.xcodeproj` and `Podfile` live); project root is derived from the fastlane folder’s parent directory.
4. Configure the same Secrets and Variables in the new repo (or in the app repo if workflows run there). See `.github/README.md` for the list.

## Local use (when inside the main IceVault repo)

From the IceVault repo root:

```bash
bundle install
bundle exec fastlane build_for_testflight   # build only
bundle exec fastlane ios build_upload_testflight  # build + upload to TestFlight
```

See the main repo’s [README.md](../README.md) and [Docs/TROUBLESHOOTING.md](../Docs/TROUBLESHOOTING.md) for full CI/CD and troubleshooting details.
