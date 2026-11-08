class_name SkillGuide
extends RefCounted
## What a skill does, in plain words, for the F3 move list. Each skill has a short hand-written
## sentence (by name); the numbers that tune it (bind time, shots, Reiatsu...) are added from its
## data, so the list never disagrees with the game. A skill without a sentence still gets its facts.

const TEXT := {
	"Getsuga Tenshō": "Bắn sóng kiếm khí. Giữ nút để tụ lực, đầy lực thì xuyên qua đối thủ.",
	"Getsuga Jūjishō": "Bắn thêm Getsuga hình chữ thập (một ngang, một dọc).",
	"Shunpo Strike": "Lướt tới đâm một nhát. Dùng để áp sát.",
	"Return Slash": "Quay lại chém xuyên ngược qua đối thủ.",
	"Rising Cut": "Chém hất lên và bay cao: dùng để về sân.",
	"Dive Slash": "Lao chéo xuống chém.",
	"Tensa Zangetsu": "Phản đòn: bị đánh trúng thì không mất máu và chém trả ngay.",
	"Heilig Pfeil": "Bắn mũi tên Quincy. Giữ nút để tụ lực.",
	"Ginrei Kojaku": "GIỮ nút Skill để bắn liên tục.",
	"Seele Schneider": "Cắm 3 lưỡi kiếm xuống sàn như bẫy chặn đường. Chạm vào là trúng đòn.",
	"Seele Schneider: Return": "Gọi các lưỡi kiếm bay về phía Uryu, gây sát thương dọc đường.",
	"Reishi Platform": "Dựng bệ reishi giữa không trung để nhảy lên và về sân.",
	"Sky Shot": "Bắn chéo xuống từ trên cao.",
	"Reishi Mine": "Đặt mìn lên sàn, nổ khi đối thủ chạm vào.",
	"Senbonzakura": "Thả đàn cánh hoa trôi lơ lửng trước mặt.",
	"Senbonzakura: Command": "Ra lệnh cho cánh hoa lao về phía trước.",
	"Flash Step": "Dịch chuyển chớp nhoáng tới sát đối thủ và chém.",
	"Rikujōkōrō": "Quay về phía đối thủ, 6 thanh sáng giáng xuống trói lại. Đối thủ không đi, nhảy, đánh được nhưng vẫn đỡ được; bị đánh trúng thì hết trói.",
	"Sky Flash": "Dịch chuyển lên cao: dùng để về sân.",
	"Byakurai": "Bắn tia sét cực nhanh chéo xuống. Giữ Lên/Xuống khi bắn để đổi góc.",
	"Petal Wall": "Tường cánh hoa chặn và hủy đạn của đối thủ.",
	"Hoero Zabimaru": "Phóng xích Zabimaru thẳng ra. Giữ nút để tụ lực.",
	"Zabimaru Pull": "Bắn xích kéo đối thủ về phía Renji.",
	"Zabimaru Slam": "Bấm lần nữa ngay khi đối thủ bị kéo tới: đập xuống, hất đối thủ xuống đất.",
	"Fang Dash": "Lao tới chém nặng. Dùng để áp sát.",
	"Zabimaru Whirl": "GIỮ nút Skill: vòng xích xoay quanh người, đánh trúng liên tục; mỗi nhịp tốn Reiatsu.",
	"Snake Hook": "Móc xích hất lên và bay cao: dùng để về sân.",
	"Second Hook": "Móc xích lần hai để bay xa hơn.",
	"Coil Snare": "Đặt bẫy xích trên sàn, quấn đối thủ chạm vào.",
	"Tsugi no Mai: Hakuren": "Bắn luồng băng thẳng ra. Giữ nút để tụ lực.",
	"Snow Step": "Lướt đi trong tuyết, gây sát thương dọc đường.",
	"Kōri no Kabe": "Quay về phía đối thủ và dựng tường băng đặc: chặn người đi bộ và cả đạn.",
	"Frost Rise": "Bay lên bằng băng: dùng để về sân.",
	"Snow Veil": "Rải vùng tuyết, đối thủ bên trong chạy chậm hơn. Rukia không bị chậm.",
	"Some no Mai: Tsukishiro": "Dựng các cột băng trên sàn: vùng sát thương rộng, khống chế không gian.",
	"Reiatsu Slash": "Chém sóng reiatsu. Giữ nút để tụ lực.",
	"Charging Cleave": "Lao tới chém rất nặng. Dùng để áp sát.",
	"Armored Rush": "Lao tới có giáp, đòn nhẹ đánh trúng không làm gián đoạn.",
	"Wild Leap": "Nhảy vọt lên cao: dùng để về sân.",
	"Meteor Drop": "Rơi thẳng xuống đập nặng.",
	"Ground Smash": "Đập đất cực mạnh nhưng chậm.",
	"Eyepatch Release": "Giật băng mắt. Trong thời gian này gây thêm sát thương nhưng cũng nhận thêm.",
}


