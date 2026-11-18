# Alpha exit: what only the Founder or a real phone can do

Everything that can be built and proven on a computer is done (see `docs/ALPHA-EXIT-CHECKLIST.md`). These are the only things
left before Alpha can be signed. **Nothing below has been measured yet: nothing has run on a phone except your own tests of 0.7
and 0.8.** Use the latest APK, `gloamline-0.9.0-alpha.apk` (in your Downloads). It installs over any earlier build and keeps your
save. Before each test, open More (Settings) and tap **Copy feedback note**; paste it with your answers so we know the build and
settings.

1. **Smoothness of the arena (your phone).**
   1. Settings: Frame rate 60, Animations on, Sound on.
   2. Play three matches without skipping. Watch the Mossback fight (about 41 to 46 seconds in) and the last fight (66 to 71 s).
   3. Note: any stutter or freeze? Do fights read as fights (charges, bolts, health bars, the deciding kill)? Is the slow-down on
      the deciding kill nice or annoying? Is x2 too fast to follow? Are the sounds pleasant on the speaker, and does the
      vibration on kills feel right or too much?
2. **Heat (your phone).** Fully charged, screen brightness at about half, Frame rate 60: play 30 minutes in one go (about six
   matches with everything in between). Touch the back of the phone at 0, 15 and 30 minutes and note: cool, warm or hot.
3. **Battery and 30 vs 60 (your phone).**
   1. Start at 100 percent. Frame rate 60, play 30 minutes, note the battery percentage at the end.
   2. Another day, same start: Frame rate 30, same 30 minutes, note the percentage.
   3. Note also whether 30 looked choppy on the map.
4. **Three full seasons by you** (the exit rule asks 3 by you, 5 in total). Play each season to the end, including the playoffs
   and the start of the next season. Note any crash, freeze, lost save, or a screen you did not understand. After each season copy
   the feedback note: it carries the pace log (how long games took; target about 5 minutes including the draft).
5. **Two more full seasons by testers** (any phones), so that 5 seasons in total are played on phones without a crash.
6. **One first-time player.** Give the APK to someone who has never seen the game. Do not help or explain. Watch them play the
   first game and, if possible, a whole first season. Note every place they got stuck or asked a question, and whether they could
   say why they lost a match from the result screen.
7. **A second phone and a low-end phone.** Install on two other Android phones, one of them low-end (about 3 GB of memory or less,
   or more than about 4 years old). On each: does it install, does it start in under about 10 seconds, play one match, note the
   phone model and any stutter or heat. (Phone model and Android version go in the feedback form.)
8. **Island or gate scores (testers).** In about one game in five the winner loses the last fight and still wins. Ask each tester
   to play some games with Settings > "Testers: last fight at the gate" off (island, the default) and some with it on (gate), and
   score how fair each ending felt, 1 to 5. These scores decide the default ending and the kill-rate retune (both deliberately
   unchanged until then).
9. **Release key and distribution: your decisions.**
   1. Choose the route for outside testers: Google Play Console closed testing (needs a Play developer account, a one-time fee,
      and a store listing), or direct APK by message as now.
   2. Create a release signing key and keep it safe (two copies, offline): it can never be replaced once the app is in the store.
      The debug key in the repo must never ship. Tell us when it exists; we switch the export to it without the key entering the
      repository.
   3. Run the feedback form script once in your Google account (`docs/ALPHA-FEEDBACK-FORM.md`, about 1 minute) and send testers
      the form link with `docs/TESTER-PACK.md` and the APK.
10. **Trademark search and name checks.**
    1. Search "Gloamline" in the trademark registers where you will publish (for example IPOS for Singapore, USPTO, EUIPO, WIPO
       Global Brand Database), in the classes for games (class 9 and 41).
    2. Search Google Play and the App Store for "Gloamline" and close spellings.
    3. Do the same quick store and web search for the names still marked Watch in `docs/design/IP-RISK-LOG.md` (Wrenfell, Orlund,
       Tarskel, Moonhulk, Mossback). Before a public release, show the results to an IP lawyer.
    4. One person who has seen ESMO should hold its map next to `docs/design/art/arena-map-preview.png` and confirm they do not
       look alike (IP-RISK-LOG section G).

When 1 to 8 are done and reported, and you have decided 9 and 10, the Alpha exit checklist can be signed.
