# Releasing on Google Play

Expect about four weeks, nearly all of it waiting. Steps marked **You** need your account or identity.

## 1. Before the Play Console

- [ ] **You:** merge [#37](https://github.com/joelwongjy/scripture_memory/pull/37), then [#39](https://github.com/joelwongjy/scripture_memory/pull/39).
- [x] Publish the privacy policy update.
- [ ] **You:** back up `~/.config/scripture-memory/upload.jks` and `android-signing.properties` somewhere safe, such as a password manager.

## 2. Create your developer account (allow up to a week)

- [ ] **You:** register at [play.google.com/console/signup](https://play.google.com/console/signup). Choose a personal account and pay the US$25 fee.
- [ ] **You:** verify your legal name, address, phone and email. Google may also ask you to confirm you have an Android device.
- [ ] Your legal name, country and developer email appear publicly on Google Play. Use the email you want shown.

## 3. Create the app (30 minutes)

- [ ] **You:** Create app. Use the name in `listing.md`, App, Free.
- [ ] Paste the store listing and upload the graphics from `listing.md`.
- [ ] Fill in the forms with `app-content.md`.

## 4. Internal test (a day)

This puts the app on your own phone before anyone else sees it.

- [x] Build the bundle with `Scripts/release.sh android`.
- [ ] **You:** Test and release > Internal testing > Create release. Accept Play App Signing, then upload `android/app/build/outputs/bundle/release/app-release.aab`.
- [ ] **You:** add a tester who has an Android phone, and ask them to install from the link. Ask them to check what no emulator could: dictation, haptics, and TalkBack.

## 5. Closed test (14 days)

- [ ] **You:** Test and release > Closed testing > Create track. Add the testers' emails, promote the internal build, and submit it for review.
- [ ] **You:** once it's approved, send the message in `tester-invite.md` with the opt-in link.
- [ ] Check that at least 12 people stay opted in for 14 days in a row. Keep a record of feedback.

## 6. Apply for production (up to a week)

- [ ] **You:** Dashboard > Apply for production, using the draft in `tester-invite.md`.
- [ ] Google usually replies within seven days. It may ask for more testing.

## 7. Go live

- [ ] **You:** Production > Create release. Promote the tested build and start with a 20% rollout. Choose your countries, or all of them.
- [ ] Watch crashes in Play Console for a couple of days, then go to 100%.

## 8. After launch

- [ ] Add a Play API key so `Scripts/release.sh` can upload. See `RELEASING.md`.
- [ ] Update the README and support page, which describe only the iPhone app.

## Installing before the Play release

Singapore is in the first group of countries for Android developer verification, so an APK from outside a store may not install normally. Use the internal test in step 4.

## Sources

- [App testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Target API levels](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
- [Preview assets](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en)
- [Data safety](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
- [Required developer information](https://support.google.com/googleplay/android-developer/answer/13628312?hl=en)
- [App content](https://support.google.com/googleplay/android-developer/answer/9859455?hl=en)
- [Android developer verification](https://android-developers.googleblog.com/2026/06/android-developer-verification.html)
