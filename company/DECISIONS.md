# Decisions log

## Decided

| Date | Decision | Decided by |
|---|---|---|
| 2026-11-07 | Game is MOBA-only (no other esports genres) | Founder |
| 2026-11-07 | Copy genre logic (roles, lanes, jungle, objectives, draft); invent all names, art, heroes, items | Founder |
| 2026-11-07 | Visual design for characters and items is postponed to the pre-launch phase | Founder |
| 2026-11-07 | Engine: Godot (provisional, revisit at P-001) | Producer, pending Founder |
| 2026-11-07 | Single player (offline, local device) is the first release; online comes in later updates | Founder |
| 2026-11-07 | Match presentation: text and event feed first; animated map is the end goal | Founder |
| 2026-11-07 | Setting: fantasy-lite; may change and develop later | Founder |
| 2026-11-07 | Monetization: tiered monthly or annual subscriptions (Basic, Pro+, Esports, our own version), modelled loosely on the reference game's tier structure. Postponed until the final game release; nothing is built in Phase 1 | Founder |
| 2026-11-07 | Release path and naming: the game's edition name changes with the update phase (see below) | Founder |
| 2026-11-07 | Platform: Android first; iOS only when demand grows | Founder |
| 2026-11-07 | Language: English for testing; more languages added at the live release (all text must be kept in translatable string tables from day one) | Founder |
| 2026-11-07 | Game Plan (small version: about 8 sliders, default plan, "ahead" and "behind" triggers) is in Phase 1 | Founder |
| 2026-11-07 | Team Bonds (pairwise Bond and Understanding, languages data field) is in Phase 1 | Founder |
| 2026-11-07 | Proposed by Producer, proceeding unless the Founder objects: turn-based calendar; free agents only in Phase 1; sponsor "lite" plus tutorial goals; finances screens; manager talents deferred (see REFERENCE-ESMO-ADAPTATION.md section 8 and decisions 4 to 8) | Producer (pending Founder) |
| 2026-11-07 | Proposed by Producer, proceeding unless the Founder objects: keep the 6 core player stats; Potential becomes per stat; stat help sheets, mastery levels, derived KDA, career log; contract expiry reminders always free (see REFERENCE-ESMO-ADAPTATION.md section 9) | Producer (pending Founder) |
| 2026-11-07 | Proposed by Producer, proceeding unless the Founder objects: Form Rating (28-day fade, importance-weighted) and a trophy cabinet in Phase 1; multi-tier leagues, cups and region leaderboards wait for Global (see REFERENCE-ESMO-ADAPTATION.md section 10) | Producer (pending Founder) |

## Release path (Founder, 2026-11-07)

| Phase | Edition | What it adds |
|---|---|---|
| Single Player | MOBA Esports: Single Player | Offline play on the local device |
| Multiplayer | MOBA Esports: Multiplayer | Internet multiplayer hosting and matching, friends, sale and transfer of players |
| Global | MOBA Esports: Global | Game seasons, regional tournaments, mid-season invitationals, a World Cup |

"MOBA Esports" is the working title only. A distinctive final name still needs a trademark and store search (see IP-RISK-LOG).

## Still open

1. **Final game name.** Working title: "MOBA Esports" with the edition suffixes above. Needs a name search before launch.
2. **Monetization details.** Reference images received; concept drafted in `docs/design/MONETIZATION-DRAFT.md`. Postponed until the final release.
3. **Transfers with AI clubs in Single Player.** The release path puts sale and transfer of players in the Multiplayer edition. Should a later Single Player update also allow transfers with AI-run clubs? Recommendation: not in Phase 1; decide after the core loop is balanced.
4. **Ads in the Single Player edition.** Still open (see MONETIZATION-DRAFT.md).
5. **Competition geography for the Global edition.** Real regions or fictional realms (fantasy-lite)? Not needed until the Global edition.
