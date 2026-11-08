#!/usr/bin/env python3
"""Merge a Narrative copy patch into game/i18n/en.json (build plan I-00; one-off per patch).

    python3 tools/merge_copy.py                    # dry run: report only, writes nothing
    python3 tools/merge_copy.py --write            # write game/i18n/en.json
    python3 tools/merge_copy.py --write --expect-total 536 --expect-replaced 12 --expect-new 524 --expect-held 4

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
"""
import argparse, json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PLACE = re.compile(r"\{(\w+)\}")


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
        if k not in patch:
            errs.append(f"hold list names {k}, which is not in the patch")
    if errs:
        raise ValueError("\n".join(errs))
    held = [k for k in patch if k in hold]
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


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--en", default=str(ROOT / "game/i18n/en.json"))
    ap.add_argument("--patch", default=str(ROOT / "docs/design/copy/en_0_7.json"))
    ap.add_argument("--hold", default=str(ROOT / "docs/design/copy/hold_0_7.json"))
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--expect-total", type=int, help="keys taken from the patch (patch size minus held)")
    ap.add_argument("--expect-replaced", type=int)
    ap.add_argument("--expect-new", type=int)
    ap.add_argument("--expect-held", type=int)
    a = ap.parse_args()
    en_path, patch_path, hold_path = pathlib.Path(a.en), pathlib.Path(a.patch), pathlib.Path(a.hold)
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
    if a.write:
        en_path.write_text(json.dumps(merged, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(f"written: {en_path}")
    else:
        print("dry run: nothing written (use --write)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
