# iOS readiness (Gloamline)

Written 2026-11-23 by the Producer (acting as DevOps / Build Engineer and Technical Director), overnight run. Nothing here has been bought, enrolled or signed. Costs are Apple's public prices as the Producer knows them; check apple.com before paying. **No iPhone build has ever been made, and nothing has run on an iPhone.** The web build at https://gloamline-playtest.vercel.app runs in iPhone Safari today, and is the only iPhone path until the items below are done.

## 1. What blocks an iPhone build today

| # | Blocker | Why | Who |
|---|---|---|---|
| B1 | **A Mac with Xcode** | Godot exports an Xcode project for iOS; only Xcode on macOS can build, sign and upload it. This machine is Windows with WSL (Linux), so it cannot. | Founder: buy or borrow a Mac (any Apple-silicon Mac on a current macOS), or rent a cloud Mac (for example MacinCloud or a CI service with macOS runners) |
| B2 | **Apple Developer Program membership** | Needed to sign for real devices beyond 7-day personal testing, for TestFlight and for the App Store. USD 99 a year. | Founder (spending, account) |
| B3 | **Organisation or individual account** | An organisation account shows the company name on the store and needs a D-U-N-S number (free, from Dun & Bradstreet; can take up to about 2 weeks). An individual account shows the Founder's own name. | Founder |
| B4 | **Godot iOS export templates** | `ios.zip` from the Godot 4.3 templates package (the same package as the Android and web templates; check it is installed on the Mac). | Producer, on the Mac |
| B5 | **Bundle id and app name** | For example `com.<company>.gloamline`. Must not reuse the Android alpha id pattern if the company name changes. Trademark search for "Gloamline" first. | Founder decides; Producer sets up |
| B6 | **Privacy details** | App Store Connect asks what data the app collects. Today: none sent anywhere; saves are local. The app still needs a privacy manifest (`PrivacyInfo.xcprivacy`, required by Apple since 2024; Godot 4.3's iOS export has privacy manifest options) and a privacy policy URL for the store. | Producer drafts; Founder publishes the policy page |
| B7 | **Export compliance** | The app uses no encryption beyond the OS (HTTPS is not used by the game itself), so it should answer "no" or "exempt". `ITSAppUsesNonExemptEncryption = NO` in the plist. | Producer |

## 2. Apple enrolment steps (Founder)

1. Make or choose an Apple ID with two-factor authentication on, in the name of the person who will own the account.
2. For a company account, get a D-U-N-S number for the company (free) and make sure the legal name matches exactly.
3. Enrol at developer.apple.com/programs (the Apple Developer app on an iPhone is the quickest way), and pay USD 99 a year.
4. Once approved, in App Store Connect: accept the agreements and, before any paid feature, fill in tax and banking.
5. Add the Producer's workflow as needed. The Founder keeps the Account Holder role; an "App Manager" or "Developer" user can upload builds. Keys and certificates are never sent by chat or email, and never committed to the repository.

## 3. Signing and TestFlight plan

1. **Certificates:** on the Mac, Xcode, Settings, Accounts: sign in and let Xcode manage signing ("Automatically manage signing"). This makes the Apple Development and Apple Distribution certificates. Back up the distribution certificate and private key (a `.p12` with a strong password) to the Founder's password manager, not the repo.
2. **App id and profile:** create the bundle id in the developer portal (Xcode can do it automatically). Capabilities: none needed today (no push, no in-app purchase yet).
3. **Godot export preset "iOS":** Team ID, bundle id, version 0.12.0 and build number, `targeted_device_family` iPhone only, portrait only, icons (1024 px master plus the sizes Godot asks for), launch screen (storyboard with the dusk colour and the logo), GL Compatibility renderer (same as Android and web).
4. **Build:** export the Xcode project from Godot, open it in Xcode, select "Any iOS Device (arm64)", then Product, then Archive.
5. **Upload:** Organizer, Distribute App, App Store Connect, Upload. Processing takes 10 to 60 minutes.
6. **TestFlight internal testing:** up to 100 team members, with no Apple review. Add the Founder first.
7. **TestFlight external testing:** up to 10,000 testers by email or a public link. The first build of each version needs a short beta review, usually about a day. External testers need the TestFlight app.
8. **After each build:** the Founder's phone test list from the release notes, plus the in-game "Copy feedback note" with the build id.

Rough time once B1 to B3 are done: 1 to 2 days to the first internal TestFlight build. Enrolment itself can take from a day to 2 weeks with a D-U-N-S number.

## 4. Godot iOS risks for this game

| Risk | What could happen | What to do |
|---|---|---|
| R1 OpenGL ES on iOS | GL Compatibility on iOS runs on OpenGL ES 3.0, which Apple deprecated long ago (still present). Shaders (`arena_ground.gdshader`, fog mask) may behave differently, and Apple could remove OpenGL some day. | Test the arena on a real iPhone early. Plan B is the Mobile renderer (Vulkan through MoltenVK), which costs a perf re-baseline |
| R2 Safe areas | The notch or Dynamic Island and the home indicator cover the top and bottom of a 720 x 1280 portrait frame; headers (96 px) and the tab bar (112 px) could sit under them | Read `DisplayServer.get_display_safe_area()` and pad the header and tab bar; screenshot tests with an iPhone 15 safe-area variant |
| R3 Aspect ratios | iPhones are about 19.5:9, taller than our 16:9 base; the "tall" layout exists and is tested, but not at the exact iPhone sizes | Add 1179 x 2556 and 1170 x 2532 to the shots matrix |
| R4 120 Hz ProMotion and low-processor mode | Frame pacing differs. Low-processor mode (on since 0.7) may look choppy at 120 Hz or waste battery | Measure the arena frame time on the phone with the Q1 tester timings; cap at 60 if needed |
| R5 App lifecycle | iOS suspends apps quickly; the autosave on pause (`NOTIFICATION_APPLICATION_PAUSED`) must finish fast, and there is no back button or quit | Already no quit on the web; same rule for iOS; test the pause and resume save |
| R6 Haptics and sound | `Input.vibrate_handheld` works on iPhone only in limited form; the silent switch mutes sound (good, matches the mute-friendly design) | Keep haptics optional (already); test the first-tap sound unlock |
| R7 SVG and ThorVG | SVG icons load through ThorVG; never tested on iOS (also never on Android) | Bake SVG to PNG atlases at build time if any glyph renders wrong |
| R8 Text input | The save-code restore pastes long text; iOS paste prompts and the keyboard may cover the box | Test on the phone; the code could also be shared via the share sheet later |
| R9 App Store review | Guideline 4.2 (minimum functionality) is fine for a full game; the name needs a clear trademark; esports themes are fine; no gambling or loot boxes (none today). An alpha may be rejected as "incomplete" for the store, but TestFlight is fine | Use TestFlight for alpha and beta; submit to the store only at release |
| R10 Build size | The Android APK is 25 MB; iOS apps are usually larger (bitcode-free, arm64 only). Fine under the 200 MB cellular download limit | No action |
| R11 Godot version | Godot 4.3 iOS export works, but newer Xcode versions sometimes need template fixes; Apple requires building with a recent Xcode SDK for uploads | Check that the Godot 4.3 templates build with the current Xcode before committing to dates. A move to Godot 4.4 or later is a separate decision |

## 5. Decisions owed (Founder)

1. A Mac: buy, borrow or rent. That is spending.
2. The Apple account: company (needs a D-U-N-S number) or personal; USD 99 a year. That is an account and spending.
3. The bundle id and company name, after the trademark search for "Gloamline".
4. A privacy policy page: the host, and who owns it.
