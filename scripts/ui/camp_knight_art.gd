extends RefCounted
## Reviewed painterly native layers; original planted-sword idle cadence and anchor.
const PORTRAIT = preload("res://assets/characters/mysterious_knight/art_polish_a_v03/textures/portrait.png")
const FRAMES := [
	preload("res://assets/characters/mysterious_knight/art_polish_a_v03/textures/idle_00.png"),
	preload("res://assets/characters/mysterious_knight/art_polish_a_v03/textures/idle_01.png"),
	preload("res://assets/characters/mysterious_knight/art_polish_a_v03/textures/idle_02.png"),
	preload("res://assets/characters/mysterious_knight/art_polish_a_v03/textures/idle_03.png"),
	preload("res://assets/characters/mysterious_knight/art_polish_a_v03/textures/idle_04.png"),
	preload("res://assets/characters/mysterious_knight/art_polish_a_v03/textures/idle_05.png"),
	preload("res://assets/characters/mysterious_knight/art_polish_a_v03/textures/idle_06.png"),
	preload("res://assets/characters/mysterious_knight/art_polish_a_v03/textures/idle_07.png")]
const ANCHOR := Vector2(.5,.84917587)

static func frame(seconds: float, reduced: bool) -> Texture2D:
	return FRAMES[0 if reduced else int(seconds*4)%FRAMES.size()]

