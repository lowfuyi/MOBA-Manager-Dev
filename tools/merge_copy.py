#!/usr/bin/env python3
"""Merge a Narrative copy patch into game/i18n/en.json (build plan I-00; one-off per patch).

    python3 tools/merge_copy.py                    # dry run: report only, writes nothing
    python3 tools/merge_copy.py --write            # write game/i18n/en.json
    python3 tools/merge_copy.py --write --expect-total 536 --expect-replaced 12 --expect-new 524 --expect-held 4
    python3 tools/merge_copy.py --patch P.json --write           # add mode for a later patch (P.json may re-state old keys)

    python3 tools/merge_copy.py --update FILE.json               # UPDATE MODE, dry run: table of key, old text, new text
    python3 tools/merge_copy.py --update FILE.json --write       # write game/i18n/en.json
    python3 tools/merge_copy.py --seed-owned [--write]           # once: own every merged, non-held key of --patch

Rules
  * Refuses (exit 1, nothing written) when a file has a duplicate key, the patch has a non-ASCII character,
    a patch value is not a string, a replaced key changes its {placeholders}, or the patch has nothing new to
    say (every key already present with the same text: the patch was already merged).
  * A patch key that already exists in en.json with different text is a REPLACEMENT. It is listed with old and new
    text. A key that exists with the same text is "unchanged" (listed as a count).
  * HOLD list (docs/design/copy/hold_0_7.json): keys named there are NOT merged yet (old text stays, or, for a key
    that is not in en.json yet, it is not added). Each entry says which build step releases it. Release a key by
    deleting it from the hold file in that step and running this script again with --write.
  * New keys are appended after the existing ones, grouped by prefix (first dotted segment, stable order).
  * Keys are never deleted: retiring old keys is a later step (COPY-0.7 section 6.3, after the code stops using them).
  * Add mode also writes every key it takes from the patch into the allow-list docs/design/copy/owned_keys.txt
    (one key per line, '#' starts a comment). A hold key that is not in this patch is skipped (the hold file is shared
    by several patches); it is an error only when it is in neither the patch nor en.json.
  * Before ANY write (add or update) tools/check_copy.py check() runs on the whole result; one error stops the write.
    Then tools/check_strings.py runs on a scratch copy of the tree holding the new table (game table only).

Update mode (COPY-0.7 section 8, route A) changes the text of existing keys, nothing else
  * FILE.json holds only the changed keys. The WHOLE file is refused (nothing written) if any key: is not in
    owned_keys.txt, is not already in en.json, is on the hold list (release it through add mode), has a non-string or
    non-ASCII value, or changes its {placeholders} (unless --allow-placeholder-change: a programmer flag, code must
    change at the same time). Keys are never added, renamed or deleted. Key order, indentation and line endings stay;
    en.json must already be in the tool's canonical format (2-space JSON, one key per line, LF) or it is refused.
  * Changing owned_keys.txt is a Producer or Lead Programmer edit, never Narrative's.
"""
import argparse, json, pathlib, re, shutil, sys, tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import check_copy, check_strings          # noqa: E402  (tools/ is a plain folder, not a package)

PLACE = re.compile(r"\{(\w+)\}")
DEFAULT_EN = ROOT / "game/i18n/en.json"
DEFAULT_OWNED = ROOT / "docs/design/copy/owned_keys.txt"


def load_unique(path):
    def hook(pairs):
        keys = [k for k, _ in pairs]
        dups = sorted({k for k in keys if keys.count(k) > 1})
        if dups:
            raise ValueError(f"{path}: duplicate keys {dups}")
        return dict(pairs)
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=hook)


def merge(en, patch, hold):
    """Returns (merged dict, report dict). Raises ValueError on a refusal."""
    errs = []
    for k, v in patch.items():
        if not isinstance(v, str):
            errs.append(f"patch value for {k} is not a string")
        elif not v.isascii() or not k.isascii():
            errs.append(f"patch key or value is not ASCII: {k}")
    for k in hold:
        if k not in patch and k not in en:
            errs.append(f"hold list names {k}, which is in neither the patch nor en.json")
    if errs:
        raise ValueError("\n".join(errs))
    held = [k for k in patch if k in hold]          # hold keys of other patches are simply not touched
    todo = {k: v for k, v in patch.items() if k not in hold}
    replaced, unchanged, new = [], [], []
    for k, v in todo.items():
        if k in en:
            if en[k] == v:
                unchanged.append(k)
            else:
                if set(PLACE.findall(en[k])) != set(PLACE.findall(v)):
                    errs.append(f"{k}: placeholders change from {sorted(set(PLACE.findall(en[k])))} to {sorted(set(PLACE.findall(v)))}")
                replaced.append(k)
        else:
            new.append(k)
    if errs:
        raise ValueError("\n".join(errs))
    if not replaced and not new:
        raise ValueError("nothing to merge: every non-held patch key is already in en.json with the same text (already merged?)")
    out = dict(en)
    for k in replaced:
        out[k] = todo[k]
    new_sorted = sorted(new, key=lambda k: k.split(".")[0])      # stable: patch order inside a prefix
    for k in new_sorted:
        out[k] = todo[k]
    return out, {"held": held, "replaced": replaced, "unchanged": unchanged, "new": new_sorted, "todo": todo}


