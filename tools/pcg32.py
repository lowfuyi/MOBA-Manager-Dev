"""Reference implementation of the game's random number generator (task P-002 spec, GDD 8.4).

This is the source of truth for the golden test vectors. The Godot module
(game/src/core/pcg32.gd) must reproduce the vectors in
game/tests/golden/rng_vectors.json.

Design:
- PCG32 (XSH-RR variant) by M. E. O'Neill, 64-bit state.
- Floats use the top 24 bits of a draw, so every value is exactly representable.
- Normal draws use Box-Muller and consume exactly two uniform draws each
  (no cached second value), so substream positions are easy to reason about.
- Every contest gets its own named substream derived from the match seed.
"""
import math

MASK64 = (1 << 64) - 1
MASK32 = 0xFFFFFFFF
MULT = 6364136223846793005
FNV_OFFSET = 0xCBF29CE484222325
FNV_PRIME = 0x100000001B3


class Pcg32:
    def __init__(self, initstate: int, initseq: int):
        self.state = 0
        self.inc = ((initseq << 1) | 1) & MASK64
        self.next_u32()
        self.state = (self.state + initstate) & MASK64
        self.next_u32()

    def next_u32(self) -> int:
        old = self.state
        self.state = (old * MULT + self.inc) & MASK64
        xorshifted = (((old >> 18) ^ old) >> 27) & MASK32
        rot = old >> 59
        return ((xorshifted >> rot) | (xorshifted << ((-rot) & 31))) & MASK32

    def next_float(self) -> float:
        """Uniform in [0, 1), 24 bits of resolution."""
        return (self.next_u32() >> 8) / 16777216.0

    def next_normal(self, mean: float = 0.0, sd: float = 1.0) -> float:
        """Box-Muller; consumes exactly two uniform draws."""
        u1 = 1.0 - self.next_float()  # in (0, 1], so log() is finite
        u2 = self.next_float()
        return mean + sd * math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)


def fnv1a64(text: str) -> int:
    h = FNV_OFFSET
    for b in text.encode("utf-8"):
        h = ((h ^ b) * FNV_PRIME) & MASK64
    return h


def splitmix64(x: int) -> int:
    x = (x + 0x9E3779B97F4A7C15) & MASK64
    z = x
    z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & MASK64
    z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & MASK64
    return z ^ (z >> 31)


def match_seed(save_seed: int, match_id: str) -> int:
    """Fixed when the match is generated, before the draft."""
    return splitmix64((save_seed ^ fnv1a64(match_id)) & MASK64)


def contest_stream(seed_of_match: int, contest_id: str) -> Pcg32:
    """Each contest draws from its own named substream, so replaying a match
    with a changed input reuses the same noise (exact counterfactuals)."""
    name_hash = fnv1a64(contest_id)
    return Pcg32(splitmix64((seed_of_match ^ name_hash) & MASK64), name_hash)
