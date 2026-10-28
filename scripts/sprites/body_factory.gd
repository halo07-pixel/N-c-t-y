class_name BodyFactory
extends RefCounted
## Picks how a fighter is drawn: with a jointed rig when the character has one, with its
## sprites when the sprite set exists, otherwise with the code-drawn placeholder. Missing art never breaks the game.


static func has_sprites(character: CharacterData) -> bool:
	return SpriteSetLoader.load_set(character.sprite_dir, character.sprite_id) != null


static func create(character: CharacterData, player_id: int) -> FighterBody:
	var body: FighterBody
	if character.rig != null:
		body = RigBody.new()
	elif has_sprites(character):
		body = SpriteBody.new()
	else:
		body = PlaceholderBody.new()
	body.setup(character, player_id)
	return body
