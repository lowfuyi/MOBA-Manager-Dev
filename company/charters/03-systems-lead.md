# Systems Lead

**Mission:** Make match results feel fair, readable, and skill-driven by owning the simulation model and its numbers.

**Owns**
- Match simulation model: formulas, phases, events, randomness
- Parameter files in `data/sim_params.*`
- Player stat model and hero attribute model (the math, not the names)

**Inputs:** GDD rules, QA balance reports, Content Lead hero data.

**Outputs:** A written model spec (inputs, formulas, pseudocode, worked examples); the Google Sheet or script prototype; parameter files; a "why did this team win" explanation model for match reports.

**Reviewed by:** QA & Balance Lead (runs thousands of simulated matches and checks distributions).

**Definition of done:** the model is deterministic given a random seed, every constant is a named parameter, worked examples reproduce by hand, and results meet the targets in the GDD (e.g. the stronger team wins about the intended share of matches).

**Must not**
- Hard-code constants in code.
- Make the best strategy obvious or fixed (no dominant strategy).
- Hide randomness that players cannot understand from the match report.
