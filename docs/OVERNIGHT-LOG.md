# Overnight run log (2026-11-23 to 24)

One line per increment: time (SGT), what was done, gate result, commit. Founder's queue Q0 to Q9, then the 0.12.0 release. Nothing here is measured on a phone.

- 2026-11-24 01:27 · Q0 0.11.2: Fennimore support effect (Fen Fog ally heal, Leap Frog shield), q_k +7%, hero re-tune; 40,000 games per format: bands in tolerance, heroes outside 45-55 1/0/0, Fennimore 45.7/47.3/49.3; golden vectors re-recorded; two noisy alpha6 lines re-set (kill share 1.25, winner kills 60%) · fast gate ALL GREEN · commit (this one)
- 2026-11-24 01:28 · Q9 docs: ART-PRODUCTION-BRIEF.md (asset list, routes A/B/C with estimated cost ranges, commission brief) and IOS-READINESS.md (blockers, enrolment, TestFlight plan, risks); docs only · fast gate ALL GREEN (run with Q1 on the tree) · commit (this one)
- 2026-11-24 01:47 · Q1 tester timings: device and browser line, build id on every platform, draft time, game start (Start the match to the first arena frame), arena frame avg/worst/slow per view (Field, Action, All) in Settings and Copy feedback note; web probe returns them · fast gate ALL GREEN · commit (this one)
- 2026-11-24 02:14 · Q2 WebKit: Playwright WebKit (iPhone 15) and Chromium (Pixel 7) both run title to report; differences logged in WEB-PLAYTEST.md (WebKit-only WebGL framebuffer warning from Godot's renderer, headless audio); iPhone launch images and Home Screen title added; first load about 8.8 MB brotli · fast gate ALL GREEN · commit (this one)
- 2026-11-24 02:33 · Q3 event log: ward events carry the exact spot; 'decisive' events for fights with 3+ kills and Cairns; vision and Action camera read them; results identical, golden vectors re-recorded for the logs · fast gate ALL GREEN · commit (this one)
