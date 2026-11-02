# Releasing

One command ships both apps:

```bash
Scripts/release.sh all --notes "What changed"
```

It runs the Swift and Kotlin tests, moves `VERSION` to the next build, uploads to TestFlight and the Play internal track, commits, tags and pushes. Use `ios` or `android` in place of `all` to ship one app. Add `--patch` or `--minor` for a new version; the default is a new build of the current one. `--dry-run` prints what would happen.

## Version numbers

`VERSION` is the only place a version lives. `release.sh` writes it into the Xcode project, and Gradle reads it directly. The Android `versionCode` is `major×1000000 + minor×10000 + patch×100 + build`, so it always goes up.

Apple closes a version once it is approved. When that happens, `release.sh` moves to the next patch version and uploads again.

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
