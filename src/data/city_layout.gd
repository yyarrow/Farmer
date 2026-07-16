extends RefCounted

# One source of truth for the current fixed city. Future city tiers can expose
# additional layouts without making UI hit targets and rendered art drift apart.
const BUILDING_POSITIONS := {
	"wall": Vector2(386, 154),
	"barracks": Vector2(326, 217),
	"warehouse": Vector2(226, 268),
	"market": Vector2(78, 323),
	"house": Vector2(330, 348),
	"woodcut": Vector2(35, 209),
	"quarry": Vector2(395, 407),
	"farm": Vector2(83, 432),
}

const BUILDING_SIZES := {
	"wall": Vector2(132, 112),
	"barracks": Vector2(126, 112),
	"warehouse": Vector2(112, 102),
	"market": Vector2(118, 100),
	"house": Vector2(118, 104),
	"woodcut": Vector2(116, 104),
	"quarry": Vector2(116, 104),
	"farm": Vector2(126, 106),
}

const MARKER_POSITIONS := {
	"wall": Vector2(410, 190),
	"barracks": Vector2(344, 260),
	"warehouse": Vector2(243, 305),
	"market": Vector2(102, 354),
	"house": Vector2(360, 390),
	"woodcut": Vector2(58, 242),
	"quarry": Vector2(415, 465),
	"farm": Vector2(104, 485),
}

const EFFECT_POSITIONS := {
	"trade": Vector2(150, 405),
	"recruit": Vector2(380, 275),
	"defense_order": Vector2(377, 292),
	"policy": Vector2(270, 410),
	"siege": Vector2(425, 205),
	"shortage": Vector2(270, 460),
	"storage_full": Vector2(270, 350),
}
