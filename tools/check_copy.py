"""Copy lint for player-facing strings (Narrative Designer's checks, saved as a repo tool).

Usage:
    python3 tools/check_copy.py                      # the Alpha 0.7 patch, docs/design/copy/en_0_7.json
    python3 tools/check_copy.py game/i18n/en.json    # the merged string table
    python3 tools/check_copy.py FILE [FILE ...] [--context game/i18n/en.json] [--expect-keys N]
Exit code 0 = no errors (warnings may print), 1 = at least one error.

What it checks (all on string VALUES; key names and id lists are never scanned for words):
  1. file loads, no duplicate keys, ASCII only (a font gap would show as a blank box)
  2. word limits by key class (RULES below: coach text 25, lesson 25, glossary definition 22,
     help line 20, switch banner 4, track end label 3 words and 14 characters)
  3. colour words (COLOUR_RE). Allow-list: ALLOW_COLOUR, key pattern -> the only words it may use
  4. rename (Producer ruling, TUTORIAL.md 13): the helper is "Coach", the player is "Manager".
     Flags advisor, assistant, owner, "the coach" in lower case, "you are the Coach", "AI helper"
  5. gendered pronouns (he, his, him, she, her)
  6. labels a text tells you to tap ("Tap Start draft") exist as strings in the table
  7. glossary ids: every id in help.<sheet>.terms has gl.<id>.name, .def, .where; every
     gl.<id>.where names a help sheet that has a title
  8. placeholders: a key that replaces an existing key in --context keeps the same {placeholders}
  9. optional --expect-keys N: the file has exactly N keys

Known, still-open problems in strings that are not in the patch are listed in KNOWN_OPEN and print
as warnings, never errors. Remove an entry when the string is fixed.
"""
import argparse, json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PATCH = ROOT / "docs/design/copy/en_0_7.json"
EN = ROOT / "game/i18n/en.json"

# ---- 2. word limits: (key regex, class name, max words, max characters or None). First match wins.
RULES = [
    (r"^tut\.", "COACH", 25, None),
    (r"^les\.l\d+\.", "LESSON", 25, None),
    (r"^gl\..+\.def$", "GLOSS", 22, None),
    (r"^help\.[a-z]+\.(see|do|know)$", "HELP", 20, None),
    (r"^gp\.switch\.short\.", "BANNER", 4, None),
    (r"^gp\.end\.", "END", 3, 14),
]
CLUB_WORDS = 2          # a {club} placeholder counts as two words (a club name is usually two)

# ---- 3. colour words. Colour must never carry meaning (colour-blind mode swaps green and red).
COLOUR_RE = re.compile(
    r"\b(green|red|blue|orange|yellow|purple|violet|pink|teal|coral|amber|grey|gray|cyan|magenta)(er|est|ish)?\b",
    re.I)
# Legitimate cases: key regex -> the only colour words that key may contain (lower case).
ALLOW_COLOUR = [
    (r"^(draft|hub)\.side\.(blue|red)$", {"blue", "red"}),        # the two side names, shown beside a flag
    (r"^settings\.colorblind(_hint)?$", {"green", "red", "blue", "orange"}),   # they describe the setting itself
]

# ---- 4. rename: (regex, message). Case-sensitive unless the pattern sets (?i).
RENAME = [
    (re.compile(r"\badvis[eo]rs?\b", re.I), "says advisor: the helper is Coach"),
    (re.compile(r"\bassistants?\b", re.I), "says assistant: the helper is Coach"),
    (re.compile(r"\bowners?\b", re.I), "says owner: the player is the Manager"),
    (re.compile(r"\bcoach(?:'s|es)?\b"), "lower-case coach: the helper is Coach (capital C), the player is never a coach"),
    (re.compile(r"\byou are (?:the |a )?(?:head )?coach\b", re.I), "calls the player a coach: the player is the Manager"),
    (re.compile(r"\bAI (?:helper|assistant|coach|advisor)\b", re.I), "calls the helper AI: it is Coach"),
]
# ---- 5. pronouns
PRONOUN_RE = re.compile(r"\b(he|his|him|himself|she|her|hers|herself)\b", re.I)

# Values that are ids (data, not text): never scanned for words.
DATA_KEYS = re.compile(r"^(help\.[a-z]+\.terms|gl\..+\.where)$")

# Open problems in strings outside the patch (COPY-0.7.md 6.4). Warnings only.
KNOWN_OPEN = {
    "chem.pentagon_hint": "colour-only cue (Greener line); needs a non-colour cue first",
    "tip.hub": "says Tap Play but the button reads 'Play game'; the key is retired when Home is rebuilt (COPY-0.7.md 6.3)",
    **{k: "gendered pronoun in an existing string (COPY-0.7.md 6.4)" for k in (
        "chem.bench_hint", "neg.asking", "neg.block.locked", "neg.pv.bench", "neg.pv.h_sign",
        "release.block.unknown", "release.confirm", "release.yes", "season.contracts_hint",
        "stat.help.mec", "stat.help.pot", "train.squad_h")},
}

# Labels a text may tell you to tap that are not strings in en.json (none yet). Case-insensitive.
LABEL_ALLOW = set()

TAP_RE = re.compile(r"\b[Tt]ap ([A-Z+?][^.,;:!]*)")
QUOTE_RE = re.compile(r'"([^"]+)"')
LABEL_STOP = re.compile(r"\s+(?:or|then|to|and|on|in|for|until|when|if|so|before|after)\s+.*$")


def load_unique(path):
    def hook(pairs):
        keys = [k for k, _ in pairs]
        dups = sorted({k for k in keys if keys.count(k) > 1})
        if dups:
            raise ValueError(f"{path}: duplicate keys {dups}")
        return dict(pairs)
    return json.loads(pathlib.Path(path).read_text(encoding="utf-8"), object_pairs_hook=hook)


