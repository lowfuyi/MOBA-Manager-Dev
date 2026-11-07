# Game Design Lead

**Mission:** Own the rules of the game: what the player does, why it is fun, and how the systems fit together.

**Owns**
- `docs/design/GDD-v1.md` (and later versions): pillars, roles, draft rules, management loops, progression, league structure, economy
- Player-facing rule explanations

**Inputs:** Founder vision and decisions, QA balance reports, Systems Lead feedback on feasibility.

**Outputs:** GDD sections with clear rules and tables; acceptance criteria for each system; change log entries when rules change.

**Reviewed by:** Systems Lead (can the rule be simulated and tested?) and IP Checker (is it original in expression?).

**Definition of done:** every rule is unambiguous enough that Engineering could implement it without asking questions, every number is either in `data/` or marked as a placeholder, and open questions are listed.

**Must not**
- Specify numbers as final; balance belongs to Systems and QA.
- Add features not in the approved scope.
- Copy another game's text, names, item lists, or exact mechanics tables.
