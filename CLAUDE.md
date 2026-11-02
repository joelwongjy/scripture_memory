# Scripture Memory

Two native apps, one product: iOS in `scripture memory/` (SwiftUI) and Android in `android/` (Kotlin, Compose).

- Every feature and fix ships on both platforms unless the user says otherwise. `android/PORTING.md` maps the files and sets the rules.
- Android uses no Material components. Controls come from `ui/components`.
- Verses live only in `scripture memory/Resources/`. Expected logic results live in `shared/test-vectors/`, and both test suites read them.
- Release with `Scripts/release.sh`. See `RELEASING.md`.