def word_count(text):
    return len(text.split()) + text.count("{club}") * (CLUB_WORDS - 1)


def colour_allowed(key, word):
    return any(re.search(p, key) and word in ok for p, ok in ALLOW_COLOUR)


def label_candidates(text):
    """Labels the text names: the words after 'Tap' when they start with a capital, and quoted phrases."""
    out = []
    for m in TAP_RE.finditer(text):
        cand = LABEL_STOP.sub("", m.group(1)).strip()
        if cand:
            out.append(cand)
    out += [m.group(1).strip() for m in QUOTE_RE.finditer(text)]
    return out


def check(subject, context=None):
    """subject: {key: text} being checked. context: {key: text} already in the game (may be empty).
    Returns (errors, warnings), lists of strings."""
    errs, warns = [], []
    context = context or {}
    table = {**context, **subject}                        # what the game will hold after the merge
    lookup = {v.strip().lower() for v in table.values()} | {s.lower() for s in LABEL_ALLOW}

    def problem(key, msg):
        (warns if key in KNOWN_OPEN else errs).append(f"{key}: {msg}" + (f" [known: {KNOWN_OPEN[key]}]" if key in KNOWN_OPEN else ""))

    for key, text in subject.items():
        if not isinstance(text, str):
            errs.append(f"{key}: value is not a string")
            continue
        try:
            text.encode("ascii")
        except UnicodeEncodeError:
            problem(key, "non-ASCII character (the font may not have it)")
        if DATA_KEYS.match(key):                          # ids: no word checks
            continue
        for pat, cls, max_w, max_c in RULES:
            if re.search(pat, key):
                n = word_count(text)
                if n > max_w:
                    problem(key, f"{cls} text has {n} words, limit {max_w}")
                if max_c and len(text) > max_c:
                    problem(key, f"{cls} text has {len(text)} characters, limit {max_c}")
                break
        for m in COLOUR_RE.finditer(text):
            if not colour_allowed(key, m.group(0).lower()):
                problem(key, f"colour word '{m.group(0)}'")
        for rx, msg in RENAME:
            m = rx.search(text)
            if m:
                problem(key, f"'{m.group(0)}' {msg}")
        m = PRONOUN_RE.search(text)
        if m:
            problem(key, f"gendered pronoun '{m.group(0)}'")
        for cand in label_candidates(text):
            if cand.lower() in lookup or cand.lower().rstrip("s") in lookup:
                continue
            if cand[0].islower():                         # "Tap any hero": not a label
                continue
            if cand.lower().split(" ", 1)[0] in {"a", "an", "the", "any", "your", "it", "each", "one", "that", "this", "its"}:
                continue
            problem(key, f"label '{cand}' is not a string in the table (add it to LABEL_ALLOW if it is drawn by code)")

    # 7. glossary ids
    for key, text in subject.items():
        m = re.match(r"^help\.([a-z]+)\.terms$", key)
        if m:
            for gid in [t.strip() for t in text.split(",") if t.strip()]:
                for part in ("name", "def", "where"):
                    if f"gl.{gid}.{part}" not in table:
                        errs.append(f"{key}: glossary id '{gid}' has no gl.{gid}.{part}")
        if re.match(r"^gl\..+\.where$", key):
            sheet = text.strip()
            if f"help.{sheet}.title" not in table:
                errs.append(f"{key}: '{sheet}' is not a help sheet (no help.{sheet}.title)")
    # a term that is defined but has no name or def is a half-written term
    ids = {k.split(".")[1] for k in subject if re.match(r"^gl\.[a-z_]+\.(name|def|where)$", k)}
    for gid in sorted(ids):
        for part in ("name", "def", "where"):
            if f"gl.{gid}.{part}" not in table:
                errs.append(f"gl.{gid}.{part}: missing (term is half written)")

    # 8. placeholders unchanged on replaced keys
    ph = re.compile(r"\{(\w+)\}")
    for key, text in subject.items():
        if key in context and set(ph.findall(context[key])) != set(ph.findall(text)):
            errs.append(f"{key}: placeholders changed from {sorted(set(ph.findall(context[key])))} to {sorted(set(ph.findall(text)))}")
    return errs, warns


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="*", help="string files to check (default: the Alpha 0.7 patch)")
    ap.add_argument("--context", default=str(EN), help="string table already in the game (default game/i18n/en.json)")
    ap.add_argument("--expect-keys", type=int, default=None, help="the (single) file must have exactly this many keys")
    args = ap.parse_args(argv)
    files = [pathlib.Path(f) for f in args.files] or [PATCH]
    ctx_path = pathlib.Path(args.context)
    total_errs = 0
    for f in files:
        try:
            subject = load_unique(f)
            # checking the table against itself: no context, or every key would be a "replacement"
            context = {} if f.resolve() == ctx_path.resolve() else load_unique(ctx_path)
        except (ValueError, OSError, json.JSONDecodeError) as e:
            print(f"ERROR {e}")
            total_errs += 1
            continue
        errs, warns = check(subject, context)
        if args.expect_keys is not None and len(subject) != args.expect_keys:
            errs.append(f"{f.name}: {len(subject)} keys, expected {args.expect_keys}")
        for w in warns:
            print("warn  " + w)
        for e in errs:
            print("ERROR " + e)
        print(f"{f}: {len(subject)} keys, {len(errs)} errors, {len(warns)} warnings")
        total_errs += len(errs)
    print("copy OK" if total_errs == 0 else "copy FAILED")
    return 1 if total_errs else 0


if __name__ == "__main__":
    sys.exit(main())
