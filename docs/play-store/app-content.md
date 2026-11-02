# App content answers

Play Console > Policy and programs > App content. These match the app as built. You are responsible for what you submit, so correct anything that has changed.

| Form | Answer |
| --- | --- |
| Privacy policy | https://joelwongjy.github.io/scripture-memory-privacy/ |
| Ads | No, the app doesn't contain ads |
| App access | All functionality is available without special access |
| Content rating | See below |
| Target audience | 13 to 15, 16 to 17, 18 and over. Don't select under 13, which brings in the Families policy. |
| Appeals to children | No |
| News app | No |
| Government app | No |
| Financial features | None |
| Health features | None |
| Advertising ID | No |
| Data safety | See below |

## Content rating

Use the email joelwongjy@gmail.com. Category: **Reference, News, or Educational**.

Answer **No** to everything: violence, sexuality, language, controlled substances, gambling, user interaction, sharing location, digital purchases.

## Data safety

| Question | Answer |
| --- | --- |
| Does your app collect or share any required user data types? | Yes |
| Is all user data encrypted in transit? | Yes. TelemetryDeck and Supabase are both HTTPS. |
| Which account creation methods? | None. Users can't create an account. |
| Can users request that their data is deleted? | No. Signals are anonymous, so one person's can't be found. |

Select these two data types, and nothing else.

| Data type | Collected | Shared | Ephemeral | Required or optional | Purpose |
| --- | --- | --- | --- | --- | --- |
| App activity > App interactions | Yes | No | No | Optional | Analytics |
| Device or other IDs | Yes | No | No | Optional | Analytics |

- **Shared is No** because TelemetryDeck is a service provider working only for you, which Google exempts.
- **Optional** is accurate because Settings > Share Anonymous Usage turns it off for everyone.
- **Voice isn't declared.** Dictation runs through the phone's own speech service. The app receives only the recognised text, keeps no audio and sends none to you.
- **Verses, progress and search terms stay on the device**, so they aren't declared.

## Permissions

| Permission | Why |
| --- | --- |
| Microphone | Dictating a verse, only when the user taps the mic |
| Notifications | Daily reminders |
| Run at startup | Re-arming reminders after a restart |
| Network | Analytics and verse corrections |
| Vibrate | Haptics |

None of these needs the sensitive-permissions form. The bundle also lists `FOREGROUND_SERVICE`, added by the WorkManager library. If Play asks about it, say the app has no foreground service feature of its own.

## If Google asks about rights

The app includes NIV text and shows Navigators and DEP artwork. The Acknowledgments say "Used by permission", so keep any permission from Biblica and The Navigators where you can find it. Google can ask for proof if a rights holder complains.
