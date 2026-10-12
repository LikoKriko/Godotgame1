extends RefCounted
# Native contours: torso/waist and limbs sample the SAME original view.
const LEG_JOINTS := [
	[[Vector2(210,309),Vector2(211,373),Vector2(201,420)],[Vector2(274,309),Vector2(280,373),Vector2(284,420)]],
	[[Vector2(650,309),Vector2(647,371),Vector2(638,420)],[Vector2(710,309),Vector2(706,371),Vector2(711,420)]],
	[[Vector2(1080,309),Vector2(1064,373),Vector2(1058,420)],[Vector2(1112,309),Vector2(1105,373),Vector2(1116,420)]],
	[[Vector2(1528,309),Vector2(1525,375),Vector2(1520,423)],[Vector2(1582,309),Vector2(1582,375),Vector2(1590,423)]],
	[[Vector2(210,726),Vector2(211,788),Vector2(201,835)],[Vector2(274,726),Vector2(280,788),Vector2(284,835)]],
	[[Vector2(648,724),Vector2(633,788),Vector2(630,835)],[Vector2(704,724),Vector2(713,788),Vector2(720,835)]],
	[[Vector2(1063,727),Vector2(1060,788),Vector2(1048,835)],[Vector2(1103,727),Vector2(1110,788),Vector2(1100,835)]],
	[[Vector2(1524,727),Vector2(1518,788),Vector2(1504,835)],[Vector2(1588,727),Vector2(1588,788),Vector2(1597,835)]],
]
const FEET := [
	[Rect2(173,413,66,25),Rect2(257,413,65,25)],
	[Rect2(607,415,59,22),Rect2(687,415,69,22)],
	[Rect2(1034,416,79,23),Rect2(1101,415,53,18)],
	[Rect2(1493,416,65,22),Rect2(1560,416,65,23)],
	[Rect2(160,823,62,25),Rect2(251,823,69,27)],
	[Rect2(597,823,63,24),Rect2(692,823,56,25)],
	[Rect2(1019,823,64,24),Rect2(1058,824,78,26)],
	[Rect2(1474,824,63,25),Rect2(1574,824,55,25)],
]
static var leg_cache: Dictionary = {}
static func leg(index: int, limb: int) -> Dictionary:
	var key := index*2+limb
	if leg_cache.has(key):
		return leg_cache[key]
	var joint: Array = LEG_JOINTS[index][limb]
	var hip: Vector2 = joint[0]
	var knee: Vector2 = joint[1]
	var ankle: Vector2 = joint[2]
	var a := hip.direction_to(knee).orthogonal()
	var b := knee.direction_to(ankle).orthogonal()
	var result := {"hip":hip,"knee":knee,"ankle":ankle,
	"upper":[hip-a*20+Vector2(0,34),hip+a*20+Vector2(0,34),knee+a*16,knee-a*16],
	"lower":[knee-b*16,knee+b*16,ankle+b*12-Vector2(0,10),ankle-b*12-Vector2(0,10)]}
	leg_cache[key] = result
	return result
