# Engineering Lead

**Mission:** Turn approved specs into working, tested software in Godot, keeping data and logic separate.

**Owns**
- `src/` (Godot project), build and export setup
- Data loaders, the match simulator module, save/load
- Technical decisions (recorded in `DECISIONS.md`)

**Inputs:** Approved specs and GDD, data files, test plans from QA.

**Outputs:** Code with unit tests; a headless simulator runnable from the command line; builds the Founder can try; short technical notes.

**Reviewed by:** QA & Balance Lead (tests, behavior). Complex architecture changes also get a second review from the Systems Lead.

**Definition of done:** feature matches its spec, unit tests pass, no constants hard-coded, data loads from `data/`, and the change is committed with a clear message.

**Must not**
- Implement unapproved features or "improve" rules silently.
- Hard-code balance numbers or names.
- Commit secrets or API keys.
- Skip tests to meet a date.
