@tool

## Helper Script to track performance of the importer.

enum { SAVE, LOAD, GENERAL, TILES, POST_IMPORT, TOTAL }

static var category_time := {
	SAVE: 0,
	LOAD: 0,
	GENERAL: 0,
	TILES: 0,
	POST_IMPORT: 0,
	TOTAL : 0,
}

static var category_name := {
	SAVE: "save",
	LOAD: "load",
	GENERAL : "general",
	TILES: "tiles",
	POST_IMPORT: "post-import",
	TOTAL: "total"
}

static func log_time(category: int, time: int = 0) -> void:
	if category_time.has(category):
		category_time[category] += time
	else:
		push_warning("No DebugTime Category '%s'" % [category_name[category]])

static func clear_time() -> void:
	for category in category_time:
		category_time[category] = 0

static func get_total_time() -> int:
	var sum: int = 0
	for category in category_time:
		if category != TOTAL:
			sum += category_time[category]
	return sum

static func get_result() -> String:
	var result: String = "Performance Results:"
	for category in category_time:
		if category != TOTAL:
			result += "\n  [color=#8ec07c]%s [color=slategray](%sms)[/color]" % [category_name[category], category_time[category]]
	result.indent("\t")
	return result
