extends RefCounted
## Proves run_tests.gd auto-discovery: this file is not called by name anywhere, so if its check shows up in the
## count, the loop found it. It also pins the contract of a discovered file: a plain script with run(check).


func run(check: Callable) -> void:
	check.call(true, "auto-discovery ran discovery_tests.gd (found by name pattern, not by an explicit call)")
	var found := false
	for f in DirAccess.get_files_at("res://tests"):
		found = found or f == "discovery_tests.gd"
	check.call(found, "discovery_tests.gd is in res://tests")
