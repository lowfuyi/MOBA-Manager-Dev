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
3. The production URL (for example `https://gloamline-playtest.vercel.app`) is the tester link. Each new deploy replaces it, and testers get the new build on their next load.

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
> The first load downloads about 10 MB. Later loads are quick.
> Speed in the browser is **not** what the phone app will feel like, so please judge the game, not its speed.
> Your season is saved in this browser. To keep it safe, open Settings, "Your save", "Copy save code" now and then.
> **Feedback:** Settings, "Send feedback" (it copies your build number and opens the form; paste it into the first answer). Tell us what was fun, what was confusing and where you stopped.
