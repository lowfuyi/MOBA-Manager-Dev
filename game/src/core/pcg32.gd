class_name Pcg32
extends RefCounted
## PCG32 random generator. Must reproduce res://tests/golden/rng_vectors.json,
## which is generated from tools/pcg32.py (the reference implementation).
## GDScript ints are signed 64-bit and wrap on overflow; right shift is
## arithmetic, so every right shift below is masked to act as a logical shift.
## STATUS: written but NOT YET RUN in Godot (see company/TASKBOARD.md, P-001).

const MULT := 6364136223846793005
const FNV_OFFSET := -3750763034362895579   # 0xCBF29CE484222325 as signed 64-bit
const FNV_PRIME := 0x100000001B3

var state: int = 0
var inc: int = 0


static func lsr(x: int, n: int) -> int:
	if n == 0:
		return x
	return (x >> n) & ((1 << (64 - n)) - 1)


func seed_rng(initstate: int, initseq: int) -> Pcg32:
	state = 0
	inc = (initseq << 1) | 1
	next_u32()
	state += initstate
	next_u32()
	return self


func next_u32() -> int:
	var old := state
	state = old * MULT + inc
	var xorshifted := lsr(lsr(old, 18) ^ old, 27) & 0xFFFFFFFF
	var rot := lsr(old, 59)
	return ((xorshifted >> rot) | (xorshifted << ((-rot) & 31))) & 0xFFFFFFFF


func next_float() -> float:
	return float(next_u32() >> 8) / 16777216.0


func next_normal() -> float:
	var u1 := 1.0 - next_float()
	var u2 := next_float()
	return sqrt(-2.0 * log(u1)) * cos(TAU * u2)


static func fnv1a64(text: String) -> int:
	var h := FNV_OFFSET
	for b in text.to_utf8_buffer():
		h = (h ^ b) * FNV_PRIME
	return h


static func splitmix64(x: int) -> int:
	x += -7046029254386353131   # 0x9E3779B97F4A7C15 as signed 64-bit
	var z := x
	z = (z ^ lsr(z, 30)) * -4658895280553007687   # 0xBF58476D1CE4E5B9
	z = (z ^ lsr(z, 27)) * -7723592293110705685   # 0x94D049BB133111EB
	return z ^ lsr(z, 31)


static func match_seed(save_seed: int, match_id: String) -> int:
	return splitmix64(save_seed ^ fnv1a64(match_id))


static func contest_stream(seed_of_match: int, contest_id: String) -> Pcg32:
	var name_hash := fnv1a64(contest_id)
	return Pcg32.new().seed_rng(splitmix64(seed_of_match ^ name_hash), name_hash)
