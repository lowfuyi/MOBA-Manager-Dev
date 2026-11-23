# Web playtest build (0.11.1 web)

Founder request of 2026-11-22: a web build that anyone with the link can play on an iPhone, an Android phone or a desktop, for gameplay and design feedback (not for performance). **Browser speed is not phone speed:** the browser runs the game through WebAssembly and WebGL. A strong desktop may run it faster than a cheap phone, and a phone browser may run it slower than the installed app. Frame rate, loading time and battery use are measured only on the Android APK.

## What the web build is

- Godot 4.3 Web export, GL Compatibility (WebGL 2), **single-threaded**, so the host needs no special headers (no SharedArrayBuffer or cross-origin isolation).
- PWA: "Add to Home Screen" opens it full screen with its own icon (teal circle, coral hexagon). The loading screen has a progress bar and shows the build id.
- **Build id**: shown on the loading screen, in Settings under "Send feedback" (Build: …), and in the copied feedback note. Format: `0.11.1-alpha-web-<commit>-<UTC time>`. A `+` after the commit means files in game/ had uncommitted changes when it was built.
- **Always the newest build**: every load asks the service worker for an update. A new build's service worker has a new cache name (Godot stamps one on each export), takes over and reloads the page once. Every file is also served with `Cache-Control: max-age=0, must-revalidate`.
- Portrait 720x1280. On a wide window (desktop, phone turned sideways) the game keeps 9:16 with bars at the sides. On a tall phone it uses the full height (the "tall" layout).
- Mouse and touch both work. Sound starts after the first tap (browsers allow sound only after a touch). Vibration works where the browser supports it (Android Chrome) and is silently skipped elsewhere (iPhone). There is no back-button quit.
- **Saves live in the browser** (IndexedDB). Clearing site data, private browsing or low storage can delete them. Settings, "Your save": **Copy save code** (one line of text; also shown in a box to copy by hand if the browser refuses the clipboard) and **Restore from a save code** (paste, check, confirm). The code is the save JSON, gzipped and base64-encoded: nothing new is stored in the save.
- **Send feedback** (Settings): copies the feedback note (build id, club, season, pace) and opens the tester feedback form in a new tab. It appears only when the build was made with `FEEDBACK_URL`. Without it, "Copy feedback note" still works.
- Not indexed: `<meta name="robots" content="noindex, nofollow">`, the `X-Robots-Tag: noindex, nofollow, noarchive` header and a `robots.txt` that disallows everything. Not secret, though: anyone with the link can play.
- Not shipped: tests (`exclude_filter tests/*`), tools, docs, the debug template (release export). The Godot script-class list still names the test classes (names only, no code).

## Build

```
GODOT=/path/to/Godot_v4.3-stable_linux.x86_64 FEEDBACK_URL=https://forms.gle/... tools/build_web.sh
```

Output: `build/web/` (git-ignored; never commit it). It holds index.html/.js/.wasm/.pck, the service worker, the manifest, icons, `vercel.json`, `robots.txt` and `build.txt`. Needs the Godot 4.3 export templates (`web_nothreads_release.zip`).

## Deploy (Vercel CLI)

1. `vercel whoami` must print the Founder's own account (lowfuyi@gmail.com). If it prints any other account, stop and run `vercel login` with that address. Never deploy into another business's team.
2. `cd build/web && vercel deploy --prod --yes` (first time: project name `gloamline-playtest`, no framework, no build command; the folder is already the output). On this machine `npx` is the Windows Node.js, which holds the login and cannot work in an Ubuntu folder, so copy `build/web/` to a Windows folder first (e.g. `/mnt/c/Users/Fuyi/gloamline-web`) and run `npx vercel@latest deploy --prod --yes` from there.
3. The production URL, **https://gloamline-playtest.vercel.app** (first deployed 2026-11-23, build `0.11.1-alpha-web-df6213b-20261123-1243`), is the tester link. Each new deploy replaces it, and testers get the new build on their next load.

Plan (Founder decision, 2026-11-22): the **free Hobby plan**. Vercel's terms (section 4, read 2026-11-22) say Hobby is "for your personal or non-commercial use"; the Founder accepted that risk for an unlisted, unpaid playtest. Vercel may disable a Hobby deployment at its discretion, so the build stays plain static files with no Vercel-only feature: no build step, no functions, no analytics, no Vercel domain settings. The only Vercel file is `vercel.json`, and it sets two headers.

## Moving to another host (minutes)

