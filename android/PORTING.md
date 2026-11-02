# Porting between iOS and Android

The iOS app in `scripture memory/` and the Android app in `android/` are one product. Behaviour, copy, scheduling and data formats match. The Swift code is the reference when they differ, unless this file says otherwise.

## Rules

- Native Kotlin and Jetpack Compose. Only `androidx.compose.foundation`, `ui`, `animation` and `runtime`. No `androidx.compose.material*` imports, no Material theme, no ripples. `Scripts/check_android.sh` fails the build if one appears.
- Every colour, font, size, spring and control comes from `ui/theme` and `ui/components`. A screen never hard-codes a font or defines its own button. If a control is missing, add it to `ui/components`.
- Port behaviour exactly: the same copy, defaults, limits, keys, ordering and edge cases. When Swift has a comment explaining a bug it avoids, keep the fix.
- Port animations with the same timing. SwiftUI `.smooth`, `.snappy` and the durations in the Swift code map to `AppMotion`. Respect reduce motion where iOS does.
- Android-native behaviour where the platforms differ: edge-to-edge, predictive back, the system keyboard, system haptics, runtime notification permission, Google backup instead of iCloud.
- No explanatory code comments. Names carry the meaning; the reason goes in the commit message.
- Match the surrounding Kotlin: small files, `camelCase`, one concern per file, same names as Swift where possible so the two can be read side by side.

## Layout

| iOS | Android |
| --- | --- |
| `scripture memory/Model/` | `app/src/main/java/joel/scripturememory/model/` |
| `scripture memory/Utilities/` | `ui/theme/` for layout and motion, `system/` for platform services |
| `scripture memory/Views/<Area>/` | `ui/<area>/` |
| `scripture memory/Views/Shared/` | `ui/components/` and `ui/study/` |
| `ScriptureWidget/` | `widget/` |
| `Tests/SRSCoreTests/` | `app/src/test/` |
| `scripture memory/Resources/` | Same files, read directly as Gradle assets |

## Shared data

- `scripture memory/Resources/*.json` is the only copy of the verses.
- `shared/test-vectors/*.json` holds expected results for scheduling, diffing and text handling. Swift and Kotlin tests both read them, so logic that drifts fails on one side.

## Building

```bash
cd android
./gradlew :app:assembleDebug
./gradlew :app:testDebugUnitTest
```

On this Mac, set `GRADLE_OPTS="-Djavax.net.ssl.trustStore=$HOME/.gradle/ssl/truststore.jks -Djavax.net.ssl.trustStorePassword=changeit"` first; a corporate gateway re-signs some hosts.

## When you change one app

1. Make the change on the platform you are working on.
2. Find the matching file with the table above and make the same change on the other platform.
3. If the change touches logic, update `shared/test-vectors/`.
4. Run the checks in `RELEASING.md`.
