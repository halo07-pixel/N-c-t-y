class_name BodyFactory
extends RefCounted
## Picks how a fighter is drawn: with its sprites when the sprite set exists,
## otherwise with the code-drawn placeholder. Missing art never breaks the game.


static func has_sprites(character: CharacterData) -> bool:
	return SpriteSetLoader.load_set(character.sprite_dir, character.sprite_id) != null


static func create(character: CharacterData, player_id: int) -> FighterBody:
	var body: FighterBody = SpriteBody.new() if has_sprites(character) else PlaceholderBody.new()
	body.setup(character, player_id)
	return body
