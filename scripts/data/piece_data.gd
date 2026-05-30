class_name PieceData extends RefCounted
## One piece that lands on a territory.
##
## A piece carries a `glyph` (the visible name) and a `meaning` (what it truly
## is). Two pieces sharing a glyph but disagreeing on meaning — inside the same
## region — is the seed of all trouble. (Builder note: living = Entity,
## token = Value Object. The player never hears those words.)

var id: String = ""
var label: String = ""    # display name shown to the player
var glyph: String = ""    # the visible symbol/word it carries
var meaning: String = ""  # the true meaning (drives instability; semantic key)
var kind: String = "living"  # "living" | "token"
var corrupt: bool = false  # starts already rotten (only meaningful in spreading territories)
var fixed: bool = false    # 固/锚: can't be moved by a wall — you must carve the OTHERS around it (iter-53)


static func from_dict(d: Dictionary) -> PieceData:
	var p := PieceData.new()
	p.id = d.get("id", "")
	p.label = d.get("label", "")
	p.glyph = d.get("glyph", "")
	p.meaning = d.get("meaning", "")
	p.kind = d.get("kind", "living")
	p.corrupt = bool(d.get("corrupt", false))
	p.fixed = bool(d.get("fixed", false))
	return p


func is_valid() -> bool:
	return id != "" and glyph != "" and meaning != "" and kind in ["living", "token"]
