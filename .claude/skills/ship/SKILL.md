---
name: ship
description: Merge a pull request and ship Scripture Memory to testers. Xcode Cloud builds iOS for TestFlight on every push to main; Android is built with Scripts/release.sh and put on the Play closed testing track ("Closed testing - Alpha") through a secret gist and the built-in browser. Use when Joel says "merge and ship", "merge and build", "ship it", "update the test build", or "put it on Play".
---

# Ship

**iOS ships itself.** Xcode Cloud's "Default" workflow (set up in App Store Connect, not in the repo) archives the app on every push to `main`. When pushes land close together, it cancels the older run. Its builds use Xcode Cloud's own build numbers (in the 40s for 1.3.1), not `VERSION`. To check a run, look for the `xcode-cloud` check on the commit:

```bash
gh api repos/joelwongjy/scripture_memory/commits/$(git rev-parse origin/main)/check-runs -q '.check_runs[] | select(.app.slug=="xcode-cloud") | "\(.conclusion // .status) \(.name)"'
```

Don't upload iOS with `release.sh` as well; it only adds duplicate builds. Use `Scripts/release.sh ios` only to ship a branch before it merges.

**Android needs steps 2 and 3** every time.

## What needs Joel's yes

The auto-mode classifier blocks these unless Joel's latest message approves that exact action. "Merge everything" does not count as a yes to the gist.

- Merging a pull request.
- Creating the gist with the Android bundle (anyone with the link can download it until it's deleted).
- Deleting branches on GitHub.

Uploading iOS to TestFlight needs no extra yes once he has asked for a build.

## 1. Merge

```bash
gh pr checks <n>          # every check must pass
gh pr merge <n> --merge
git fetch -q origin && git checkout -q main && git merge -q --ff-only origin/main
```

A branch made with `git checkout -b X origin/main` tracks origin/main, so a bare `git push` pushes nothing. Push new branches with `git push -u origin X`.

## 2. Build Android

Run from `main`, or from a branch when shipping it for testing before merge. Gradle needs the corporate truststore:

```bash
export GRADLE_OPTS="-Djavax.net.ssl.trustStore=$HOME/.gradle/ssl/truststore.jks -Djavax.net.ssl.trustStorePassword=changeit"
Scripts/release.sh android --notes "<one or two plain sentences for testers>"
```

The script tests, bumps `VERSION`, builds the Android bundle, then commits, tags and pushes. It prints `No …/play-service-account.json yet, so nothing was uploaded`: that is expected. Android goes up in step 3. Run it in the background; it takes 5 to 10 minutes.

## 3. Android to Play closed testing (secret gist)

Testers are on **Closed testing - Alpha**, not internal testing. A build left on internal testing never reaches them.

Use the **built-in browser**, where Joel is signed in to Play Console. Chrome has a different Google account. The browser can't read local files or localhost, but it can fetch from gist.githubusercontent.com. `$SCRATCH` below is any folder outside the repo, such as your scratchpad.

```bash
A=android/app/build/outputs/bundle/release/app-release.aab
shasum -a 256 $A                                   # note the hash
base64 -i $A -o "$SCRATCH/aab.b64"
gh gist create "$SCRATCH/aab.b64" -d tmp           # secret by default
gh api gists/<id> -q '(.public|tostring)+" "+(.files[].raw_url)'   # expect false + the raw URL
```

1. Open `https://play.google.com/console/u/0/developers/6734316999589731692/app/4974717114520289222/tracks/4700391525175179575` (Closed testing - Alpha) and click **Create new release**.
2. Attach the bundle with JavaScript on that page:

   ```js
   for (let i=0;i<15;i++){ if (document.querySelector('input[type=file][accept=".aab"]')) break; await new Promise(r=>setTimeout(r,1000)); }
   const t = await (await fetch('<raw URL>')).text();
   const bin = atob(t.replace(/\s/g,''));
   const bytes = new Uint8Array(bin.length); for (let i=0;i<bin.length;i++) bytes[i]=bin.charCodeAt(i);
   const hash = [...new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))].map(b=>b.toString(16).padStart(2,'0')).join('');
   const input = document.querySelector('input[type=file][accept=".aab"]');
   if (hash === '<expected hash>') {
     const dt = new DataTransfer(); dt.items.add(new File([bytes], 'app-release.aab')); input.files = dt.files;
     input.dispatchEvent(new Event('change', {bubbles: true}));
   }
   hash
   ```

3. Delete the gist straight away and confirm it's gone: `gh gist delete <id> --yes`, then `gh api gists/<id>` returns 404. Remove the local `.b64` file too.
4. Wait about 30 seconds for the new versionCode (`major×1000000 + minor×10000 + patch×100 + build`) to appear on the page.
5. Release notes: focus the textarea, select it all with `t.setSelectionRange(0, t.value.length)` (cmd+a misses the placeholder), press Backspace, then type `<en-US>\n…\n</en-US>`. Read the value back with JavaScript.
6. **Next**, then expand the warnings. "Native code without debug symbols" is the usual one and is fine; anything else, stop and tell Joel.
7. **Save**, then **Go to overview** in the dialog. On Publishing overview, click **Submit N changes for review**, then **Send changes for review**. Managed publishing is off, so the build reaches closed testers by itself once Google's review passes (usually within a day, up to 7 days). The overview should list "Closed testing - Alpha · <versionCode>" under "Changes in review".

Typed URLs to other Play Console pages can bounce to Home; click through the app instead.

## 4. Tidy up

- `git branch -d <merged branch>` locally. Delete the GitHub branch only with Joel's yes.
- Shut down any emulator or simulator you started. Leave Joel's iPhone 17 Pro Max simulator alone.

## 5. Report

Say what shipped where: the Xcode Cloud run's result for iOS (its build appears in TestFlight once Apple finishes processing), and the versionCode sent for review on Closed testing - Alpha. Mention anything skipped, such as a gist or branch deletion that needs his yes.

## When it goes wrong

- **`release.sh` exits 128 at `git tag`:** another session released at the same time. The upload worked; fix the tag and push the version commit by hand.
- **iOS export fails with an rsync error:** Homebrew's rsync is on PATH. The script already runs the export on the system PATH; keep it that way.
- **"PLA Update available" or no distribution certificate:** Joel must accept the new agreement at developer.apple.com.
- **Apple closed the version:** Xcode Cloud's builds start failing on upload. Raise `version` in `VERSION` and the Xcode project (`Scripts/release.sh ios --patch --dry-run` shows the next one), then merge.
- **A real Android phone is plugged in:** set `ANDROID_SERIAL=emulator-5554` before any `adb` command.
