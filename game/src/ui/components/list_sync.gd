class_name ListSync
extends RefCounted
## Keyed reconcile for a list that changes length or order (build plan 2.1, rule 3): instead of deleting every child and
## building them again, keep one child per key.
##   ListSync.sync(container, keys, make_fn, update_fn := Callable()) -> Dictionary (key -> child)
## - a key seen for the first time: make_fn(key) -> Control is called once and the child is added;
## - a key that is in `keys`: its child is shown and moved to its place (move_child only when it is not there already);
## - a key that is gone: its child is hidden (visible = false), not freed, so it returns with the same instance id and
##   state when the key comes back (a role filter, a search);
## - update_fn(child, key), when given, runs for every shown child so it can set values in place (components guard equal
##   values themselves).
## The container should hold only synced children. Hidden children are kept after the shown ones. Duplicate keys in one
## call are ignored after the first. Nothing is freed here: free the container when the screen goes away.

const MAP_META := "listsync_map"
const KEY_META := "listsync_key"


static func sync(container: Container, keys: Array, make_fn: Callable, update_fn: Callable = Callable()) -> Dictionary:
	var map: Dictionary = container.get_meta(MAP_META, {})
	var seen := {}
	var order: Array = []
	for k in keys:
		if seen.has(k):
			continue
		seen[k] = true
		order.append(k)
		if not map.has(k) or not is_instance_valid(map[k]):
			var child: Control = make_fn.call(k)
			child.set_meta(KEY_META, k)
			container.add_child(child)
			map[k] = child
	for i in order.size():
		var node: Control = map[order[i]]
		node.visible = true
		if node.get_index() != i:
			container.move_child(node, i)
		if update_fn.is_valid():
			update_fn.call(node, order[i])
	var hidden_at := order.size()
	for k in map.keys():
		if not seen.has(k) and is_instance_valid(map[k]):
			var node2: Control = map[k]
			node2.visible = false
			if node2.get_index() != hidden_at and hidden_at < container.get_child_count():
				container.move_child(node2, hidden_at)
			hidden_at += 1
	container.set_meta(MAP_META, map)
	return map


## The children now shown, in order.
static func shown(container: Node) -> Array:
	var out: Array = []
	for c in container.get_children():
		if c is Control and (c as Control).visible and c.has_meta(KEY_META):
			out.append(c)
	return out


## The keys now shown, in order.
static func shown_keys(container: Node) -> Array:
	var out: Array = []
	for c in shown(container):
		out.append(c.get_meta(KEY_META))
	return out
