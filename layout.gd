extends RefCounted
# T0: logical coordinates, independent of window scaling.
const VIEWPORT_SIZE := Vector2(1600, 900)
const HUD_HEIGHT := 90.0
const COMMAND_TOP := 700.0
const GRID_ORIGIN := Vector2(269, 104)
const CELL_SIZE := Vector2(118, 116)
const GRID_COLUMNS := 9
const GRID_ROWS := 5
const DEPLOY_COLUMNS := 3
const GRID_SIZE := CELL_SIZE * Vector2(GRID_COLUMNS, GRID_ROWS)
const GATE_OFFSET := 20.0
const LORD_START := Vector2(690, 394)
const LORD_MIN := GRID_ORIGIN + Vector2(3, 4)
const LORD_MAX := GRID_ORIGIN + GRID_SIZE - Vector2(3, 12)
const CARD_Y := 730.0
const CARD_SIZE := Vector2(145, 202)
const CARD_SCALE := Vector2(0.8, 0.8)
const CARD_X := [500.0, 650.0, 800.0]
const PAUSE_RECT := Rect2(870, 28, 44, 40)
const RESTART_RECT := Rect2(1450, 28, 90, 36)
const PAGE_FRAME := Rect2(13, 13, 1574, 874)
const FIELD_FRAME := Rect2(25, 96, 1550, 596)
const CASTLE_RECTS := [Rect2(30,106,185,580), Rect2(1385,106,185,580)]
const HUD_FRAME := Rect2(28, 18, 1544, 68)
const PORTRAITS := [Vector2(78,50), Vector2(1380,50)]
const CASTLE_NAMES := [Vector2(126,39), Vector2(1080,39)]
const CASTLE_BARS := [Rect2(128,53,330,12), Rect2(1000,53,308,12)]
const CASTLE_FRAMES := [Rect2(108,40,370,38), Rect2(982,40,345,38)]
const CASTLE_VALUES := [Vector2(490,65), Vector2(1255,39)]
const CLOCK_FRAME := Rect2(710,26,145,48)
const CLOCK_TEXT := Vector2(730,59)
const COMMAND_FRAME := Rect2(28,700,1544,188)
const COMMAND_TITLE := Vector2(49,723)
const NOTICE_TEXT := Vector2(410,723)
const ECONOMY_FRAME := Rect2(48,738,380,137)
const GOLD_ICON := Rect2(60,750,36,41)
const GOLD_TEXT := Vector2(105,784)
const INCOME_TEXT := Vector2(230,777)
const FARM_COUNT_TEXT := Vector2(65,810)
const GOLD_PIP_ORIGIN := Vector2(65,823)
const GOLD_PIP_STEP := 30.0
const GOLD_PIP_SIZE := Vector2(22,10)
const GOLD_PIP_COUNT := 10
const ECONOMY_HELP := Vector2(65,860)
const LORD_FRAME := Rect2(1080,738,460,137)
const LORD_TITLE := Vector2(1100,762)
const LORD_BAR := Rect2(1100,774,230,8)
const LORD_HP_TEXT := Vector2(1350,783)
const LORD_STATE_TEXT := Vector2(1100,809)
const LORD_AURA_TEXT := Vector2(1100,835)
const LORD_HELP_TEXT := Vector2(1100,860)
const OVERLAY_RECT := Rect2(440,290,720,150)
const OVERLAY_TITLE := Vector2(490,352)
const OVERLAY_HELP := Vector2(490,400)

static func cell_center(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE

static func spawn_position(team: int, lane: int) -> Vector2:
	return cell_center(Vector2i(0 if team == 0 else GRID_COLUMNS - 1, lane))

static func gate_stop(side: int) -> float:
	return spawn_position(side, 0).x + (-GATE_OFFSET if side == 0 else GATE_OFFSET)

static func gate_icon_x(side: int) -> float:
	return GRID_ORIGIN.x - 28 if side == 0 else GRID_ORIGIN.x + GRID_SIZE.x + 28

# Help page: text wraps inside two bounded columns.
const HELP_PANEL := Rect2(100,105,1400,640)
const HELP_TITLE := Vector2(150,175)
const HELP_TEXT_RECTS := [Rect2(150,210,610,495),Rect2(830,210,610,495)]
const HELP_FONT_SIZE := 22
const HELP_BACK := Rect2(650,780,300,55)
