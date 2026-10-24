extends HarnessScenario
## Format (src/game/format.gd, docs/reference/input-camera.md, **Format**): the amounts, the
## meters' short form and the durations, each against the text it must give. Headless; no
## screenshots, and it acts on nothing in the game.

const DURATIONS := {
	-5: "0s", 0: "0s", 45: "45s", 60: "1m 00s", 75: "1m 15s", 3599: "59m 59s", 3600: "1h 00m",
	4000: "1h 06m", 66600: "18h 30m", 86399: "23h 59m", 86400: "1d 00h", 237600: "2d 18h",
	241199: "2d 18h",
}
const AMOUNTS := {0: "0", 12345: "12,345", -1500: "-1,500", 1000000: "1,000,000"}
const SHORTS := {999999: "999,999", 1250000: "1.2M", 4000000: "4M", 12500000: "12.5M", 1200000000: "1.2B"}


func run(_main: MainScript) -> void:
	for seconds: int in DURATIONS:
		check(Format.duration(seconds) == DURATIONS[seconds], "duration(%d) is '%s' ('%s')"
			% [seconds, DURATIONS[seconds], Format.duration(seconds)])
	for value: int in AMOUNTS:
		check(Format.amount(value) == AMOUNTS[value], "amount(%d) is '%s' ('%s')" % [value, AMOUNTS[value],
			Format.amount(value)])
	for value: int in SHORTS:
		check(Format.short(value) == SHORTS[value], "short(%d) is '%s' ('%s')" % [value, SHORTS[value],
			Format.short(value)])
