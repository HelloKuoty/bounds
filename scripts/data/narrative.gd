class_name Narrative extends RefCounted
## All the game's prose, in one place. Pure fable — never a word of jargon (see
## CLAUDE.md iron rule; test_no_jargon scans every string here).

# 开场只用这一句短钩子(别拿大段文字挡在玩家和第一次点击之间);PREMISE 留作可选档案。
const HOOK := "万物各有其名、各有其位。后来名混了、位塌了。\n你来,把它重新划分明。"

const PREMISE := "很久以前,万物各有其名,名与物相称,界与界分明。后来人们贪图省事,把一个名安在许多物上,又拆掉了田垄、墙垣与门。于是名相混,物相融,分不清此地与彼地、此物与彼物,秩序一寸寸塌成了泥。\n你是最后一位司守,循着褪色的旧图走入这片正在腐朽的疆土——你不持刀,只重新为万物划清它该在的地方。"

const ENDING := "你收起尺,回望。每一处都重新有了边,有了名,有了它独自的安静。\n原来撑住一个世界的,从来不是更大的力气,而是:让每样东西,只做它自己。"

# Chapter framings — escalate as terrain, never as mechanics-speak.
const CHAPTERS := [
	{"name": "立垄", "line": "起初没有界,所以什么都不长久。先学会画一道线,让该在一处的,留在一处。"},
	{"name": "渡口", "line": "两地隔水相望,话却传不过去。在岸边立一块石,让此岸的言语,能被彼岸听懂。"},
	{"name": "回声", "line": "一件事落地,水纹会一圈圈推开。学会让重要的消息传到该到的地方,不多,不少。"},
	{"name": "蔓沼", "line": "最深处,名已尽数融在一起,再没有边、没有形。这里曾是众土之源,如今是它们共同的坟。"},
]

# Atmospheric one-liners shown when entering a new area.
const NARRATION := [
	"旧图在此处晕开了,墨迹底下还压着一座没塌尽的城。",
	"风里有两种气味:一种是熟了的麦,一种是化不开的泥。",
	"这片地认得你手里的尺——它等一道界,等了很久。",
	"越往里走,物越没有形状,连影子都开始相互渗。",
	"有座门还立着,门后的东西始终是一整团,没有散。",
	"此地与邻地说着同一个词,却指着两样东西——难怪都病了。",
	"你画下一道线。线的两侧,各自重新记起了自己是谁。",
	"泥退下去半寸,露出底下一行字:从前这里,样样分明。",
]


static func all_strings() -> Array:
	var out: Array = [HOOK, PREMISE, ENDING]
	for c in CHAPTERS:
		out.append(c["name"])
		out.append(c["line"])
	for n in NARRATION:
		out.append(n)
	return out