def read_owned(path):
    """The allow-list as an ordered list of keys ('#' comments and blank lines skipped). [] when the file is missing."""
    path = pathlib.Path(path)
    if not path.exists():
        return []
    keys = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].strip()
        if line:
            keys.append(line)
    return keys


def owned_text(existing_text, add):
    """The owned file text after appending keys (kept as is, comments included, new keys at the end)."""
    text = existing_text
    if text and not text.endswith("\n"):
        text += "\n"
    return text + "".join(k + "\n" for k in add)


def update(en, upd, owned, hold=(), allow_placeholder_change=False):
    """Update mode. Returns (merged dict, list of (key, old, new)). Raises ValueError listing EVERY refusal."""
    errs = []
    owned = set(owned)
    for k, v in upd.items():
        if not isinstance(v, str):
            errs.append(f"{k}: value is not a string")
        elif not v.isascii() or not k.isascii():
            errs.append(f"{k}: key or value is not ASCII")
        if k not in owned:
            errs.append(f"{k}: not on the allow-list (owned_keys.txt); ask the Producer or Lead Programmer")
        if k not in en:
            errs.append(f"{k}: not in en.json; update mode never adds keys (use add mode)")
        if k in hold:
            errs.append(f"{k}: is on the hold list; release it through add mode")
        if k in en and isinstance(v, str) and not allow_placeholder_change \
                and set(PLACE.findall(en[k])) != set(PLACE.findall(v)):
            errs.append(f"{k}: placeholders change from {sorted(set(PLACE.findall(en[k])))} to "
                        f"{sorted(set(PLACE.findall(v)))} (needs --allow-placeholder-change and a code change)")
    if not upd:
        errs.append("update file has no keys")
    if errs:
        raise ValueError("\n".join(errs))
    changes = [(k, en[k], v) for k, v in upd.items() if en[k] != v]
    if not changes:
        raise ValueError("nothing to update: every key already has this text")
    out = dict(en)
    for k, _, v in changes:
        out[k] = v
    return out, changes


def canonical(table):
    return json.dumps(table, indent=2, ensure_ascii=False) + "\n"


def run_checks(merged, en_path):
    """check_copy.check() on the whole result (any error stops the write), then check_strings on a scratch tree.
    Returns (errors, warnings, notes)."""
    errs, warns = check_copy.check(merged, {})
    notes = []
    if pathlib.Path(en_path).resolve() == DEFAULT_EN.resolve():
        with tempfile.TemporaryDirectory() as tmp:
            g = pathlib.Path(tmp) / "game"
            (g / "i18n").mkdir(parents=True)
            for sub in ("src", "tests", "data"):
                (g / sub).symlink_to(ROOT / "game" / sub, target_is_directory=True)
            for f in (ROOT / "game/i18n").glob("*.json"):
                shutil.copy(f, g / "i18n" / f.name)
            (g / "i18n/en.json").write_text(canonical(merged), encoding="utf-8")
            s_errs, _ = check_strings.check(pathlib.Path(tmp))
            errs += [f"check_strings: {e}" for e in s_errs]
        notes.append("check_strings run on a scratch copy")
    else:
        notes.append("check_strings skipped (not game/i18n/en.json)")
    return errs, warns, notes


