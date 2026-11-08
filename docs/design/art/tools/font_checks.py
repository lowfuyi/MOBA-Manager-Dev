#!/usr/bin/env python3
"""Font facts and string widths quoted in docs/design/ART-BIBLE.md 5.1 and 5.2 (pass 2b).
Needs fontTools and Pillow. Run: python3 -I docs/design/art/tools/font_checks.py <folder with BarlowSemiCondensed-*.ttf and OFL.txt>
The font files are NOT in the repo (they were downloaded from the public Google Fonts repository to measure them)."""
import hashlib, os, sys
from fontTools.ttLib import TTFont
from PIL import ImageFont

def main(d):
    f = lambda w: os.path.join(d, 'BarlowSemiCondensed-%s.ttf' % w)
    for w in ('Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'):
        print('%-10s %7d bytes  sha256 %s' % (w, os.path.getsize(f(w)), hashlib.sha256(open(f(w), 'rb').read()).hexdigest()[:16]))
    ofl = os.path.join(d, 'OFL.txt')
    if os.path.exists(ofl):
        print('OFL.txt', hashlib.sha256(open(ofl, 'rb').read()).hexdigest()[:16], 'Reserved Font Name lines:',
              [l.strip() for l in open(ofl, encoding='utf-8') if 'Reserved Font Name' in l][:3])
    t = TTFont(f('Regular')); nm = t['name']
    for i in (0, 5, 9, 13, 14):
        r = nm.getName(i, 3, 1, 0x409); print('name', i, r.toUnicode()[:160] if r else None)
    cmap = t.getBestCmap(); hm = t['hmtx']
    gsub = t['GSUB'].table
    print('GSUB features:', sorted({x.FeatureTag for x in gsub.FeatureList.FeatureRecord}))
    print('digit advances (default):', [hm[cmap[ord(c)]][0] for c in '0123456789'])
    cov = lambda lo, hi: '%d/%d' % (sum(1 for c in range(lo, hi + 1) if c in cmap), hi - lo + 1)
    print('coverage: Latin', cov(0x20, 0x7e), 'Latin-1', cov(0xa0, 0xff), 'Ext-A', cov(0x100, 0x17f), 'Vietnamese', cov(0x1ea0, 0x1ef9),
          'Greek', cov(0x370, 0x3ff), 'Cyrillic', cov(0x400, 0x4ff))
    syms = {'up U+2191': 0x2191, 'down U+2193': 0x2193, 'tri up U+25B2': 0x25B2, 'tri down U+25BC': 0x25BC, 'tick U+2713': 0x2713,
            'cross U+2717': 0x2717, 'star U+2605': 0x2605, 'right U+2192': 0x2192, 'minus U+2212': 0x2212, 'times U+00D7': 0xD7, 'bullet U+2022': 0x2022}
    print('symbols present:', {k: (v in cmap) for k, v in syms.items()})
    def w(text, size, weight='Regular', ls=0.0):
        return ImageFont.truetype(f(weight), size).getlength(text) + ls * size * (len(text) - 1)
    rows = [('Display 64 ExtraBold', 'Season complete', 64, 'ExtraBold', 0, 530), ('Display 64 ExtraBold', '15  -  24', 64, 'ExtraBold', 0, 200),
            ('Title 48 Bold', 'Northreach Corsairs', 48, 'Bold', 0, 466), ('Screen 40 Bold', 'Why this happened', 40, 'Bold', 0, 362),
            ('Screen 40 Bold', 'Your turn: ban', 40, 'Bold', 0, 260), ('Screen 40 Bold', 'YOUR TURN: BAN', 40, 'Bold', 0, 260),
            ('Heading 36 SemiBold', 'Northreach Corsairs', 36, 'SemiBold', 0, 530), ('Body 32', 'Northreach Corsairs', 32, 'Regular', 0, 298),
            ('Segmented 32', 'Playoffs', 32, 'SemiBold', 0, 160), ('Small 26', 'Gravenstone', 26, 'SemiBold', 0, 160),
            ('Caption 24', '+0.9% chemistry', 24, 'SemiBold', 0, 260), ('Section label 24 +8%', 'REINFORCEMENTS (FREE AGENTS)', 24, 'SemiBold', 0.08, 400),
            ('Map label 24 Bold +1.5px', 'STONEBACK', 24, 'Bold', 0.0625, 200), ('Map label 24 Bold +1.5px', 'MOONHULK', 24, 'Bold', 0.0625, 200)]
    print('\nwidths (px at design size) against the room I assumed (large-text case):')
    for n, s, size, wt, ls, room in rows:
        x = w(s, size, wt, ls); print('%-26s %-30s %4.0f  room %3d  %s' % (n, s, x, room, 'fits' if x <= room else 'DOES NOT FIT'))

if __name__ == '__main__':
    if len(sys.argv) != 2: sys.exit(__doc__)
    main(sys.argv[1])
