class_name ShelterEvents
## Nội dung Chương 2 "Dưới hầm": sự kiện ban đêm ở cửa hầm, chạm trán ngoài phố, chuyện buổi sáng, bản tin radio.
##
## Mỗi sự kiện: {title, text, choices}. Mỗi lựa chọn: {t: nhãn, need: điều kiện (tuỳ), info: true nếu chỉ là dò xét, out: [kết cục]}.
## Mỗi kết cục: {p: xác suất, t: lời kể, fx: tác động}. Các khoá tác động xem Shelter.apply_fx().
## "Kẻ nhại": thứ bắt chước giọng người quen để dụ mở cửa. Dấu hiệu: lặp lại y nguyên lời vừa nghe, không chớp mắt,
## không có hơi thở, khô ráo giữa trời mưa, gõ cửa đều như máy.

const DAYS_TO_RESCUE := 8

## Đêm nào cũng có một chuyện. Vài đêm đã định sẵn (mạch truyện chính), còn lại bốc từ POOL.
## Chương 2 (bản mới): đêm 1, 3, 4 bốc ngẫu nhiên một trong 10 sự kiện dưới đây; đêm 2 là lọ thuốc, đêm 5 là máy phát tín hiệu.
## Từ đêm 6 trở đi không còn sự kiện ngẫu nhiên. Các sự kiện cũ (ông Tư thật, cô y tá ở nhờ, con Mực…) tạm cất, không dùng.
const NIGHT_SCRIPT := {2: "thuoc_dac_tri", 5: "may_phat_tin_hieu"}
const RANDOM_NIGHTS := [1, 3, 4]
const NIGHT_POOL := ["ke_lua_dao", "nguoi_kho", "cuop_xin", "keu_cuu", "het_do_an", "ong_khi", "nhai_ong_tu", "y_ta_doi_thuoc", "tieng_tre_khoc", "mua_ngap"]
## Câu mở đầu dùng chung cho kẻ lừa đảo và người khổ thật: nghe thì giống hệt nhau.
const BEG_TEXTS := [
	"Tiếng gõ khe khẽ, rồi một giọng đàn ông khàn đặc:\n\n— Anh chị ơi… tôi xin một chút gì ăn được thôi. Mẹ già tôi ở nhà nằm liệt hai hôm nay rồi, không có gì vào bụng. Tôi lạy anh chị…",
	"— Có ai dưới đó không ạ? — Giọng một người phụ nữ, run run. — Con tôi lên cơn sốt từ chiều, nhà hết sạch nước. Một chai thôi, tôi xin…",
	"Ai đó quỳ xuống ngay trên nắp hầm, trán gõ vào sắt từng nhịp.\n\n— Ba ngày rồi tôi chưa ăn gì. Tôi không xin nhiều. Một gói mì thôi. Tôi biết anh chị cũng khổ…",
]
const OUTSIDE_POOL := ["o_dot_lua", "o_ong_ba", "o_nguoi_ket", "o_xe_hang", "o_dua_be", "o_nguoi_linh"]
const MORNING_POOL := ["m_chuot", "m_bup_be", "m_ba_ngoai", "m_nuoc_la", "m_cau_hoi"]

const RADIO := {
	1: "…đây là Ban chỉ huy cứu hộ thành phố. Lực lượng sẽ vào được nội thành sau khoảng bảy ngày. Ở yên dưới hầm. Chúng tôi chỉ đến vào BAN NGÀY. Nhắc lại: sau khi trời tối, không mở cửa cho bất kỳ ai, kể cả người gọi đúng tên bạn…",
	2: "…có báo cáo về những thứ bắt chước tiếng người. Chúng lặp lại lời bạn vừa nói. Chúng không biết những điều chỉ người thân mới biết. Hãy hỏi trước khi mở…",
	3: "…các trạm y tế lưu động chưa vào được. Nhà thuốc ở các khu phố có thể còn kháng sinh. Trẻ sốt cao quá ba ngày không thuốc sẽ nguy kịch…",
	4: "…để trực thăng nhận ra nơi còn người sống: treo một tấm vải trắng trước cửa nhà. Nhà không có dấu sẽ bị bỏ qua ở lượt đầu…",
	5: "…đã mở được hành lang phía tây. Còn ba ngày. Tiết kiệm nước. Một người lớn chịu được ba ngày không uống, không hơn…",
	6: "…đêm nay và đêm mai chúng sẽ đến rất đông. Chúng biết chúng tôi sắp tới. Đừng tin giọng nói nào ngoài cửa hầm…",
	7: "…sáng mai. Chúng tôi vào từ phía tây lúc rạng sáng. Ai còn nghe được, hãy cầm cự thêm một đêm nữa…",
	8: "…chúng tôi đang ở ngay trên phố của các bạn…",
}