def finish(en_path, merged, extra_writes, write):
    """Run the checks, then write (only with --write). extra_writes: list of (path, text). Returns exit code."""
    errs, warns, notes = run_checks(merged, en_path)
    for w in warns:
        print("warn  " + w)
    if errs:
        print("REFUSED (copy check failed, nothing written):\n" + "\n".join(errs))
        return 1
    print(f"copy check: 0 errors, {len(warns)} warnings; " + "; ".join(notes))
    if write:
        pathlib.Path(en_path).write_bytes(canonical(merged).encode("utf-8"))
        print(f"written: {en_path}")
        for path, text in extra_writes:
            pathlib.Path(path).write_bytes(text.encode("utf-8"))
            print(f"written: {path}")
    else:
        print("dry run: nothing written (use --write)")
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--en", default=str(ROOT / "game/i18n/en.json"))
    ap.add_argument("--patch", default=str(ROOT / "docs/design/copy/en_0_7.json"))
    ap.add_argument("--hold", default=str(ROOT / "docs/design/copy/hold_0_7.json"))
    ap.add_argument("--owned", default=str(DEFAULT_OWNED), help="allow-list file")
    ap.add_argument("--update", metavar="FILE", help="update mode: change the text of existing owned keys")
    ap.add_argument("--allow-placeholder-change", action="store_true", help="update mode, programmer only")
    ap.add_argument("--expect-changed", type=int, help="update mode: number of keys that change")
    ap.add_argument("--seed-owned", action="store_true", help="own every non-held key of --patch that is already in en.json (once)")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--expect-total", type=int, help="keys taken from the patch (patch size minus held)")
    ap.add_argument("--expect-replaced", type=int)
    ap.add_argument("--expect-new", type=int)
    ap.add_argument("--expect-held", type=int)
    a = ap.parse_args(argv)
    en_path, patch_path, hold_path = pathlib.Path(a.en), pathlib.Path(a.patch), pathlib.Path(a.hold)
    owned_path = pathlib.Path(a.owned)
    if a.update:
        return main_update(a, en_path, hold_path, owned_path)
    if a.seed_owned:
        return main_seed(a, en_path, patch_path, hold_path, owned_path)
    try:
        en = load_unique(en_path)
        patch = load_unique(patch_path)
        hold = load_unique(hold_path) if hold_path.exists() else {}
        merged, rep = merge(en, patch, hold)
    except ValueError as e:
        print("REFUSED:\n" + str(e))
        return 1
    print(f"en.json before: {len(en)} keys; patch: {len(patch)} keys; held: {len(rep['held'])}; taken from the patch: {len(rep['todo'])}")
    print(f"new: {len(rep['new'])}; replaced: {len(rep['replaced'])}; unchanged: {len(rep['unchanged'])}; en.json after: {len(merged)} keys")
    for k in rep["held"]:
        print(f"HELD   {k}  (release in {hold[k].get('release_in', '?')}: {hold[k].get('reason', '')})")
        if k in en:
            print(f"         old text kept: {en[k][:90]!r}")
    for k in rep["replaced"]:
        print(f"REPLACED {k}\n    old: {en[k][:110]!r}\n    new: {merged[k][:110]!r}")
    bad = []
    for flag, got in (("expect_total", len(rep["todo"])), ("expect_replaced", len(rep["replaced"])),
                      ("expect_new", len(rep["new"])), ("expect_held", len(rep["held"]))):
        want = getattr(a, flag)
        if want is not None and want != got:
            bad.append(f"{flag.replace('_', '-')}: expected {want}, got {got}")
    if bad:
        print("REFUSED (expectation not met, nothing written):\n" + "\n".join(bad))
        return 1
    owned_now = read_owned(owned_path)
    to_own = [k for k in rep["todo"] if k not in owned_now]
    old_text = owned_path.read_text(encoding="utf-8") if owned_path.exists() else \
        "# Keys Narrative may change through 'merge_copy.py --update'. One key per line. Producer or Lead Programmer edits only.\n"
    print(f"allow-list: {len(to_own)} keys to add to {owned_path.name} (now {len(owned_now)})")
    return finish(en_path, merged, [(owned_path, owned_text(old_text, to_own))], a.write)


def main_update(a, en_path, hold_path, owned_path):
    try:
        raw = en_path.read_bytes().decode("utf-8")
        en = load_unique(en_path)
        if canonical(en) != raw:
            raise ValueError(f"{en_path.name} is not in canonical format (2-space JSON, LF, one key per line): "
                             "refusing, because writing it would change more than the edited values")
        upd = load_unique(pathlib.Path(a.update))
        hold = load_unique(hold_path) if hold_path.exists() else {}
        merged, changes = update(en, upd, read_owned(owned_path), hold, a.allow_placeholder_change)
    except (ValueError, OSError) as e:
        print("REFUSED (nothing written):\n" + str(e))
        return 1
    print(f"update: {len(changes)} keys change, {len(upd) - len(changes)} unchanged; en.json stays at {len(merged)} keys")
    for k, old, new in changes:
        print(f"CHANGED {k}\n    old: {old!r}\n    new: {new!r}")
    if a.expect_changed is not None and a.expect_changed != len(changes):
        print(f"REFUSED (expectation not met, nothing written): expect-changed {a.expect_changed}, got {len(changes)}")
        return 1
    return finish(en_path, merged, [], a.write)


def main_seed(a, en_path, patch_path, hold_path, owned_path):
    try:
        en = load_unique(en_path)
        patch = load_unique(patch_path)
        hold = load_unique(hold_path) if hold_path.exists() else {}
    except (ValueError, OSError) as e:
        print("REFUSED:\n" + str(e))
        return 1
    have = read_owned(owned_path)
    add = [k for k in patch if k not in hold and k in en and k not in have]
    print(f"seed-owned: {len(add)} keys to add to {owned_path.name} (now {len(have)}); held keys skipped: {len([k for k in patch if k in hold])}")
    if a.write:
        old = owned_path.read_text(encoding="utf-8") if owned_path.exists() else \
            "# Keys Narrative may change through 'merge_copy.py --update'. One key per line. Producer or Lead Programmer edits only.\n"
        owned_path.write_bytes(owned_text(old, add).encode("utf-8"))
        print(f"written: {owned_path}")
    else:
        print("dry run: nothing written (use --write)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
