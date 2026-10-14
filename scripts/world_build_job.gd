extends RefCounted
var world
var seed_value: int
var mutex := Mutex.new()
var progress := 0.0
func build() -> void:
	world.generate(seed_value,report)
func report(value: float) -> void:
	mutex.lock(); progress = value; mutex.unlock()
func fraction() -> float:
	mutex.lock(); var value := progress; mutex.unlock(); return value
