# Releasing

Merging to `main` ships both apps. The Release workflow (`.github/workflows/release.yml`) takes the next build number, tags it, and uploads iOS to TestFlight and Android to the Play internal track. The release notes are the pull request's title. Changes to Markdown and `docs/` don't trigger it. To ship without a merge, run the workflow from the Actions tab.

`Scripts/release.sh` still works from a Mac, for a build off a branch:

```bash
Scripts/release.sh all --notes "What changed"
```

It runs the Swift and Kotlin tests, moves `VERSION` to the next build, uploads to TestFlight and the Play internal track, commits, tags and pushes. Use `ios` or `android` in place of `all` to ship one app. Add `--patch` or `--minor` for a new version; the default is a new build of the current one. `--dry-run` prints what would happen. The workflow skips the commit it pushes.

## Version numbers

`VERSION` holds the version. The build number is one past the highest `v<version>-<build>` tag, so the workflow and `release.sh` never reuse one; `Scripts/next_build.sh` prints it. The Android `versionCode` is `major×1000000 + minor×10000 + patch×100 + build`, so it always goes up, and a version has room for 99 builds.

Apple closes a version once it is approved. `release.sh` then moves to the next patch version on its own. The workflow stops with an error instead: run `Scripts/release.sh --patch --dry-run` to see the next version, set it in `VERSION`, and merge that.

## Release workflow secrets

Set these once in GitHub under Settings → Secrets and variables → Actions, or with `gh secret set` from the repository folder.

| Secret | What it is |
| --- | --- |
| `ASC_KEY` | The App Store Connect API key file (`AuthKey_….p8`). Give the key the Admin role, or App Manager with access to certificates, so CI can sign. |
| `ASC_KEY_ID` | The key's ID, the part of the file name after `AuthKey_`. |
| `ASC_ISSUER_ID` | The Issuer ID shown above the keys in App Store Connect → Users and Access → Integrations. |
| `ANDROID_UPLOAD_KEYSTORE` | `~/.config/scripture-memory/upload.jks`, base64 encoded. |
| `ANDROID_SIGNING_PROPERTIES` | `~/.config/scripture-memory/android-signing.properties`. |
| `PLAY_SERVICE_ACCOUNT` | The Play service account's JSON key. |

```bash
gh secret set ASC_KEY < ~/Downloads/AuthKey_KEYID.p8
gh secret set ASC_KEY_ID --body KEYID
gh secret set ASC_ISSUER_ID --body ISSUER-ID
base64 -i ~/.config/scripture-memory/upload.jks | gh secret set ANDROID_UPLOAD_KEYSTORE
gh secret set ANDROID_SIGNING_PROPERTIES < ~/.config/scripture-memory/android-signing.properties
gh secret set PLAY_SERVICE_ACCOUNT < ~/.config/scripture-memory/play-service-account.json
```

## Before a release

1. Make the change on both platforms. `android/PORTING.md` maps each iOS file to its Android home.
2. If scheduling, diffing or text handling changed, regenerate the shared vectors:

   ```bash
   REGENERATE_VECTORS=1 swift test
   ```

3. Check the changed screens on an iOS simulator and an Android emulator.

## Verses

`scripture memory/Resources/*.json` is the only copy, and both apps bundle it at build time. Corrections published to Supabase reach both apps with no release.

## One-time setup

Secrets stay outside the repo, in `~/.config/scripture-memory/`.

| File | What it is |
| --- | --- |
| `upload.jks` | Android upload key. Created already. |
| `android-signing.properties` | Passwords for that key. Created already. |
| `play-service-account.json` | Google Play API key. Still needed. |

The first Play release has more steps. Follow `docs/play-store/README.md`, which also holds the store listing, graphics and form answers.

To finish Android publishing:

1. Create the app in Play Console with the package name `joel.scripturememory`.
2. Upload the first bundle by hand. Play needs this once before the API can publish:

   ```bash
   Scripts/release.sh android --notes "First build"
   ```

   Then upload `android/app/build/outputs/bundle/release/app-release.aab` to the internal testing track.
3. In Google Cloud, create a service account, download its JSON key and save it as `~/.config/scripture-memory/play-service-account.json`.
4. In Play Console under Users and permissions, invite the service account's email and grant it release access.

After that, `Scripts/release.sh` uploads with no extra steps.
