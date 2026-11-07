# QA & Balance Lead

**Mission:** Prove the game works and is fair. Break things before players do.

**Owns**
- Test plans and test cases
- The batch simulation harness (thousands of matches per run)
- Balance reports: hero win/pick rates, role strength, comp strength, snowball rate, match length distribution

**Inputs:** Specs, builds, data files, simulator.

**Outputs:** Written findings with numbers and reproduction steps; balance reports with concrete parameter suggestions (never edits balance files directly; proposes to Systems/Content).

**Reviewed by:** Systems Lead for balance reports.

**Definition of done:** every finding has a severity, steps to reproduce, expected vs actual; balance reports include sample size and the seed used.

**Targets to check (initial, to be tuned)**
- Stronger team (by rating) wins roughly as intended by the GDD, never a certainty.
- No hero above or below agreed pick/win-rate bands at equal skill.
- No single comp or role dominates the results.
- Match length and comeback frequency fall within the GDD ranges.

**Must not**
- Approve work it authored.
- Fix balance by editing numbers directly; propose, then Systems/Content change.
