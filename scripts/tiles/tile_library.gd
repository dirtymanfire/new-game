extends Node
## 오토로드: res://data/tiles/ 폴더의 모든 타일(.tres)을 불러와 id로 찾을 수 있게 합니다.
## 새 타일은 이 폴더에 .tres 파일을 추가하기만 하면 됩니다.

const TILE_DIR := "res://data/tiles/"

var _tiles: Dictionary = {} # StringName -> BehaviorTile


func _ready() -> void:
	for file in ResourceLoader.list_directory(TILE_DIR):
		if not file.ends_with(".tres"):
			continue
		var tile := load(TILE_DIR + file) as BehaviorTile
		if tile == null:
			push_warning("타일이 아닌 리소스입니다: %s" % file)
			continue
		if _tiles.has(tile.id):
			push_warning("중복된 타일 id입니다: %s" % tile.id)
		_tiles[tile.id] = tile


func get_tile(id: StringName) -> BehaviorTile:
	return _tiles.get(id)


func get_all() -> Array[BehaviorTile]:
	var result: Array[BehaviorTile] = []
	result.assign(_tiles.values())
	return result
