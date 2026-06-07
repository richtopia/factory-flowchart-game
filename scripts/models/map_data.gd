## Data model representing a factory map — a bounded area where tools and
## paths are placed.
##
## Maps can optionally link to another map via the [code][link][/code] table,
## enabling multi-map navigation in the simulation.
class_name MapData
extends RefCounted

## Unique identifier for this map (e.g., "aluminum_valley").
var id: String = ""

## Human-readable display name (e.g., "Aluminum Production Valley").
var name: String = ""

## Width of the map in meters.
var width_m: float = 0.0

## Length of the map in meters.
var length_m: float = 0.0

## Whether this map is a linked sub-map of another map.
var is_linked_map: bool = false

## The ID of the target map this map links to, if [member is_linked_map] is
## [code]true[/code]. Empty string when not linked.
var target_map_id: String = ""


## Creates a [MapData] instance from a dictionary.
##
## Expected keys: [code]id[/code], [code]name[/code], [code]width_m[/code],
## [code]length_m[/code]. An optional nested [code]link[/code] dictionary may
## contain [code]is_linked_map[/code] and [code]target_map_id[/code].
static func from_dict(d: Dictionary) -> MapData:
	var map := MapData.new()
	map.id = d.get("id", "")
	map.name = d.get("name", "")
	map.width_m = float(d.get("width_m", 0.0))
	map.length_m = float(d.get("length_m", 0.0))

	var link: Variant = d.get("link", null)
	if link is Dictionary:
		map.is_linked_map = bool(link.get("is_linked_map", false))
		map.target_map_id = link.get("target_map_id", "")

	return map
