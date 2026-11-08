#!/usr/bin/env python3
"""Colour checks quoted in docs/design/ART-BIBLE.md (pass 2b). Needs numpy only.
Run: python3 -I docs/design/art/tools/colour_checks.py
WCAG 2.x contrast; colour-blind simulation = Machado 2009 matrices at full severity on linear RGB;
distance = CIE76 dE in Lab (D65). These are approximations, not a lab test (tolerance about 1)."""
import itertools
import numpy as np

def hx(h): h = h.lstrip('#'); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
def lin(c):
    c = np.asarray(c, float) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
def delin(l):
    l = np.clip(l, 0, 1)
    return np.where(l <= 0.0031308, l * 12.92, 1.055 * l ** (1 / 2.4) - 0.055) * 255
def lum(h): r, g, b = lin(hx(h)); return 0.2126 * r + 0.7152 * g + 0.0722 * b
def cr(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True); return (la + 0.05) / (lb + 0.05)
def mix(a, b, t):
    A, B = np.array(hx(a), float), np.array(hx(b), float); C = A * (1 - t) + B * t
    return '#%02X%02X%02X' % tuple(int(x + 0.5) for x in C)
def lab(rgb):
    M = np.array([[0.4124564, 0.3575761, 0.1804375], [0.2126729, 0.7151522, 0.0721750], [0.0193339, 0.1191920, 0.9503041]])
    xyz = M @ lin(rgb) / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 216 / 24389, np.cbrt(xyz), (24389 / 27 * xyz + 16) / 116)
    return np.array([116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])])
CVD = {'prot': [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]],
       'deut': [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]],
       'trit': [[1.255528, -0.076749, -0.178779], [-0.078411, 0.930809, 0.147602], [0.004733, 0.691367, 0.303900]]}
def sim(h, k): return hx(h) if k == 'norm' else delin(np.array(CVD[k]) @ lin(hx(h)))
def de(a, b, k='norm'): return float(np.linalg.norm(lab(sim(a, k)) - lab(sim(b, k))))
def de4(a, b): return tuple(round(de(a, b, k), 1) for k in ('norm', 'prot', 'deut', 'trit'))

T = dict(BG='#0A1120', VOID='#070D1A', PANEL='#162842', PANEL2='#223A5E', PANEL3='#30507F', TEXT='#EAF0F7', TEXT2='#B9C8DA',
         DIM='#96AAC4', ACCENT='#3FD0B8', TEAL_HI='#7BE3D2', CORAL='#FF8A5C', WARN='#F2C14E', BAD='#F58080', GOOD='#5BD68A',
         GOOD_CB='#7FD0FF', BAD_CB='#F2924A', SIDE_BLUE='#5AA9FF', OLD_SIDE_RED='#FF7A7A', MAP_LAND='#173629', MAP_MERE='#0E3550',
         MAP_SHORE='#2F7F8F', INK_TEAL='#04120F', INK_CORAL='#1C0B04', JUNGLE='#B7F797', TOP='#9797F7', MID='#68DCF3',
         BOT='#EFD139', SUP='#F36896')
CLUBS = {'duskwater_foxes': '#BC8FEA', 'emberfen_hounds': '#DA9160', 'gildmoor_raiders': '#82A520', 'ironquill_wolves': '#1AAF7D',
         'mossgate_wardens': '#20A4D5', 'northreach_corsairs': '#22B035', 'pinehollow_owls': '#AF8C29', 'saltmarrow_gulls': '#4886E4',
         'stormvale_herons': '#E57B74', 'thornwick_stags': '#DC6B95'}

def main():
    print('== reproduce pass-2 numbers (expect 97/29/6, 94/77/88/96, 47.3/29.9/29.2/28.4, 12.9)')
    print('GOOD/BAD', de4(T['GOOD'], T['BAD']), ' GOOD_CB/BAD_CB', de4(T['GOOD_CB'], T['BAD_CB']))
    roles = [T[k] for k in ('TOP', 'JUNGLE', 'MID', 'BOT', 'SUP')]
    print('role min dE', [round(min(de(a, b, k) for a, b in itertools.combinations(roles, 2)), 1) for k in ('norm', 'prot', 'deut', 'trit')],
          ' TEXT on PANEL', round(cr(T['TEXT'], T['PANEL']), 1))
    print('\n== 3.8 sides: teal vs coral and neighbours (normal, protan, deutan, tritan)')
    for n, (a, b) in {'teal/coral': ('ACCENT', 'CORAL'), 'coral/BAD': ('CORAL', 'BAD'), 'coral/BAD_CB': ('CORAL', 'BAD_CB'),
                      'teal/GOOD_CB': ('ACCENT', 'GOOD_CB'), 'BAD/old SIDE_RED': ('BAD', 'OLD_SIDE_RED')}.items():
        print('%-18s' % n, de4(T[a], T[b]))
    print('teal/coral luminance', round(lum(T['ACCENT']), 3), round(lum(T['CORAL']), 3), 'ratio', round(cr(T['ACCENT'], T['CORAL']), 2))
    print('\n== token fill contrast on map surfaces (flat fills; need 3:1)')
    for s in ('MAP_LAND', 'PANEL3', 'PANEL2', 'MAP_MERE', 'MAP_SHORE'):
        print('%-10s teal %.1f coral %.1f' % (s, cr(T['ACCENT'], T[s]), cr(T['CORAL'], T[s])))
    print('ink on flat fills: INK_TEAL %.1f INK_CORAL %.1f' % (cr(T['INK_TEAL'], T['ACCENT']), cr(T['INK_CORAL'], T['CORAL'])))
    print('\n== 3.9 merges (dE normal, protan, deutan, tritan)')
    for n, (a, b) in {'moon lilac/TEXT2': ('#B9C6FF', T['TEXT2']), 'moon lilac/MID ring': ('#B9C6FF', T['MID']), 'moss/JUNGLE': ('#8FCF7A', T['JUNGLE']),
                      'JUNGLE/GOOD': (T['JUNGLE'], T['GOOD']), 'bramble/coral': ('#E0A35A', T['CORAL']), 'WARN/coral': (T['WARN'], T['CORAL']),
                      'old lane/PANEL3': ('#2C4A70', T['PANEL3']), 'plaza/PANEL2': ('#1E3556', T['PANEL2'])}.items():
        print('%-20s' % n, de4(a, b))
    print('\n== 3.7 club wash: 10 percent of the club primary over BG_GLOW #14284A')
    for k, c in CLUBS.items():
        w = mix('#14284A', c, 0.10)
        print('%-20s wash %s  TEXT %.1f TEXT2 %.1f DIM %.1f | full-strength TEXT %.1f | badge vs wash %.1f' % (
            k, w, cr(T['TEXT'], w), cr(T['TEXT2'], w), cr(T['DIM'], w), cr(T['TEXT'], c), cr(c, w)))

if __name__ == '__main__':
    main()
