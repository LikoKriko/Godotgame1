extends RefCounted
# Native contours: torso/waist and limbs sample the SAME original view.
const TORSO := [
	[Vector2(214,194),Vector2(272,194),Vector2(283,213),Vector2(280,266),Vector2(293,290),Vector2(299,310),Vector2(185,310),Vector2(191,289),Vector2(204,266),Vector2(202,213)],
	[Vector2(655,194),Vector2(706,194),Vector2(720,214),Vector2(717,270),Vector2(727,290),Vector2(733,310),Vector2(626,310),Vector2(637,290),Vector2(649,267),Vector2(647,214)],
	[Vector2(1070,188),Vector2(1106,193),Vector2(1120,219),Vector2(1119,273),Vector2(1127,310),Vector2(1045,310),Vector2(1052,272),Vector2(1053,215)],
	[Vector2(1524,191),Vector2(1576,191),Vector2(1592,212),Vector2(1583,270),Vector2(1604,310),Vector2(1490,310),Vector2(1515,270),Vector2(1516,213)],
	[Vector2(215,606),Vector2(268,606),Vector2(283,628),Vector2(278,686),Vector2(298,727),Vector2(186,727),Vector2(205,684),Vector2(201,628)],
	[Vector2(658,606),Vector2(704,607),Vector2(716,630),Vector2(717,686),Vector2(730,727),Vector2(624,727),Vector2(648,685),Vector2(651,630)],
	[Vector2(1064,608),Vector2(1102,609),Vector2(1119,635),Vector2(1117,689),Vector2(1131,727),Vector2(1043,727),Vector2(1054,687),Vector2(1054,632)],
	[Vector2(1526,608),Vector2(1588,608),Vector2(1612,631),Vector2(1605,687),Vector2(1628,727),Vector2(1487,727),Vector2(1516,687),Vector2(1515,631)],
]
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
static func leg(index: int, limb: int) -> Dictionary:
	var joint: Array = LEG_JOINTS[index][limb]
	var hip: Vector2 = joint[0]
	var knee: Vector2 = joint[1]
	var ankle: Vector2 = joint[2]
	var a := hip.direction_to(knee).orthogonal()
	var b := knee.direction_to(ankle).orthogonal()
	return {"hip":hip,"knee":knee,"ankle":ankle,
	"upper":[hip-a*23-Vector2(0,14),hip+a*23-Vector2(0,14),hip+a*23+Vector2(0,28),knee+a*16,knee-a*16,hip-a*23+Vector2(0,28)],
	"lower":[knee-b*16,knee+b*16,ankle+b*12-Vector2(0,10),ankle-b*12-Vector2(0,10)]}