const EVENTS := {
	# ============================================================ CHƯƠNG 2 BẢN MỚI: CỐT TRUYỆN
	"thuoc_dac_tri": {
		"title": "Lọ thuốc của bé Na",
		"text": "Bé Na lên cơn. Môi con tím tái, mỗi hơi thở rít lên như kéo qua ống sậy. Đây là cơn bệnh cũ của con, và chỉ có một thứ cắt được nó: lọ thuốc đặc trị con vẫn mang trong cặp.\n\nMai lục tung cái cặp lần thứ ba.\n\n— Không có. Anh ơi… sáng hôm ấy con để quên cặp ở trường. Lọ thuốc nằm trong tủ khoá của con.\n\nTrường tiểu học ở phía nam, gần nhà bác Tư. Mấy trăm cái tủ khoá. Còn một cách khác: bệnh viện thành phố chắc chắn còn thuốc, nhưng loại thuốc này người ta cất trong két.\n\nCon chỉ cầm cự được tới hết ngày thứ tư.",
		"choices": [
			{"t": "Cả nhóm đi ngay đêm nay", "out": [{"t": "Bạn nhét đèn pin vào túi áo. Mai giữ con trong lòng, không nói gì, chỉ gật đầu.\n\nTủ khoá ở trường thì nhiều, phải lục từng cái. Nếu tìm được thứ gì nói được két bệnh viện nằm đâu và mở bằng gì, sẽ nhanh hơn: nhà giàu ở các biệt phủ hay có những món như thế.", "fx": {"go_out": "medicine"}}]},
			{"t": "Đợi đêm mai, chuẩn bị kỹ hơn", "out": [{"t": "Bạn ngồi cạnh con cả đêm, đếm từng nhịp thở. Gần sáng, cơn rít dịu đi một chút. Nhưng chỉ một chút.\n\n(Đêm nào cũng có thể ra ngoài tìm thuốc. Hạn cuối là hết ngày thứ tư.)", "fx": {"morale": -4}}]},
		],
	},
	"may_phat_tin_hieu": {
		"title": "Trạm phát sóng",
		"text": "Cái đài rè rè suốt cả ngày, rồi đến tối thì bắt được một giọng nói rõ ràng:\n\n— …ai còn nghe được: tại trạm phát sóng phía nam hồ còn một máy phát tín hiệu dã chiến. Mang nó về chỗ trú ẩn và bật lên, quân đội sẽ biết vị trí của các bạn. Lưu ý: tháp phát sóng có một thứ đang bám trên đó. Nó nhìn thấy mọi thứ chuyển động bên dưới. Nhắc lại…\n\nMai nhìn bạn. Máy phát to cỡ một cái vali lớn, phải vác bằng cả hai tay.",
		"choices": [
			{"t": "Cả nhóm đi lấy máy phát ngay đêm nay", "out": [{"t": "Trạm phát sóng ở phía nam hồ, cái tháp trắng đỏ cao vượt mọi mái nhà. Vác máy về thì không chạy nhanh được, không đánh trả được: phải có người đi kèm, hoặc đặt máy xuống mà đánh.", "fx": {"go_out": "machine", "flag": "radio_may"}}]},
			{"t": "Để đêm khác", "out": [{"t": "Bạn tắt đài. Giọng nói kia vẫn lặp lại trong đầu bạn đến sáng.\n\n(Đêm nào cũng có thể ra ngoài lấy máy phát.)", "fx": {"flag": "radio_may"}}]},
		],
	},
	"dem_nay": {
		"title": "Đêm nay",
		"text": "Căn hầm đã yên. Bên trên, thành phố mất điện hoàn toàn: chỉ còn ánh trăng soi được vài con phố, phần còn lại tối như mực. Đèn pin soi được đường, nhưng cũng báo cho mọi thứ biết bạn đang ở đâu.",
		"choices": [
			{"t": "Ngủ tới sáng", "out": [{"t": "Bạn kéo chăn lên. Bên trên, thứ gì đó rất lớn bước qua, mặt đất rung lên từng nhịp, rồi xa dần.", "fx": {"sleep": true}}]},
			{"t": "Cả nhóm leo lên tìm đồ (về trước khi trời sáng)", "out": [{"t": "Bạn đẩy nắp hầm lên một khe nhỏ, nghe ngóng. Không có gì. Đi thôi.", "fx": {"go_out": "loot", "ambush": 0.3}}]},
		],
	},
	# ============================================================ 10 SỰ KIỆN ĐÊM (đêm 1, 3, 4)
	"ke_lua_dao": {
		"title": "Người xin ăn",
		"beg": true,
		"text": "",
		"choices": [
			{"t": "Đưa một phần đồ ăn qua khe cửa", "need": {"food": 1}, "out": [{"t": "Bàn tay giật lấy gói đồ ăn nhanh như chớp. Rồi một tràng cười.\n\n— Mẹ già nào? Tao còn chẳng nhớ mặt mẹ tao. Nói gì chúng mày cũng tin à? Mai tao lại ghé, nhà này dễ xin thế cơ mà.\n\nTiếng chân bỏ đi, vừa đi vừa huýt sáo.", "fx": {"food": -1, "morale": -6, "later": {"in": 1, "ev": "cuop_xin"}}}]},
			{"t": "Đưa một chai nước qua khe cửa", "need": {"water": 1}, "out": [{"t": "— Nước à? — Hắn lắc lắc cái chai, cười khẩy. — Thôi cũng được, đỡ hơn không. Cảm ơn nhé, đồ ngốc.\n\nHắn tu một hơi, ném vỏ chai xuống ngay trên nắp hầm.", "fx": {"water": -1, "morale": -5}}]},
			{"t": "Không đưa gì cả", "out": [{"t": "Im lặng một lúc. Rồi hắn đá mạnh vào nắp hầm.\n\n— Đồ khốn! Chúng mày ăn no nằm đấy, để người ta chết đói! Tao nhớ nhà này rồi đấy!\n\nHắn chửi thêm một tràng nữa, rồi bỏ đi. Không có tiếng khóc nào, không có tiếng mẹ già nào.", "fx": {"morale": 1}}]},
		],
	},
	"nguoi_kho": {
		"title": "Người xin ăn",
		"beg": true,
		"text": "",
		"choices": [
			{"t": "Đưa một phần đồ ăn qua khe cửa", "need": {"food": 1}, "out": [{"t": "Người bên trên cầm gói đồ ăn bằng cả hai tay. Một lúc lâu không nói được gì.\n\n— Cảm ơn anh chị… cảm ơn… Tôi sẽ không quên đâu.\n\nTiếng chân chạy vội đi, như sợ thứ trong tay biến mất.", "fx": {"food": -1, "morale": 6, "later": {"in": 2, "ev": "qua_tra_on"}}}]},
			{"t": "Đưa một chai nước qua khe cửa", "need": {"water": 1}, "out": [{"t": "— Nước… — Giọng người ấy vỡ ra. — Con tôi khát từ hôm qua. Anh chị là người tốt. Trời sẽ thương anh chị.\n\nHọ đi rồi, nhưng bạn nghe thấy tiếng khóc rất lâu sau.", "fx": {"water": -1, "morale": 6, "later": {"in": 2, "ev": "qua_tra_on"}}}]},
			{"t": "Không đưa gì cả", "out": [{"t": "— Vâng… tôi hiểu. Ai cũng khó. Tôi xin lỗi đã làm phiền.\n\nKhông một lời trách. Tiếng chân lê đi rất chậm.\n\nSáng hôm sau, ở đầu ngõ, có người nằm co ro cạnh cột điện, không dậy nữa.", "fx": {"morale": -9}}]},
		],
	},
	"qua_tra_on": {
		"title": "Cái túi trước cửa hầm",
		"text": "Không có tiếng gõ. Gần sáng, bạn nghe tiếng sột soạt rất khẽ trên nắp hầm, rồi tiếng chân xa dần.\n\nTrên nắp hầm có một túi ni lông buộc kỹ: ít đồ ăn, hai chai nước, và một mẩu giấy viết vội: \"Cảm ơn hôm trước. Mẹ tôi đã ăn được.\"",
		"choices": [
			{"t": "Mang cái túi xuống hầm", "out": [{"t": "Bạn đặt cái túi lên kệ. Mai đọc mẩu giấy rồi cất vào túi áo.", "fx": {"food": 2, "water": 2, "morale": 8}}]},
		],
	},
	"cuop_xin": {
		"title": "Ba gã đàn ông",
		"text": "Không gõ. Chúng đập, bằng thứ gì đó bằng sắt.\n\n— Biết dưới này có người rồi. Khói bếp bốc lên từ ống thông hơi kia kìa. Một phần đồ ăn, hoặc một chai nước. Tuồn lên đây thì bọn tao đi. Không thì bọn tao tự xuống lấy.\n\nBé Na giật mình khóc. Mai bịt miệng con.",
		"choices": [
			{"t": "Ghé mắt nhìn qua khe nắp hầm", "info": true, "out": [{"t": "Ba người, khăn bịt kín mặt. Một tên cầm ống tuýp, một tên cầm gậy, tên thứ ba đứng xa hơn, mắt dán vào ống thông hơi. Chúng gầy, nhưng không gầy bằng những người bạn thấy ngoài phố."}]},
			{"t": "Tuồn một phần đồ ăn lên", "need": {"food": 1}, "out": [
				{"p": 0.3, "t": "Một bàn tay giật lấy.\n\n— Biết điều đấy. — Tiếng chân bỏ đi.", "fx": {"food": -1, "morale": -3}},
				{"p": 0.7, "t": "Bàn tay giật lấy gói đồ ăn. Rồi một giọng khác cười:\n\n— Nhìn kìa, dưới đấy còn cả kệ. Xuống!\n\nNắp hầm bị nạy tung. Ba cái bóng nhảy xuống thang.", "fx": {"food": -1, "fight": 3}},
			]},
			{"t": "Tuồn một chai nước lên", "need": {"water": 1}, "out": [
				{"p": 0.3, "t": "— Nước cũng được. Đi thôi. — Tiếng chân xa dần.", "fx": {"water": -1, "morale": -3}},
				{"p": 0.7, "t": "— Một chai thôi à? Dưới đấy chắc còn cả thùng.\n\nNắp hầm bật tung. Chúng nhảy xuống, lăm lăm gậy gộc.", "fx": {"water": -1, "fight": 3}},
			]},
			{"t": "Không đưa gì. Cầm vũ khí lên.", "out": [
				{"p": 0.3, "t": "Chúng đập thêm một lúc. Một tên chửi thề: \"Cửa sắt, mất công.\" Tiếng chân bỏ đi.", "fx": {"morale": 2}},
				{"p": 0.7, "t": "— Không đưa thì bọn tao tự lấy!\n\nTiếng xà beng nạy bản lề. Nắp hầm bung ra. Ba gã nhảy xuống.", "fx": {"fight": 3}},
			]},
			{"t": "Lên đạn thật to rồi nói vọng lên", "need": {"item": "sungluc"}, "out": [
				{"p": 0.8, "t": "Tiếng khoá nòng lách cách vang lên trong hầm. Bên trên im bặt.\n\n— Nó có súng. Đi.", "fx": {"morale": 6}},
				{"p": 0.2, "t": "— Có súng thì sao? Bọn tao ba thằng!\n\nNắp hầm bung ra. Hai gã liều mạng nhảy xuống, tên thứ ba bỏ chạy.", "fx": {"fight": 2}},
			]},
		],
	},
	"keu_cuu": {
		"title": "Tiếng kêu cứu",
		"text": "Tiếng hét xé toạc đêm, rất gần, chỉ cách vài căn nhà.\n\n— Cứu với! Cứu tôi với! Tôi đưa hết rồi, tha cho tôi!\n\nTiếng gậy nện xuống người, đều đều. Tiếng ai đó cười. Rồi tiếng hét yếu dần.",
		"choices": [
			{"t": "Ghé mắt nhìn qua khe nắp hầm", "info": true, "out": [{"t": "Dưới ánh trăng, đầu ngõ: một người đàn ông nằm co trên mặt đường, ôm đầu. Hai cái bóng đứng quanh, thay nhau đá. Một cái ba lô bị xé tung, đồ đạc vương vãi."}]},
			{"t": "Cả nhóm cầm vũ khí ra cứu", "out": [{"t": "Bạn đẩy nắp hầm, lao lên. Tiếng cười ngoài đầu ngõ tắt ngấm. Hai cái bóng quay lại.", "fx": {"go_out": "help"}}]},
			{"t": "Ngủ tiếp. Bịt tai con lại.", "out": [{"t": "Bạn bịt tai bé Na. Mai bịt tai bạn. Tiếng hét kéo dài thêm một lúc, rồi chỉ còn tiếng gió.\n\nSáng ra không ai nói về chuyện đó.", "fx": {"morale": -8}}]},
		],
	},
	"het_do_an": {
		"title": "Kệ trống",
		"need": {"low_food": true},
		"text": "Bạn đếm lại kệ đồ lần thứ hai. Không cần đếm cũng biết: không đủ cho ngày mai.\n\nBé Na hỏi bữa sáng ăn gì. Mai bảo con ngủ đi, sáng mẹ nói.\n\nBên ngoài, đêm nay trời không trăng.",
		"choices": [
			{"t": "Cả nhóm ra ngoài kiếm đồ ngay đêm nay", "out": [{"t": "Không trăng thì tối hơn, cũng có nghĩa là khó bị nhìn thấy hơn. Bạn đẩy nắp hầm lên.\n\nNhưng không chỉ mình bạn nghĩ thế. Đêm nay ngoài phố có cả những người khác đang đói.", "fx": {"go_out": "loot", "ambush": 0.6}}]},
			{"t": "Nhịn qua đêm nay", "out": [{"t": "Cả nhà chia nhau nửa gói bánh quy cuối cùng. Bé Na ăn phần của mẹ mà không biết.", "fx": {"morale": -5}}]},
		],
	},
	"ong_khi": {
		"title": "Không khí",
		"text": "Ngọn nến trên bàn cháy mỗi lúc một lùn đi. Bé Na thở dốc. Mai ôm ngực, mặt tái mét.\n\nỐng thông hơi. Có thứ gì đó rơi đè lên miệng ống ngoài kia, hoặc khớp nối bị bật ra khi mặt đất rung lúc chiều. Không sửa thì đến sáng cả nhà không còn đủ không khí để thở.",
		"choices": [
			{"t": "Cả nhóm lên sửa ống (tiện kiếm đồ luôn)", "out": [{"t": "Bạn đẩy nắp hầm. Không khí đêm lạnh buốt tràn vào phổi. Cái ống thông hơi nằm cạnh đống đổ nát, gãy gập ở khớp nối.\n\n(Đến chỗ ống thông hơi, bấm E để sửa. Sửa xong rồi muốn đi kiếm đồ thì đi.)", "fx": {"go_out": "pipe", "pipe": true, "ambush": 0.25}}]},
			{"t": "Bịt khe cửa, cố qua đêm", "out": [
				{"p": 0.5, "t": "Gần sáng, ngọn nến tắt hẳn. Cả nhà tỉnh dậy với cái đầu như búa bổ. Bé Na nôn ra sàn. Mai không đứng dậy nổi.", "fx": {"hp": -25, "hurt": "mai", "morale": -12}},
				{"p": 0.5, "t": "Bạn thức cả đêm, quạt từng chút không khí từ khe cửa vào. Sáng ra ai cũng choáng váng, nhưng còn sống.", "fx": {"hp": -12, "morale": -6}},
			]},
		],
	},
	"nhai_ong_tu": {
		"title": "Giọng bác Tư",
		"text": "Trời mưa. Mười một tiếng gõ, đều tăm tắp.\n\n— Chú ơi. Bác Tư đây. Chú cầm cái xà beng của bác. Mở cửa cho bác lấy lại.\n\nĐúng là giọng bác Tư. Nhưng hôm trước nhà bác trống không, cửa mở toang, một vệt máu kéo dài ra ngõ.",
		"choices": [
			{"t": "Ghé mắt nhìn qua khe nắp hầm", "info": true, "out": [{"t": "Bác Tư đứng ngay trên nắp hầm, thẳng đơ, hai tay buông xuôi. Mưa xối xả quanh bác, nhưng cái áo bác mặc khô nguyên.\n\nSuốt lúc bạn nhìn, bác không chớp mắt lần nào."}]},
			{"t": "Hỏi: \"Con Mực nhà bác đâu rồi?\"", "info": true, "out": [{"t": "Im lặng một nhịp.\n\n— Con Mực nhà bác đâu rồi.\n\nNó lặp lại đúng câu của bạn. Đúng cả giọng của bạn."}]},
			{"t": "Mở cửa cho bác Tư", "out": [
				{"p": 0.75, "t": "Nắp hầm vừa hé, thứ đó đổ ập xuống như không có xương. Mai hét lên. Bạn vớ được cái ghế, đập cho tới khi nó chui ngược ra ngoài, nhưng cánh tay bạn đã rách một đường dài, và một thùng đồ ăn bị giẫm nát.", "fx": {"hp": -35, "bleed": true, "food": -1, "morale": -15}},
				{"p": 0.25, "t": "Nắp hầm vừa hé, một bàn tay dài quá khổ thò vào. Bạn sập nắp xuống bằng cả người. Có tiếng gì đó gãy. Nó rút đi, để lại ba ngón tay không có móng trên bậc thang.", "fx": {"hp": -10, "morale": -10}},
			]},
			{"t": "Không mở. Chặn thêm thanh sắt.", "out": [{"t": "Bạn không trả lời nữa. Nó gõ thêm đúng mười một tiếng, rồi mười một tiếng nữa, rồi thôi.\n\nSáng ra, trên nắp hầm có những vết cào sâu. Dưới bùn in dấu chân trần, mỗi bàn sáu ngón.", "fx": {"morale": -2}}]},
		],
	},
	"y_ta_doi_thuoc": {
		"title": "Người mặc áo blouse",
		"text": "Tiếng gõ gấp gáp.\n\n— Có ai không? Tôi là Hạnh, điều dưỡng bệnh viện quận. Tôi có thuốc. Tôi không xin ở nhờ, tôi chỉ cần đồ ăn. Hai phần đồ ăn, đổi một vỉ kháng sinh.",
		"choices": [
			{"t": "Ghé mắt nhìn qua khe nắp hầm", "info": true, "out": [{"t": "Một cô gái trẻ, áo blouse dính máu khô, đeo thẻ nhân viên. Cô ôm cái túi đỏ vào ngực và cứ ngoái lại phía sau. Mắt cô chớp liên tục vì nước mưa. Hơi thở phả ra thành khói."}]},
			{"t": "Hỏi: \"Trẻ sốt cao thì làm gì?\"", "info": true, "out": [{"t": "— Cháu nặng bao nhiêu cân? Chườm ấm ở nách với bẹn, đừng chườm đá. Hạ sốt theo cân nặng, bốn tiếng một lần. Sốt quá ba ngày phải có kháng sinh. — Cô nói một hơi, rồi sốt ruột. — Anh có đổi không?"}]},
			{"t": "Đổi hai phần đồ ăn lấy kháng sinh", "need": {"food": 2}, "out": [{"t": "Cô luồn một vỉ thuốc qua khe, nhận gói đồ ăn.\n\n— Hai viên một ngày, chia sáng tối. Giữ gìn nhé.\n\nCô đi, một mình, trong mưa.", "fx": {"food": -2, "med": {"khangsinh": 1}, "morale": 2}}]},
			{"t": "Mở cửa cho cô vào trú mưa", "out": [{"t": "Hạnh run cầm cập, ngồi nép ở chân thang. Cô xem mạch cho bé Na, thay băng cho bạn, chỉ Mai cách chườm. Gần sáng cô đi, để lại một vỉ thuốc trên kệ mà không đòi gì.", "fx": {"med": {"khangsinh": 1, "bang": 1}, "morale": 8}}]},
			{"t": "Không đổi", "out": [{"t": "— Tôi hiểu. — Giọng cô run. — Chúc nhà anh chị bình an.", "fx": {"morale": -3}}]},
		],
	},
	# ============================================================ ĐÊM 1: người mẹ
	"me_con": {
		"title": "Ba tiếng gõ khẽ",
		"text": "Nửa đêm. Có ai đó gõ lên nắp hầm, rất khẽ, như sợ chính tiếng gõ của mình.\n\n— Anh chị ơi… em là Thảo, ở dãy trọ đầu ngõ. Con em khát quá. Em chỉ xin một ngụm nước thôi, em không vào đâu.\n\nMai nhìn bạn. Bé Na đã ngủ.",
		"choices": [
			{"t": "Ghé mắt nhìn qua khe nắp hầm", "info": true, "out": [{"t": "Một người phụ nữ gầy, bế đứa bé chừng hai tuổi quấn trong áo mưa. Đứa bé thở khò khè. Tay chị ta run, hơi thở phả ra thành khói trong đêm lạnh. Chị liên tục ngoái nhìn về phía đầu ngõ."}]},
			{"t": "Đưa một chai nước qua khe cửa", "need": {"water": 1}, "out": [{"t": "Bạn hé nắp, chìa chai nước ra. Một bàn tay lạnh ngắt nắm lấy tay bạn, chỉ một giây.\n\n— Em không quên đâu.\n\nTiếng chân trần xa dần.", "fx": {"water": -1, "morale": 6, "later": {"in": 4, "ev": "thao_tra_on"}, "flag": "giup_thao"}}]},
			{"t": "Mở cửa cho hai mẹ con xuống ở cùng", "out": [{"t": "Thảo bế con leo xuống, không tin nổi vào mắt mình. Chị ngồi nép vào góc xa nhất, như sợ chiếm chỗ. Bé Bin uống xong thì ngủ ngay trên tay mẹ.\n\nThêm hai miệng ăn. Nhưng đêm nay căn hầm ấm hơn.", "fx": {"morale": 8, "guest": {"id": "thao", "name": "Chị Thảo và bé Bin", "kind": "mother"}, "flag": "giup_thao"}}]},
			{"t": "Im lặng, không trả lời", "out": [{"t": "Bạn đặt tay lên vai Mai, lắc đầu. Bên trên, người phụ nữ chờ thêm một lúc.\n\n— Em xin lỗi đã làm phiền.\n\nRồi không còn gì nữa. Mai quay mặt vào tường.", "fx": {"morale": -5}}]},
		],
	},
	"thao_tra_on": {
		"title": "Cái túi trước cửa hầm",
		"text": "Có tiếng sột soạt trên nắp hầm, rồi ba tiếng gõ khẽ. Cách gõ này bạn đã nghe một lần.\n\n— Em Thảo đây. Em để cái túi ở đây rồi đi ngay. Trong đó có ít đồ em nhặt được ở nhà thuốc.",
		"choices": [
			{"t": "Hé cửa, kéo cái túi xuống", "out": [{"t": "Một túi ni lông buộc chặt: hai gói lương khô, một vỉ kháng sinh còn nguyên, và mảnh giấy viết bằng bút chì kẻ mày: \"Bin hết khò khè rồi. Cảm ơn anh chị.\"", "fx": {"food": 2, "med": {"khangsinh": 1}, "morale": 8}}]},
			{"t": "Không mở. Đêm rồi.", "out": [{"t": "Bạn để yên. Sáng hôm sau cái túi vẫn nằm đó, ướt sương, đã bị thứ gì đó xé toạc. Chỉ còn mảnh giấy.", "fx": {"morale": -3}}]},
		],
	},
	# ============================================================ ĐÊM 2: giọng ông Tư
	"ong_tu_gia": {
		"title": "Giọng ông Tư",
		"text": "Trời mưa. Mười một tiếng gõ, đều tăm tắp.\n\n— Chú ơi. Bác Tư đây. Chú cầm cái xà beng của bác. Mở cửa cho bác lấy lại.\n\nĐúng là giọng ông Tư. Nhưng nhà ông hôm trước trống không, cửa mở toang, bát cơm còn trên bàn.",
		"choices": [
			{"t": "Ghé mắt nhìn qua khe nắp hầm", "info": true, "out": [{"t": "Ông Tư đứng ngay trên nắp hầm, thẳng đơ, hai tay buông xuôi. Mưa xối xả quanh ông, nhưng cái áo ông mặc khô nguyên.\n\nSuốt lúc bạn nhìn, ông không chớp mắt lần nào."}]},
			{"t": "Hỏi: \"Con Mực nhà bác đâu rồi?\"", "info": true, "out": [{"t": "Im lặng một nhịp.\n\n— Con Mực nhà bác đâu rồi.\n\nNó lặp lại đúng câu của bạn. Đúng cả giọng của bạn."}]},
			{"t": "Mở cửa cho ông Tư", "out": [
				{"p": 0.75, "t": "Nắp hầm vừa hé, thứ đó đổ ập xuống như không có xương. Mai hét lên. Bạn vớ được cái ghế, đập cho tới khi nó chui ngược ra ngoài, nhưng cánh tay bạn đã rách một đường dài và một thùng đồ ăn bị giẫm nát.", "fx": {"hp": -35, "bleed": true, "food": -1, "morale": -15, "flag": "biet_ke_nhai"}},
				{"p": 0.25, "t": "Nắp hầm vừa hé, một bàn tay dài quá khổ thò vào. Bạn sập nắp xuống bằng cả người. Có tiếng gì đó gãy. Nó rút đi, để lại ba ngón tay không có móng trên bậc thang.", "fx": {"hp": -10, "morale": -10, "flag": "biet_ke_nhai"}},
			]},
			{"t": "Không mở. Chặn thêm thanh sắt.", "out": [{"t": "Bạn không trả lời nữa. Nó gõ thêm đúng mười một tiếng, rồi mười một tiếng nữa, rồi thôi.\n\nSáng ra, trên nắp hầm có những vết cào sâu. Dưới bùn in dấu chân trần, mỗi bàn sáu ngón.", "fx": {"morale": -2, "flag": "biet_ke_nhai"}}]},
		],
		"after": {"later": {"in": 3, "ev": "ong_tu_that"}},
	},
	"ong_tu_that": {
		"title": "Ba tiếng gõ ngắt quãng",
		"text": "Gõ. Nghỉ. Gõ gõ. Như người đã hết sức.\n\n— Chú… có nhà không chú. Bác… bác Tư đây. Bác không xin gì nhiều. Cho bác ngồi nhờ một góc.\n\nMai níu tay bạn: \"Đêm trước nó cũng nói giọng này.\"",
		"choices": [
			{"t": "Ghé mắt nhìn qua khe nắp hầm", "info": true, "out": [{"t": "Một ông già ngồi bệt trên nắp hầm, lưng còng, thở dốc. Hơi thở phả khói. Cánh tay trái quấn bằng cái áo rách, máu thấm ra đen. Tay kia nắm chặt một cái vòng cổ chó bằng da."}]},
			{"t": "Hỏi: \"Con Mực nhà bác đâu rồi?\"", "info": true, "out": [{"t": "Ông im rất lâu.\n\n— Nó sủa cho bác chạy. — Giọng ông vỡ ra. — Bác chạy. Bác không quay lại được, chú ạ."}]},
			{"t": "Mở cửa, dìu ông xuống", "out": [{"t": "Ông Tư nặng hơn bạn tưởng, người lạnh như đá. Mai xé vải băng lại tay cho ông. Ông nhìn quanh căn hầm, nhìn cái radio rè rè trên bàn.\n\n— Để mai bác xem cái đài cho. Ngày xưa bác sửa đài cho cả phố này.", "fx": {"morale": 10, "guest": {"id": "ong_tu", "name": "Ông Tư", "kind": "fixer"}, "later": {"in": 1, "ev": "ong_tu_sua_dai"}}}]},
			{"t": "Không mở. Không thể liều lần nữa.", "out": [{"t": "— Ừ. Chú làm thế là phải. — Ông nói, rất nhỏ. — Giữ lấy vợ con.\n\nBạn nghe tiếng ông ngồi xuống. Rồi chỉ còn tiếng mưa.", "fx": {"morale": -6, "later": {"in": 1, "ev": "ong_tu_chet"}}}]},
		],
	},
	"ong_tu_sua_dai": {
		"title": "Cái đài của ông Tư",
		"text": "Ông Tư tháo tung cái radio bằng một cái thìa và con dao gọt hoa quả. Đến nửa đêm, tiếng rè biến mất.\n\n— Bác bắt được sóng của bộ đội rồi. Bác gõ được cho họ biết số nhà mình.",
		"choices": [
			{"t": "Để ông gõ tín hiệu", "out": [{"t": "Ông gõ rất lâu, từng nhịp một. Rồi cái đài trả lời: ba tiếng bíp.\n\n— Họ ghi nhận rồi. Nhà mình vào lượt đầu.\n\nCứu hộ sẽ đến sớm hơn một ngày.", "fx": {"rescue": -1, "morale": 12, "flag": "dai_tot"}}]},
		],
	},
	"ong_tu_chet": {
		"title": "Sáng hôm sau",
		"text": "Không có tiếng gõ nào đêm nay. Gần sáng, bạn hé nắp hầm.\n\nÔng Tư vẫn ngồi đó, lưng tựa vào tường nhà bạn, mắt nhắm. Trong tay ông là cái vòng cổ của con Mực. Ông thật. Lần này là ông thật.",
		"choices": [
			{"t": "Phủ tấm chăn lên người ông", "out": [{"t": "Bạn kéo ông vào hiên, phủ chăn lại. Mai không nói gì suốt buổi sáng. Bé Na hỏi ông Tư đi đâu rồi.", "fx": {"morale": -16, "flag": "ong_tu_mat"}}]},
		],
	},
	# ============================================================ ĐÊM 3: cô y tá
	"y_ta": {
		"title": "Người mặc áo blouse",
		"text": "Bé Na sốt từ sáng, giờ đã mê man. Giữa lúc đó có tiếng gõ gấp gáp.\n\n— Có ai không? Tôi là Hạnh, điều dưỡng bệnh viện quận. Tôi có túi cứu thương. Cho tôi trú một đêm, tôi xem bệnh cho người nhà anh chị.\n\nMai đã đứng dậy trước khi bạn kịp nói gì.",
		"choices": [
			{"t": "Ghé mắt nhìn qua khe nắp hầm", "info": true, "out": [{"t": "Một cô gái trẻ, áo blouse dính máu khô, đeo thẻ nhân viên. Cô ôm cái túi đỏ vào ngực và cứ ngoái lại phía sau. Mắt cô chớp liên tục vì nước mưa."}]},
			{"t": "Hỏi: \"Trẻ sáu tuổi sốt 39 độ thì làm gì?\"", "info": true, "out": [{"t": "— Cháu nặng bao nhiêu cân? Có co giật không? Chườm ấm ở nách với bẹn, đừng chườm đá. Hạ sốt theo cân nặng, bốn tiếng một lần. Nếu sốt quá ba ngày phải có kháng sinh, tôi còn một ít. — Cô nói một hơi, rồi sốt ruột. — Cháu đang sốt à? Mở cửa đi anh!"}]},
			{"t": "Mở cửa cho cô Hạnh", "out": [{"t": "Hạnh quỳ xuống bên bé Na trước cả khi cởi áo mưa. Cô đo nhiệt, chườm, bóp một viên thuốc hoà vào nước.\n\n— Tôi ở lại canh cháu. Anh chị ngủ đi.\n\nCô để vỉ kháng sinh còn lại lên kệ.", "fx": {"morale": 10, "med": {"khangsinh": 1}, "guest": {"id": "hanh", "name": "Cô Hạnh", "kind": "nurse"}}}]},
			{"t": "Đổi hai phần đồ ăn lấy thuốc qua khe cửa", "need": {"food": 2}, "out": [{"t": "Cô ngập ngừng, rồi luồn một vỉ thuốc qua khe.\n\n— Hai viên một ngày, chia sáng tối. — Cô nhận gói đồ ăn. — Chúc cháu mau khỏi.\n\nCô đi, một mình, trong mưa.", "fx": {"food": -2, "med": {"khangsinh": 1}, "morale": -2}}]},
			{"t": "Không mở", "out": [{"t": "— Tôi hiểu. — Giọng cô run. — Chườm ấm cho cháu. Đừng chườm đá.\n\nMai nhìn bạn như nhìn người lạ.", "fx": {"morale": -8}}]},
		],
	},
	# ============================================================ CÁC ĐÊM NGẪU NHIÊN
	"ban_thuoc": {
		"title": "Người bán thuốc",
		"text": "Tiếng gõ bằng vật cứng, như nhẫn gõ lên sắt.\n\n— Kháng sinh đây. Hàng hộp, còn hạn. Ba phần đồ ăn một hộp. Không mặc cả, không mở cửa cũng được, đưa qua khe.",
		"choices": [
			{"t": "Đòi xem hộp thuốc qua khe", "info": true, "out": [{"t": "Hắn giơ cái hộp lên, nhưng giữ cách khe cửa cả sải tay. Dưới ánh đèn pin, tem niêm phong trông như được dán lại. Hắn thu hộp về rất nhanh."}]},
			{"t": "Đổi ba phần đồ ăn", "need": {"food": 3}, "out": [
				{"p": 0.55, "t": "Hộp thuốc thật. Hai vỉ nguyên. Hắn đếm lại đồ ăn hai lần rồi mới đi.", "fx": {"food": -3, "med": {"khangsinh": 2}, "morale": 4}},
				{"p": 0.45, "t": "Bạn bóc hộp ra. Bên trong là mười viên phấn nặn tròn, lăn bột mì. Trên kia, tiếng cười khẽ xa dần.", "fx": {"food": -3, "morale": -8}},
			]},
			{"t": "\"Một phần thôi. Đưa trước nửa hộp.\"", "need": {"food": 1}, "out": [
				{"p": 0.5, "t": "Hắn chửi thề, nhưng luồn một vỉ thuốc xuống. Thuốc thật.", "fx": {"food": -1, "med": {"khangsinh": 1}}},
				{"p": 0.5, "t": "— Thế thì để con mày tự khỏi. — Hắn nhổ nước bọt lên nắp hầm rồi đi.", "fx": {"morale": -2}},
			]},
			{"t": "Đuổi hắn đi", "out": [{"t": "Hắn gõ thêm hai tiếng, nhún vai với bóng tối, rồi sang gõ nhà khác.", "fx": {}}]},
		],
	},
	"cuop": {
		"title": "Ba gã đàn ông",
		"text": "Không gõ. Chúng đập.\n\n— Biết dưới này có người rồi! Khói bếp bốc lên từ ống thông hơi kia kìa. Tuồn đồ ăn lên, không thì bọn tao đổ xăng xuống.\n\nBé Na giật mình khóc. Mai bịt miệng con.",
		"choices": [
			{"t": "Im lặng, tắt đèn, chờ", "out": [
				{"p": 0.5, "t": "Chúng đập thêm một lúc. Một đứa bảo: \"Chắc chết cả rồi.\" Tiếng chân bỏ đi.", "fx": {"morale": -2}},
				{"p": 0.5, "t": "Mùi xăng. Rồi khói tràn xuống qua ống thông hơi. Bạn dùng nước dập, cả nhà ho sặc sụa đến sáng. Chúng bỏ đi khi không thấy ai chui lên.", "fx": {"water": -1, "morale": -10}},
			]},
			{"t": "Tuồn hai phần đồ ăn lên", "need": {"food": 2}, "out": [{"t": "Bạn đẩy hai gói lên qua khe. Một bàn tay giật lấy.\n\n— Khôn đấy. Mai bọn tao lại ghé.\n\nChúng cười, rồi đi.", "fx": {"food": -2, "morale": -4, "later": {"in": 2, "ev": "cuop_lai"}}}]},
			{"t": "Lên đạn thật to rồi nói vọng lên", "need": {"item": "sungluc"}, "out": [
				{"p": 0.8, "t": "Tiếng khoá nòng lách cách vang trong hầm. Bên trên im bặt.\n\n— Nó có súng. Đi.\n\nChúng chạy.", "fx": {"morale": 6}},
				{"p": 0.2, "t": "Một đứa cũng có súng. Nó bắn hai phát qua nắp hầm. Mảnh sắt văng vào vai bạn trước khi bạn bắn trả và chúng bỏ chạy.", "fx": {"hp": -25, "bleed": true, "morale": -6}},
			]},
			{"t": "Doạ: \"Tao có súng!\" (nói dối)", "out": [
				{"p": 0.4, "t": "Chúng lưỡng lự. Rồi bỏ đi, vừa đi vừa chửi.", "fx": {"morale": 2}},
				{"p": 0.6, "t": "— Có thì bắn đi! — Chúng cười, lấy xà beng nạy ống thông hơi, thò sào xuống khều mất một thùng đồ trước khi bạn kịp giật lại.", "fx": {"food": -1, "water": -1, "morale": -6}},
			]},
		],
	},
	"cuop_lai": {
		"title": "\"Mai bọn tao lại ghé\"",
		"text": "Chúng giữ lời. Lần này có năm đứa.\n\n— Lần trước ngoan lắm. Lần này gấp đôi.",
		"choices": [
			{"t": "Đưa bốn phần đồ ăn", "need": {"food": 4}, "out": [{"t": "Bạn đưa. Chúng sẽ còn quay lại, bạn biết thế.", "fx": {"food": -4, "morale": -8}}]},
			{"t": "Lên đạn", "need": {"item": "sungluc"}, "out": [{"t": "Một phát chỉ thiên qua ống thông hơi. Năm đứa chạy tán loạn. Chúng sẽ không quay lại nữa.", "fx": {"morale": 8}}]},
			{"t": "Từ chối. Chặn cửa.", "out": [
				{"p": 0.5, "t": "Chúng đập đến gần sáng. Nắp hầm méo đi nhưng không bung. Tiếng một con gì đó rất lớn bước qua đầu ngõ làm chúng bỏ chạy.", "fx": {"morale": -6}},
				{"p": 0.5, "t": "Chúng nạy được một góc nắp hầm. Bạn giằng co với chúng qua khe hở, ăn một gậy vào đầu, nhưng giữ được cửa.", "fx": {"hp": -22, "morale": -8}},
			]},
		],
	},
	"tieng_tre_khoc": {
		"title": "Tiếng trẻ con khóc",
		"text": "— Mẹ ơi… mẹ ơi… con lạnh…\n\nTiếng một đứa bé, ngay trên nắp hầm. Mai bật dậy.\n\n— Anh, có đứa bé ngoài kia! Nó bằng tuổi con Na!",
		"choices": [
			{"t": "Lắng nghe thật kỹ", "info": true, "out": [{"t": "Bạn đếm. Tiếng khóc dài bảy giây. Nghỉ hai giây. Rồi lặp lại, y hệt, từng tiếng nấc ở đúng chỗ cũ.\n\nNó không lấy hơi lần nào."}]},
			{"t": "Mở cửa", "out": [{"t": "Mai mở nắp trước khi bạn kịp ngăn. Không có đứa bé nào. Thứ đứng đó cao gần chạm mái hiên, và nó vẫn đang khóc bằng giọng trẻ con khi vươn tay xuống.\n\nBạn kéo được Mai lại, nhưng cô ấy bị nó quệt trúng vai.", "fx": {"hp": -18, "hurt": "mai", "morale": -14, "flag": "biet_ke_nhai"}}]},
			{"t": "Giữ chặt Mai lại", "out": [{"t": "Bạn ôm ghì lấy vợ. Cô ấy đấm vào ngực bạn, rồi khóc. Tiếng trẻ con bên trên kéo dài đến gần sáng, không sai một nhịp.\n\nSáng ra Mai không nói với bạn câu nào.", "fx": {"morale": -7, "flag": "biet_ke_nhai"}}]},
		],
	},
	"linh_dao_ngu": {
		"title": "Người lính",
		"text": "— Mở cửa. Quân đội đây. — Một giọng đàn ông trẻ, hụt hơi. Rồi nhỏ hơn: — Làm ơn. Tôi bị thương. Tôi có súng, tôi có thể canh cho gia đình anh.",
		"choices": [
			{"t": "Ghé mắt nhìn qua khe nắp hầm", "info": true, "out": [{"t": "Một cậu lính chừng hai mươi, quân phục rách, khẩu súng trường đeo chéo lưng. Cậu ta ôm bụng, máu chảy qua kẽ tay. Phù hiệu đơn vị trên vai áo đã bị xé đi."}]},
			{"t": "Hỏi: \"Đơn vị của cậu đâu?\"", "info": true, "out": [{"t": "— Chết hết rồi. — Cậu ta nói nhanh quá. Rồi chậm lại: — Không. Tôi bỏ chạy. Chúng nó vẫn bắn, còn tôi bỏ chạy. Anh muốn nghe thế chứ gì."}]},
			{"t": "Cho cậu ta xuống", "out": [{"t": "Cậu lính tên Khoa. Cậu ngủ ngồi, tựa lưng vào thang hầm, súng trong lòng. Trước khi ngủ, cậu tháo băng đạn đưa cho bạn.\n\n— Anh giữ đi. Để anh yên tâm.", "fx": {"morale": 4, "guest": {"id": "khoa", "name": "Khoa (lính)", "kind": "soldier"}, "bag": {"bangdan": 1}, "later": {"in": 2, "ev": "linh_bi_tim"}}}]},
			{"t": "Đổi ba phần đồ ăn lấy khẩu súng", "need": {"food": 3}, "out": [{"t": "Khoa nhìn khẩu súng rất lâu, rồi luồn nó qua khe cùng một băng đạn.\n\n— Đằng nào tôi cũng không bắn nổi nữa.\n\nCậu ta ôm gói đồ ăn, lết đi.", "fx": {"food": -3, "bag": {"sungluc": 1, "bangdan": 1}}}]},
			{"t": "Không mở", "out": [{"t": "— Ừ. — Cậu ta nói. — Tôi cũng sẽ không mở.\n\nBạn nghe tiếng báng súng kéo lê trên mặt đường, xa dần.", "fx": {"morale": -3}}]},
		],
	},
	"linh_bi_tim": {
		"title": "Đội tuần tra",
		"text": "Ban ngày. Tiếng giày đinh, tiếng bộ đàm. Người thật.\n\n— Gia đình dưới hầm chú ý. Chúng tôi tìm một quân nhân bỏ vị trí, mang theo vũ khí. Có ai thấy không?\n\nKhoa nhìn bạn. Cậu ta không xin gì cả.",
		"need": {"guest": "khoa"},
		"choices": [
			{"t": "Giao Khoa cho họ", "out": [{"t": "Khoa tự leo lên, không để ai phải kéo. Viên chỉ huy để lại hai hộp lương khô \"vì đã hợp tác\".\n\nBé Na hỏi chú Khoa có bị phạt không. Bạn không biết trả lời thế nào.", "fx": {"unguest": "khoa", "food": 2, "morale": -10}}]},
			{"t": "\"Không thấy ai cả.\"", "out": [
				{"p": 0.7, "t": "Họ đứng thêm một lúc rồi đi. Khoa thở ra, lần đầu tiên từ hôm qua.\n\n— Tôi nợ anh.", "fx": {"morale": 6, "flag": "che_khoa"}},
				{"p": 0.3, "t": "Họ không tin. Họ xuống lục soát, lôi Khoa đi, và tịch thu hai phần đồ ăn \"vì che giấu\".", "fx": {"unguest": "khoa", "food": -2, "morale": -8}},
			]},
		],
	},
	"ba_sau": {
		"title": "Bà Sáu bán xôi",
		"text": "— Thằng Hưng có nhà không con? Bà Sáu đây. Bà còn cái bánh chưng, ăn một mình không hết. Cho bà ngồi nhờ tới sáng, bà sợ quá.\n\nBà Sáu bán xôi đầu ngõ hai mươi năm nay. Bà gọi bạn bằng cái tên chỉ người trong ngõ mới gọi.",
		"choices": [
			{"t": "Hỏi: \"Bà ơi, xôi lạc hay xôi đỗ?\"", "info": true, "out": [{"t": "— Cha bố anh. Sáng nào cũng xôi lạc, thêm ruốc, không hành. Hai mươi năm rồi còn hỏi.\n\nBà cười, rồi ho."}]},
			{"t": "Mở cửa đón bà", "out": [{"t": "Bà Sáu ngồi cạnh bé Na cả đêm, kể chuyện cái ngõ này hồi chưa có nhà tầng. Sáng ra bà nhất định đòi về \"trông cái nồi\". Bà để lại cả cái bánh chưng.", "fx": {"food": 3, "morale": 10}}]},
			{"t": "Không mở", "out": [{"t": "— Ừ, thôi, bà hiểu. — Bà để lại thứ gì đó trên nắp hầm rồi đi.\n\nSáng ra bạn thấy một phần tư cái bánh chưng, gói lại cẩn thận trong lá.", "fx": {"food": 1, "morale": -6}}]},
		],
	},
	"anh_dung": {
		"title": "Anh Dũng phòng kế toán",
		"text": "— Hưng! Dũng đây, Dũng kế toán đây! Tao biết chỗ tập kết rồi, ở sân vận động, có xe tải, có lính. Đi ngay bây giờ, sáng ra là hết chỗ!\n\nĐúng giọng anh Dũng. Sáng hôm xảy ra chuyện anh ấy còn ngồi cách bạn hai bàn.",
		"choices": [
			{"t": "Ghé mắt nhìn qua khe nắp hầm", "info": true, "out": [{"t": "Anh Dũng, đúng là anh Dũng, vẫn cái áo sơ mi kẻ. Anh thở hồng hộc, chớp mắt, quệt mồ hôi. Người thật.\n\nNhưng phía cuối ngõ, trong bóng tối, có hai đốm thuốc lá đỏ đang đứng yên."}]},
			{"t": "Hỏi: \"Radio bảo cứu hộ chỉ đến ban ngày mà?\"", "info": true, "out": [{"t": "— Thì… thì đấy là đài nói thế. — Anh ta liếc về cuối ngõ. — Mày cứ ra đây đã. Mang đồ ăn theo, đường xa."}]},
			{"t": "Đi theo anh Dũng", "out": [
				{"p": 0.7, "t": "Chưa ra khỏi ngõ, hai gã lạ chặn đầu. Anh Dũng không nhìn vào mắt bạn.\n\n— Tao xin lỗi. Chúng nó giữ vợ tao.\n\nChúng lột sạch đồ bạn mang theo và nện bạn một trận.", "fx": {"hp": -24, "bag_clear": true, "morale": -8}},
				{"p": 0.3, "t": "Hai gã cuối ngõ thấy bạn cầm đồ thì chùn lại. Anh Dũng kéo bạn tới một cái xe tải lật, chỉ vào thùng xe.\n\n— Tao chỉ chỗ này cho mày. Coi như tao trả nợ.\n\nRồi anh ta chạy mất.", "fx": {"bag": {"luongkho": 2, "nuocsuoi": 2}, "morale": 2}},
			]},
			{"t": "\"Anh xuống đây đi, đừng đi đâu cả.\"", "out": [{"t": "Anh ta lùi lại.\n\n— Không… không được. Tao phải đi.\n\nAnh ta nhìn bạn thêm một giây, mấp máy môi: \"Đừng ra.\" Rồi chạy về phía hai đốm thuốc lá.", "fx": {"morale": -2}}]},
			{"t": "Không trả lời", "out": [{"t": "Anh ta gọi thêm vài câu. Có tiếng ai đó chửi, tiếng một cái tát. Rồi im.", "fx": {"morale": -3}}]},
		],
	},
	"mua_ngap": {
		"title": "Đêm mưa",
		"text": "Không ai gõ cửa đêm nay. Chỉ có mưa.\n\nNước bắt đầu rỉ qua mép nắp hầm, chảy thành dòng xuống bậc thang, lan về phía chỗ để đồ ăn.",
		"choices": [
			{"t": "Lấy chăn chặn khe cửa", "out": [{"t": "Hai cái chăn ướt sũng, nhưng nước dừng lại. Cả nhà ngủ co ro không chăn, bé Na ho suốt đêm.", "fx": {"morale": -5}}]},
			{"t": "Thức cả đêm tát nước", "out": [{"t": "Bạn tát từng ca một cho tới sáng. Đồ đạc khô ráo. Tay bạn phồng rộp, lưng không đứng thẳng nổi.", "fx": {"hp": -8, "morale": 2}}]},
			{"t": "Hứng nước mưa vào can", "out": [
				{"p": 0.6, "t": "Bạn kê can dưới chỗ rỉ. Sáng ra được gần đầy hai phần nước, hơi đục nhưng uống được. Một thùng mì thì ướt nhũn.", "fx": {"water": 2, "food": -1}},
				{"p": 0.4, "t": "Bạn kê can dưới chỗ rỉ. Sáng ra được hai phần nước và không mất gì cả.", "fx": {"water": 2}},
			]},
		],
	},
	"may_phat": {
		"title": "Giọng người chỉ huy",
		"text": "Một tiếng \"cạch\" trên nắp hầm, như vật gì rơi xuống. Rồi tiếng loa rè:\n\n— Đây là lực lượng cứu hộ. Yêu cầu các gia đình mở cửa hầm để điểm danh. Đây là lực lượng cứu hộ. Yêu cầu các gia đình mở cửa hầm để điểm danh.",
		"choices": [
			{"t": "Nhớ lại bản tin radio", "info": true, "out": [{"t": "\"Chúng tôi chỉ đến vào ban ngày. Sau khi trời tối, không mở cửa cho bất kỳ ai.\"\n\nBây giờ là hai giờ sáng."}]},
			{"t": "Ghé mắt nhìn qua khe nắp hầm", "info": true, "out": [{"t": "Không có ai cầm loa. Không có cái loa nào. Chỉ có một cái bóng rất cao đứng ở đầu ngõ, miệng mở, và giọng nói đi ra từ đó."}]},
			{"t": "Mở cửa điểm danh", "out": [{"t": "Bạn đẩy nắp hầm lên. Giọng nói ngừng giữa chừng. Cái bóng ở đầu ngõ quay lại, và chạy về phía bạn bằng cả bốn chi.\n\nBạn sập nắp kịp. Gần như kịp.", "fx": {"hp": -28, "bleed": true, "morale": -10, "flag": "biet_ke_nhai"}}]},
			{"t": "Ngồi im", "out": [{"t": "Câu nói lặp lại bốn mươi hai lần. Bạn đếm. Rồi ngừng, giữa một chữ.", "fx": {"flag": "biet_ke_nhai"}}]},
		],
	},
	"vali": {
		"title": "Người đàn ông và cái vali",
		"text": "— Xin lỗi đã làm phiền lúc khuya. — Một giọng nhã nhặn, phát âm rõ từng chữ. — Tôi có năm chai nước. Tôi đổi cả năm lấy một chỗ nằm đến sáng. Sáng tôi đi.",
		"choices": [
			{"t": "Ghé mắt nhìn qua khe nắp hầm", "info": true, "out": [{"t": "Một người đàn ông trung niên, sơ mi trắng, cái vali kéo đứng bên cạnh. Giày ông ta lấm bùn tới ống quần. Cái vali thì sạch bong, không một vết xước."}]},
			{"t": "Cho ông ta xuống", "out": [
				{"p": 0.5, "t": "Ông ta nằm quay mặt vào tường, cái vali kê dưới đầu. Sáng ra ông ta đã đi. Năm chai nước để ngay ngắn trên bàn.\n\nKệ đồ ăn thiếu mất hai phần.", "fx": {"water": 5, "food": -2, "morale": -3}},
				{"p": 0.5, "t": "Ông ta nằm quay mặt vào tường. Sáng ra ông ta gấp chăn, để lại năm chai nước và một tấm danh thiếp: bác sĩ thú y.\n\n— Con chó nào cào cửa nhà anh chị thì cứ cho vào. Chó không bắt chước được.", "fx": {"water": 5, "morale": 4, "flag": "meo_cho"}},
			]},
			{"t": "\"Đưa nước qua khe trước đã.\"", "out": [{"t": "— Thế thì tôi còn gì để đổi nữa? — Ông ta cười khẽ, nhấc vali lên. — Chúc gia đình ngủ ngon.", "fx": {}}]},
			{"t": "Không mở", "out": [{"t": "Tiếng bánh xe vali lăn trên mặt đường nứt, đều đều, xa dần.", "fx": {}}]},
		],
	},
	"con_muc": {
		"title": "Tiếng cào cửa",
		"text": "Không phải tiếng gõ. Tiếng cào, và tiếng rên ư ử.\n\nBé Na ngồi bật dậy: \"Con Mực! Bố ơi, con Mực nhà ông Tư!\"",
		"choices": [
			{"t": "Ghé mắt nhìn qua khe nắp hầm", "info": true, "out": [{"t": "Một con chó đen, gầy trơ xương, một chân sau co lên. Nó dí mũi vào khe cửa, ngửi, rồi vẫy đuôi yếu ớt. Cái vòng cổ đã mất."}]},
			{"t": "Cho con Mực xuống", "out": [{"t": "Con Mực lết xuống thang, liếm tay bé Na, rồi nằm chắn ngay chân thang, mặt quay ra cửa.\n\nTừ giờ, mỗi khi có thứ gì không phải người đứng ngoài kia, nó sẽ biết trước bạn.", "fx": {"morale": 12, "guest": {"id": "muc", "name": "Con Mực", "kind": "dog"}}}]},
			{"t": "Không mở. Không nuôi nổi thêm.", "out": [{"t": "Nó cào thêm một lúc, rồi nằm xuống ngay trên nắp hầm. Bé Na khóc tới khi ngủ thiếp đi.\n\nSáng ra nó không còn ở đó nữa.", "fx": {"morale": -9}}]},
		],
	},
	# ============================================================ ĐÊM CUỐI
	"dem_cuoi": {
		"title": "Đêm cuối cùng",
		"text": "Chúng đến tất cả cùng một lúc.\n\nGiọng ông Tư. Giọng người mẹ bế con. Giọng anh Dũng. Giọng một đứa trẻ. Giọng của chính Mai, vọng xuống từ bên trên, trong khi Mai đang ngồi ngay cạnh bạn, tay lạnh ngắt.\n\n— Mở cửa đi anh. Em ở ngoài này. Người ngồi cạnh anh không phải em đâu.",
		"choices": [
			{"t": "Nắm tay Mai, hỏi điều chỉ hai người biết", "info": true, "out": [{"t": "— Hôm cưới, em khóc vì cái gì?\n\nMai bật cười trong nước mắt.\n\n— Vì anh đi nhầm giày của bố em. Hai chiếc khác nhau.\n\nBên trên, giọng nói kia lặp lại: \"Hôm cưới, em khóc vì cái gì.\""}]},
			{"t": "Ôm vợ con, ngồi im tới sáng", "out": [
				{"p": 0.8, "t": "Bạn bịt tai bé Na. Mai bịt tai bạn. Những giọng nói cào vào cửa hầm suốt sáu tiếng đồng hồ, gọi tên từng người, hứa, doạ, khóc.\n\nRồi trời sáng. Và có tiếng động cơ.", "fx": {"morale": 6}},
				{"p": 0.2, "t": "Gần sáng, bản lề nắp hầm bật một bên. Bạn lấy lưng đỡ lấy nắp hầm cho tới khi nắng lên, vai nát bấy.\n\nRồi có tiếng động cơ.", "fx": {"hp": -30, "morale": 2}},
			]},
			{"t": "Bắn qua nắp hầm", "need": {"item": "sungluc"}, "out": [{"t": "Ba phát. Những giọng nói im bặt, rồi rú lên bằng thứ tiếng không còn giống người. Chúng lùi ra đầu ngõ, đứng đó, chờ.\n\nNhưng trời đã sáng dần. Và có tiếng động cơ.", "fx": {"morale": 8}}]},
			{"t": "Mở cửa", "out": [{"t": "Bạn không biết tại sao mình lại đặt tay lên chốt cửa. Có lẽ vì giọng nói kia giống Mai quá.\n\nMai, Mai thật, giật tay bạn lại, nhưng cái nắp đã hé.", "fx": {"hp": -45, "bleed": true, "hurt": "mai", "morale": -20}}]},
		],
	},
	# ============================================================ NGOÀI PHỐ, BAN ĐÊM
	"o_dot_lua": {
		"title": "Đống lửa giữa ngã tư",
		"text": "Ba gã ngồi quanh một cái thùng phuy đang cháy. Một đứa thấy ánh đèn pin của bạn trước khi bạn kịp tắt.\n\n— Ê. Đứng lại. Túi có gì, bỏ xuống.",
		"choices": [
			{"t": "Bỏ lại đồ ăn trong túi rồi lùi đi", "out": [{"t": "Bạn đặt đồ ăn xuống đất, lùi từng bước. Chúng không đuổi.\n\n— Lần sau đi đường khác.", "fx": {"bag_food": true, "morale": -3}}]},
			{"t": "Giơ vũ khí lên", "need": {"weapon": true}, "out": [
				{"p": 0.6, "t": "Chúng nhìn thứ bạn cầm, nhìn nhau. Một đứa nhổ nước bọt.\n\n— Thôi. Không đáng.\n\nChúng để bạn đi.", "fx": {"morale": 3}},
				{"p": 0.4, "t": "Hai đứa xông vào. Bạn quật ngã được một, ăn một gậy vào sườn, rồi chạy thoát.", "fx": {"hp": -22, "morale": -2}},
			]},
			{"t": "Tắt đèn, bỏ chạy", "out": [
				{"p": 0.55, "t": "Bạn lao vào một con hẻm tối, nín thở sau đống đổ nát. Chúng chạy qua, chửi rủa, rồi quay về bên đống lửa.", "fx": {}},
				{"p": 0.45, "t": "Bạn vấp ngã trong bóng tối. Chúng bắt kịp, lột một nửa số đồ, đá thêm vài cái cho bõ tức.", "fx": {"hp": -15, "bag_half": true}},
			]},
			{"t": "\"Tôi có con nhỏ đang sốt.\"", "out": [
				{"p": 0.35, "t": "Gã lớn tuổi nhất nhìn bạn rất lâu. Rồi hắn ném cho bạn một hộp thuốc.\n\n— Tao cũng từng có. Đi đi.", "fx": {"bag": {"khangsinh": 1}, "morale": 6}},
				{"p": 0.65, "t": "— Ai mà chẳng có. — Chúng cười. — Bỏ túi xuống.\n\nBạn mất một nửa số đồ.", "fx": {"bag_half": true, "morale": -4}},
			]},
		],
	},
	"o_ong_ba": {
		"title": "Hai ông bà già",
		"text": "Căn nhà này tưởng bỏ hoang. Nhưng trong góc bếp, sau cái tủ lạnh, có hai người già ngồi ôm nhau. Bà cụ che mắt trước ánh đèn pin.\n\n— Cậu ơi… tủ còn mấy gói mì với ít thuốc của ông ấy. Cậu lấy gì thì lấy, để lại cho chúng tôi một ít. Ông ấy không đi được nữa.",
		"choices": [
			{"t": "Xin lỗi rồi đi ra, không lấy gì", "out": [{"t": "Bạn tắt đèn, cúi đầu. Ra tới cửa thì ông cụ gọi với theo, giọng khàn:\n\n— Cậu gì ơi. Nhà thuốc chỗ ngã ba, sau quầy có cái két không khoá. Chúng tôi không dùng tới nữa.", "fx": {"morale": 8, "bag": {"khangsinh": 1}, "flag": "ong_ba_tu_te"}}]},
			{"t": "Lấy một nửa", "out": [{"t": "Bạn chia đôi, cẩn thận, trước mặt họ. Bà cụ gật đầu, không nói gì. Ông cụ thì nhìn bạn suốt, không chớp.", "fx": {"bag": {"mitom": 2, "giamdau": 1}, "morale": -3, "cruelty": 8}}]},
			{"t": "Lấy hết. Nhà mình cũng có trẻ con.", "out": [{"t": "Bạn vét sạch cái tủ. Bà cụ không khóc. Bà chỉ kéo chăn lên cho ông, như thể bạn đã đi rồi.\n\nRa tới đường, bạn thấy cái túi nặng hơn nó phải nặng.", "fx": {"bag": {"mitom": 4, "giamdau": 2, "nuocsuoi": 1}, "morale": -10, "cruelty": 25}}]},
			{"t": "Để lại cho họ một chai nước", "need": {"bag_item": "nuocsuoi"}, "out": [{"t": "Bà cụ cầm chai nước bằng cả hai tay.\n\n— Cậu có con nhỏ phải không? Nhìn là biết. — Bà dúi vào tay bạn một vỉ thuốc và cái bùa hộ mệnh bằng vải đỏ. — Cho cháu.", "fx": {"bag": {"nuocsuoi": -1, "khangsinh": 1}, "morale": 12, "flag": "ong_ba_tu_te"}}]},
		],
	},
	"o_nguoi_ket": {
		"title": "Tiếng gõ dưới đống đổ nát",
		"text": "Cốc. Cốc cốc. Từ dưới một mảng tường sập.\n\n— Có ai không… chân tôi kẹt… ba ngày rồi…\n\nGiọng đàn ông, yếu lắm. Nâng mảng tường này lên sẽ rất ồn.",
		"choices": [
			{"t": "Soi đèn qua khe hở", "info": true, "out": [{"t": "Một khuôn mặt bám đầy bụi vôi, mắt nheo lại vì chói. Môi nứt nẻ. Anh ta giơ một bàn tay run rẩy lên che mắt. Người thật."}]},
			{"t": "Dùng xà beng bẩy mảng tường", "need": {"bag_item": "xabeng"}, "out": [
				{"p": 0.7, "t": "Mảng tường nhấc lên với một tiếng rầm vang cả phố. Anh ta lết ra, chân tím bầm.\n\n— Tôi là thợ điện. Tôi biết chỗ kho của công ty, còn nguyên.\n\nAnh ta dúi cho bạn tất cả những gì còn trong túi áo.", "fx": {"bag": {"luongkho": 2, "nuocsuoi": 1}, "morale": 10, "noise": true}},
				{"p": 0.3, "t": "Mảng tường nhấc lên. Tiếng rầm vang cả phố, và có thứ gì đó ở xa trả lời. Anh ta lết ra, cảm ơn bạn, rồi cả hai chạy mỗi người một ngả.", "fx": {"morale": 8, "noise": true}},
			]},
			{"t": "Luồn cho anh ta một chai nước rồi đi", "need": {"bag_item": "nuocsuoi"}, "out": [{"t": "Bạn luồn chai nước qua khe. Tiếng uống ừng ực.\n\n— Cảm ơn. Thế là đủ rồi. Anh đi đi, kẻo chúng nghe thấy.", "fx": {"bag": {"nuocsuoi": -1}, "morale": 3}}]},
			{"t": "Bỏ đi. Không thể gây ồn.", "out": [{"t": "Bạn bước lùi lại. Tiếng gõ đuổi theo bạn một quãng. Cốc. Cốc cốc.", "fx": {"morale": -6}}]},
		],
	},
	"o_xe_hang": {
		"title": "Người đẩy xe hàng",
		"text": "Một người đàn bà đẩy cái xe hàng rong, bánh xe quấn giẻ cho đỡ kêu. Trên xe có can nước, mì, thuốc lá, pin.\n\n— Đổi không? Tôi không lấy tiền. Tiền giờ để chùi.",
		"choices": [
			{"t": "Đổi một hộp thuốc lấy ba chai nước", "need": {"bag_item": "giamdau"}, "out": [{"t": "Bà ta soi hộp thuốc dưới ánh đèn, gật đầu, đếm ba chai nước ra.", "fx": {"bag": {"giamdau": -1, "nuocsuoi": 3}}}]},
			{"t": "Đổi băng gạc lấy hai gói mì", "need": {"bag_item": "bang"}, "out": [{"t": "— Băng thì lúc nào cũng cần. — Bà ta đưa hai gói mì.", "fx": {"bag": {"bang": -1, "mitom": 2}}}]},
			{"t": "Hỏi thăm tin tức", "info": true, "out": [{"t": "— Đừng đi phố có đèn. Đèn là bọn cướp. Đi phố có trăng, đi sát tường. Với lại, — bà ta hạ giọng, — cái thứ giả tiếng người ấy, nó không vào được nhà nào mà chủ nhà không tự mở cửa."}]},
			{"t": "Thôi, không đổi", "out": [{"t": "Bà ta nhún vai, đẩy xe đi tiếp, lẫn vào bóng tối.", "fx": {}}]},
		],
	},
	"o_dua_be": {
		"title": "Đứa bé trong xe ô tô",
		"text": "Trong một cái ô tô đỗ méo, có hai con mắt nhìn bạn qua kính. Một thằng bé chừng tám tuổi, ôm cái ba lô siêu nhân.\n\n— Chú có phải người thật không?",
		"choices": [
			{"t": "\"Thật. Cháu hỏi chú đi.\"", "info": true, "out": [{"t": "— Một cộng một bằng mấy?\n\n— Hai.\n\n— Bọn kia chỉ nói lại \"một cộng một bằng mấy\" thôi. — Nó mở hé cửa xe. — Bố mẹ cháu bảo ở yên đây đợi. Lâu rồi."}]},
			{"t": "Đưa thằng bé về hầm", "out": [{"t": "Nó nắm tay bạn suốt đường về, không hỏi câu nào. Tới cửa hầm, nó để cái ba lô siêu nhân xuống trước rồi mới leo vào.\n\nBé Na nhích ra, chia cho nó nửa cái chăn.", "fx": {"morale": 12, "guest": {"id": "ti", "name": "Thằng Tí", "kind": "kid"}}}]},
			{"t": "Cho nó đồ ăn rồi dặn khoá cửa xe", "need": {"bag_food_any": true}, "out": [{"t": "Bạn đưa nó thứ gì bạn có. Nó ăn ngấu nghiến.\n\n— Chú cũng có con à? — Nó hỏi. Bạn gật. — Thế chú về đi.", "fx": {"bag_food_one": true, "morale": 2}}]},
			{"t": "Lặng lẽ đi tiếp", "out": [{"t": "Bạn tắt đèn. Hai con mắt dõi theo bạn cho tới khi khuất.", "fx": {"morale": -8}}]},
		],
	},
	"o_nguoi_linh": {
		"title": "Người lính tựa cột đèn",
		"text": "Một người lính ngồi tựa cột đèn, hai chân duỗi thẳng, không còn đứng dậy được nữa. Anh ta vẫn tỉnh.\n\n— Dân thường à. May quá. Lại đây, tôi không còn nhiều thời gian.",
		"choices": [
			{"t": "Lại gần", "out": [{"t": "Anh ta tháo một ống pháo hiệu ở thắt lưng, ấn vào tay bạn.\n\n— Sáng nào nghe tiếng trực thăng thì bắn lên. Họ sẽ xuống đúng nhà anh trước. — Anh ta cười. — Nói với họ là trung sĩ Lâm đã giữ ngã tư này bốn ngày.", "fx": {"flag": "phao_hieu", "rescue": -1, "morale": 6, "bag": {"bangdan": 1}}}]},
			{"t": "Băng bó cho anh ta", "need": {"bag_item": "bang"}, "out": [{"t": "Bạn băng lại, dù cả hai đều biết là muộn. Anh ta đưa bạn pháo hiệu, băng đạn, và tấm thẻ bài.\n\n— Đưa cái này cho họ. Để mẹ tôi biết.", "fx": {"bag": {"bang": -1, "bangdan": 2}, "flag": "phao_hieu", "rescue": -1, "morale": 10}}]},
			{"t": "Giữ khoảng cách, đi vòng qua", "out": [{"t": "— Ừ. Cẩn thận là đúng. — Anh ta nói với theo, không trách. — Đi sát tường ấy.", "fx": {"morale": -3}}]},
		],
	},
	"o_me_mai": {
		"title": "Số 14, ngõ trong cùng",
		"text": "Chậu hoa giấy vẫn còn đó. Chìa khoá dưới đáy chậu, đúng như Mai nói.\n\nBà ngoại bé Na ngồi trong bếp, bên ngọn nến, đang gói thứ gì đó vào lá chuối. Bà ngẩng lên, không hề giật mình.\n\n— Mẹ biết thế nào thằng Hưng cũng sang. Con Mai với cháu mẹ sao rồi?",
		"choices": [
			{"t": "\"Mẹ đi với con. Dưới hầm an toàn hơn.\"", "out": [{"t": "Bà lắc đầu, rồi lại gật.\n\n— Chân mẹ chậm, con phải đi chậm theo mẹ đấy.\n\nBà xách theo cái làn. Trong làn có xôi, bánh chưng, và tấm ảnh cưới của Mai.", "fx": {"guest": {"id": "ba_ngoai", "name": "Bà ngoại", "kind": "mother"}, "bag": {"xoi": 2, "banhchung": 1}, "morale": 18, "flag": "da_tim_me"}}]},
			{"t": "Nhận đồ bà gói rồi về báo tin cho Mai", "out": [{"t": "— Mẹ ở đây quen rồi. Nhà mẹ tường dày. — Bà dúi cái làn vào tay bạn. — Bảo con Mai là mẹ vẫn tưới hoa.\n\nBạn ôm bà. Bà nhỏ hơn bạn nhớ rất nhiều.", "fx": {"bag": {"xoi": 2, "banhchung": 1, "nuocsuoi": 1}, "morale": 14, "flag": "da_tim_me"}}]},
		],
	},
	# ============================================================ BUỔI SÁNG DƯỚI HẦM
	"m_chuot": {
		"title": "Chuột",
		"text": "Sáng ra, một góc bao gạo bị khoét thủng. Có tiếng sột soạt sau kệ.",
		"choices": [
			{"t": "Dọn hết kệ ra bắt cho bằng được", "out": [
				{"p": 0.6, "t": "Mất cả buổi sáng, nhưng bạn đập được nó. Bé Na đòi đặt tên cho con chuột trước khi bạn vứt đi.", "fx": {"morale": 2}},
				{"p": 0.4, "t": "Nó chạy mất vào khe tường, và bạn làm đổ một can nước trong lúc bới.", "fx": {"water": -1}},
			]},
			{"t": "Kệ nó", "out": [{"t": "Đêm đó nó quay lại cùng bạn bè.", "fx": {"food": -1}}]},
		],
	},
	"m_bup_be": {
		"title": "Con búp bê",
		"text": "— Bố ơi, bạn Thỏ của con còn ở trên phòng. Bạn ấy sợ lắm.\n\nCon thỏ bông. Nó nằm trên giường bé Na, tầng hai, ngay trên đầu.",
		"choices": [
			{"t": "Leo lên lấy cho con", "out": [
				{"p": 0.8, "t": "Căn nhà im lặng, bụi phủ khắp nơi. Con thỏ vẫn nằm trên gối. Bé Na ôm nó, và lần đầu tiên sau nhiều ngày, ngủ một giấc không giật mình.", "fx": {"morale": 10}},
				{"p": 0.2, "t": "Bạn vừa cầm được con thỏ thì cả căn nhà rung lên: có thứ gì rất lớn bước qua phố. Trần rơi một mảng trúng vai bạn. Nhưng bé Na có lại bạn Thỏ.", "fx": {"hp": -14, "morale": 8}},
			]},
			{"t": "\"Bạn Thỏ đang canh nhà cho mình.\"", "out": [{"t": "Bé Na nghĩ một lúc, rồi gật đầu, rất nghiêm trang.\n\n— Thế con viết thư cho bạn ấy.", "fx": {"morale": 1}}]},
		],
	},
	"m_ba_ngoai": {
		"title": "Mẹ của Mai",
		"text": "Mai ngồi nhìn cái điện thoại hết pin.\n\n— Mẹ em ở khu tập thể bên kia. Một mình. Em phải đi tìm mẹ.",
		"choices": [
			{"t": "\"Để anh đi. Đêm nay anh sẽ ghé qua đó.\"", "out": [{"t": "Mai nắm tay bạn rất chặt.\n\n— Số 14, ngõ trong cùng. Mẹ để chìa dưới chậu hoa giấy.\n\n(Nếu đêm nay bạn ra ngoài, hãy nhớ lời hứa này.)", "fx": {"morale": 4, "flag": "hua_tim_me"}}]},
			{"t": "\"Không ai đi đâu cả. Em phải nghĩ tới con.\"", "out": [{"t": "Mai không cãi. Cô ấy chỉ đặt cái điện thoại xuống, úp màn hình vào mặt bàn.", "fx": {"morale": -8}}]},
			{"t": "Ôm cô ấy, không nói gì", "out": [{"t": "Hai người ngồi như thế rất lâu. Bé Na leo vào giữa.", "fx": {"morale": 3}}]},
		],
	},
	"m_nuoc_la": {
		"title": "Nước có mùi lạ",
		"text": "Can nước mở dở từ hôm qua có mùi tanh. Không biết là do cái can hay do thứ gì đã rơi vào.",
		"choices": [
			{"t": "Đổ đi", "out": [{"t": "Bạn đổ xuống rãnh. Một phần nước, mất trắng.", "fx": {"water": -1}}]},
			{"t": "Lọc qua vải rồi vẫn dùng", "out": [
				{"p": 0.6, "t": "Không ai làm sao cả.", "fx": {}},
				{"p": 0.4, "t": "Đến chiều Mai bắt đầu đau bụng, rồi sốt.", "fx": {"hurt": "mai"}},
			]},
		],
	},
	"m_cau_hoi": {
		"title": "Câu hỏi của bé Na",
		"text": "— Bố ơi. Mình có chết không?\n\nBé Na hỏi rất bình thản, tay vẫn tô màu lên tường bằng mẩu gạch.",
		"choices": [
			{"t": "\"Không. Bố hứa.\"", "out": [{"t": "— Bố hứa rồi đấy nhé. — Nó tô tiếp. Nó vẽ ba người, và một cái trực thăng to hơn cả ngôi nhà.", "fx": {"morale": 5}}]},
			{"t": "\"Bố không biết. Nhưng bố sẽ ở đây.\"", "out": [{"t": "Nó nghĩ rất lâu.\n\n— Thế cũng được.\n\nRồi nó dựa vào bạn. Mai quay đi lau mắt.", "fx": {"morale": 7}}]},
			{"t": "Vờ như không nghe thấy", "out": [{"t": "Nó không hỏi lại. Nó vẽ tiếp, một mình.", "fx": {"morale": -5}}]},
		],
	},
}