`build/web/` is a plain static folder. Any host that serves static files works, because the build is single-threaded and needs no cross-origin isolation headers. Two headers matter: `X-Robots-Tag: noindex` (also covered by the page's robots meta and `robots.txt`) and `Cache-Control: max-age=0, must-revalidate` (so testers get new builds quickly; the service worker also checks on every load).

- **Cloudflare Pages** (free plan allows commercial use): `npx wrangler pages deploy build/web --project-name gloamline-playtest`. It reads `_headers` from the folder.
- **Netlify**: drag `build/web/` into app.netlify.com/drop, or `npx netlify-cli deploy --prod --dir build/web`. It reads `_headers`.
- **itch.io** (made for game playtests; can be a restricted page with a password): zip the *contents* of `build/web/`, upload as an HTML game, tick "SharedArrayBuffer support" **off**, viewport 720x1280, mobile friendly, portrait. itch.io sets its own headers; noindex comes from the restricted or draft setting.
- **GitHub Pages**: works, but it cannot set headers (the robots meta and `robots.txt` still apply), and the repository may need to stay private.

Then send testers the new link. Saves are per site address, so testers moving hosts must use Settings, "Your save", "Copy save code" on the old link and "Restore from a save code" on the new one.

## Note for testers (copy and send with the link)

> **Gloamline playtest** - an esports manager game for phones, early alpha.
> Open the link in **Chrome (Android) or Safari (iPhone)**. For the best view, use **Add to Home Screen** (Safari: Share, then Add to Home Screen; Chrome: menu, then Add to Home screen) and open it from there.
> The first load downloads about 9 MB. Later loads are quick.
> Speed in the browser is **not** what the phone app will feel like, so please judge the game, not its speed.
> Your season is saved in this browser. To keep it safe, open Settings, "Your save", "Copy save code" now and then.
> **Feedback:** Settings, "Send feedback" (it copies your build number and opens the form; paste it into the first answer). Tell us what was fun, what was confusing and where you stopped.

## Measured (2026-11-23, desktop, not a phone)

Playwright, Pixel 7 viewport, software WebGL (SwiftShader), against the live link:
- **Load:** the first visit transfers about 8.8 MB (wasm 7.5 MB, pck 1.3 MB, js 0.09 MB, brotli). The title screen appears 4.0 s after the page opens.
- **Starting a game:** New game, then Home, takes 3.4 s.
- **The flow:** a full draft with 5 bans and 5 picks, then the match, then the report, with 0 errors. A full match at speed x1 took 216 s on the local copy.
- **Frame rates** of 5 to 19 in this test come from software rendering and say nothing about a phone. Real phone browsers use the GPU but run WebAssembly slower than a desktop. **Browser speed is not phone speed**; judge speed only on the Android APK.

Vercel scope: the account (lowfuyi-1301) has one team, "InvoiceNowCheck" (Hobby). The project gloamline-playtest is in it, because it is the account's only scope.

## WebKit (iPhone Safari engine) against Chromium (2026-11-24, overnight Q2; desktop WSL, not a phone)

Same build (65830da+, the Q1 timings in), served from `http://localhost:8765` (the Playwright WebKit build here has no TLS support, so the live https link cannot be opened in it). Flow: title, New game, take over a club, skip tutorial, draft (5 bans and 5 picks), full match at x1, report. Driver `~/opt/pw/drive.js` (env `BROWSER=webkit DEVICE="iPhone 15"`).

| | WebKit 18.2, iPhone 15 viewport (393 x 852 at 3x) | Chromium 131, Pixel 7 viewport (412 x 915 at 2.6x) |
|---|---|---|
| Title screen | 3.7 s | 2.7 s |
| Full flow to the report | yes, 0 script errors | yes, 0 errors |
| Draft time (5 bans, 5 picks, driver taps) | 13 s | 18 s |
| Game start (Start the match to first arena frame) | 649 ms | 674 ms |
| Action view frame time, avg / worst | 33.5 / 135 ms | 132 / 150 ms (software GL, SwiftShader) |
| Console | 256 x "WebGL: INVALID_OPERATION: Read and write color attachments cannot be the same image" (WebKit stops logging at 256); 17 x "Failed to start the audio device" | none |
| Picture | correct; thin bars left and right (the iPhone viewport is wider than 9:16; the frame letterboxes by design) | correct; fills the width |

Both frame times come from software rendering on this machine and say nothing about a phone. The tester timings (Q1) now give the real numbers from a tester's phone in the feedback note.

**Differences and what was done**
- WebGL warning (WebKit only): raised inside Godot 4.3's GL Compatibility renderer when it copies a framebuffer; the game uses no screen texture or back-buffer copy. Nothing renders wrong in the pictures. Not fixable in game code; it will be re-checked on a real iPhone (the Founder's test list) and after a Godot upgrade.
- Audio start failure: headless WebKit has no sound device. On a real iPhone, Safari starts sound only after the first tap; Godot resumes the audio context on input. To check on a phone: sound after the first tap, and with the silent switch on.
- Side bars on iPhone: by design (portrait 9:16 frame). Tall-phone layout is Q6.
- **Added:** iPhone launch images (`apple-touch-startup-image`, four sizes 750 x 1334 to 1290 x 2796, dusk gradient with the teal circle and coral hexagon, 20 to 44 KB each), generated into the build by `tools/gen_pwa_splash.gd` (not committed, not in the APK), and `apple-mobile-web-app-title`. The PWA icons (144, 180, 512) and manifest were already there.

**First load:** index.wasm 35.4 MB (gzip 8.0 MB), index.pck 1.6 MB (gzip 1.25 MB), index.js 331 KB (gzip 84 KB): about 9.3 MB gzip, about 8.8 MB brotli as Vercel serves it (measured on the live link 2026-11-23). Launch images load only when the game is added to the Home Screen. The wasm is Godot's engine; making it smaller needs a custom engine build without unused modules (a later, separate job).