## What sets each fighter's skills apart, in a few words (the character select screen).
const SIGNATURE := {
	"Ichigo": "Chữ thập · phản đòn Tensa · nhịp combo",
	"Uryu": "Lưỡi kiếm làm bẫy · bắn liên tục",
	"Byakuya": "Trói đối thủ · tia sét · cánh hoa",
	"Renji": "Vòng xích xoay · kéo rồi đập",
	"Rukia": "Tường băng · vùng tuyết làm chậm",
	"Kenpachi": "Giải phóng băng mắt · lao có giáp",
}


static func signature_for(character: CharacterData) -> String:
	return SIGNATURE.get(character.display_name, "")


## The sentence and the facts of a skill, one text.
static func text_for(skill: SpecialData) -> String:
	if skill == null:
		return ""
	var sentence: String = TEXT.get(skill.display_name.trim_suffix(" +"), "")
	var facts := facts_for(skill)
	if facts != "":
		sentence = (sentence + " " + facts).strip_edges()
	return sentence


## The numbers that tune a skill, read from its data.
static func facts_for(skill: SpecialData) -> String:
	var parts := PackedStringArray()
	if skill.bind_frames > 0:
		parts.append("Trói %.1fs." % (float(skill.bind_frames) / 60.0))
	if skill.is_stream():
		parts.append("Tối đa %d mũi, %d Reiatsu/mũi." % [skill.stream_max_shots, int(skill.stream_cost)])
	if skill.is_spin():
		parts.append("Tối đa %.1fs, %d Reiatsu/nhịp." % [float(skill.spin_frames) / 60.0, int(skill.spin_cost)])
	if skill.release_frames > 0:
		parts.append("%.0fs: gây ×%.2f, nhận ×%.2f, chạy nhanh ×%.2f." % [float(skill.release_frames) / 60.0, skill.release_dealt, skill.release_taken, skill.release_speed])
	if skill.counter_move != null and skill.cost > 0.0:
		parts.append("Tốn %d Reiatsu." % int(skill.cost))
	for projectile in skill.projectiles:
		if projectile.solid:
			parts.append("Tồn tại %.1fs." % (float(projectile.lifetime_frames) / 60.0))
			break
		if projectile.slow_scale < 1.0:
			parts.append("Kéo dài %.0fs." % (float(projectile.lifetime_frames) / 60.0))
			break
	return " ".join(parts)


## How the skill is started, e.g. "lần 2 trong 0.4s" for a follow-up.
static func trigger_for(parent: SpecialData) -> String:
	var follow := parent.follow_up
	if follow == null:
		return ""
	if parent.recall_planted:
		return "bấm lại skill này bất cứ lúc nào khi lưỡi kiếm còn trên sàn"
	var text := "lần 2 trong %.1fs" % (float(parent.follow_up_window) / 60.0)
	if parent.follow_up_cost > 0.0:
		text += " · %d Reiatsu" % int(parent.follow_up_cost)
	return text
