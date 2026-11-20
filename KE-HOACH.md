# Thức Giấc — Kế hoạch đợt cập nhật lớn

Trạng thái: **ĐÃ CHỐT, ĐANG TRIỂN KHAI THEO MỤC D**. File này ghi lại yêu cầu, các quyết định và danh sách việc.
Ký hiệu: `[ ]` chưa làm · `[x]` xong · `(?)` còn phụ thuộc câu hỏi chưa chốt.

---

## A. Những gì đã hiểu từ yêu cầu

### A1. Đường sắt trên cao (theo tuyến Cát Linh)
- Cầu cạn bê tông trên trụ, hai đường ray, lan can hai bên; ga có mái vòm, lên bằng cầu thang bộ.
- Người chơi lên ga, vượt qua rào chắn, đi bộ trên đường ray giữa các ga.
- Trên tuyến có vài đoàn tàu hỏng và vài đoạn gãy (gãy một bên hoặc gãy cụt).
- Gặp đoạn gãy cụt: quay lại ga gần nhất, hoặc nhảy xuống; bên dưới có đống đổ nát để đỡ chấn thương.
- Ở trên cao chỉ Thủy Quái và Dực Quái phát hiện được người chơi.

### A2. Bản đồ kiểu Hà Nội + hàng quán, công trình
- Bỏ lưới bàn cờ: đường lớn cong, ít đoạn thẳng, mạng lưới ngõ ngách không đều.
- Nhiều nhà chỉ là mặt tiền đóng cửa hoặc đổ nát không vào được; chỉ một phần vào được.
- Hàng quán có biển hiệu để nhận biết.
- Công trình mới: công viên, biệt phủ (2 cái), quán cà phê, cửa hàng xe máy, cửa hàng đồ ăn,
  bệnh viện lớn (sân, nhiều khoa/phòng), siêu thị lớn (ít nhất bằng cái hồ), trường học, trạm phát sóng.
- Đồ mới: radar quét đồ, kính nhìn đêm, balo xịn, áo giáp, súng lục + đạn, cà phê (thể lực giảm chậm hơn).
- Hàng bày thật trên kệ thay vì "bấm vào mới thấy".
- Âm thanh chân thực hơn (kính vỡ, chai vỡ, tiếng súng…); súng nổ thì quái nghe thấy.
- Xà beng chỉ có ở: nhà ông Tư, trường học, biệt phủ.

### A3. Cốt truyện Chương 2 (viết lại)
- Sau Chương 1: con gái làm rơi lọ thuốc đặc trị ở trường.
- Ngày 2 (bắt buộc): lấy thuốc. Hai đường: tới trường tìm lọ thuốc, hoặc tới biệt phủ lấy radar,
  radar chỉ ra lọ thuốc trong két bệnh viện kèm mật mã.
- Ngày 5 (bắt buộc): radio báo trạm phát sóng có máy phát tín hiệu. Tháp có quái vật bám, nhiều xúc tu,
  mỗi xúc tu có mắt quét. Bị bắt thì đánh trả cho tới khi nó thả. Máy to, phải vác: không nhảy, không đánh,
  tốc độ giảm 40%. Co-op: một người vác, người kia bảo vệ hoặc đánh lạc hướng.
- Mang máy về: máy báo quân đội sắp rải bom, cần trữ đủ lương thực cho 7 ngày (tính theo số người) và chăn.
  Đủ thì tương tác với máy → màn chữ kết: 7 ngày sau được cứu, 2 năm sau hết quái. Hết game.

### A4. Sự kiện ban đêm (ngày 1, 3, 4)
- Kẻ lừa đảo, người đáng thương, bọn cướp (30% bỏ đi / 70% phá cửa, phải đánh), người kêu cứu,
  hết đồ ăn, đường ống dẫn khí hỏng.
- Không hiện "đúng/sai": phản ứng của NPC cho biết kết quả.
- Co-op: bỏ phiếu; hoà thì tung xúc xắc, ai cao điểm hơn thì theo người đó. Cả phòng cùng làm một việc,
  không tách đội.
- Đánh nhau có trọng thương; hạ được cướp thì lục đồ của chúng; thêm hành động vác xác.

### A5. Tiện ích
- Đèn pin: pin vô hạn, có sẵn khi vào Chương 2.
- Tủ chứa đồ trong hầm: kéo đồ qua lại giữa balo và tủ, nút chuyển hết.
- Hội thoại kiểu phụ đề: chữ chạy chậm ở dưới màn hình, cảnh dừng lại nhưng nhân vật vẫn có hoạt ảnh đứng yên.
  Áp dụng cho: lời vợ bảo tìm xà beng, loa phát thanh, kết game, mọi lời thoại nhân vật/sự kiện.

---

## B. Các quyết định đã chốt

### B1. Bạn đã trả lời
1. **Cạy cửa hầm** là kết Chương 1. **Cạy két** là chuyện khác: nhặt được *máy dò nhu yếu phẩm* ở biệt phủ, máy hiện vị trí lọ thuốc
   trong két bệnh viện và hiện luôn mật mã két.
2. **Lịch Chương 2:** ngày 1, 3, 4 có sự kiện đêm ngẫu nhiên; ngày 2 lấy thuốc; ngày 5 lấy máy phát tín hiệu.
   Sau ngày 5 không còn sự kiện ngẫu nhiên: tập trung mang máy về và gom đồ.
   Máy phải được **đặt xuống đúng chỗ trong hầm**; đặt xong máy báo **3 ngày nữa quân đội thả bom**.
   Hết 3 ngày mà chưa đủ đồ → **kết xấu** (bom rơi rồi thì không lên mặt đất gom đồ được nữa).
3. **Chương 2 chỉ ra ngoài ban đêm.** Chương 1 là trải nghiệm ban ngày. Bản đồ phải **khó đi hơn** để Chương 1 dài ra.
4. **Hai cách lấy thuốc:** (a) tới trường, lục các tủ khoá, mất nhiều thời gian; (b) biệt phủ → máy dò → két bệnh viện.
   Lọ thuốc chỉ xuất hiện ở trường và bệnh viện. Tủ ở trường có thêm: bim bim, nước ngọt, ngô cay, sách vở, balo, mũ, giày, áo.
5. **Lương thực 7 ngày:** tính theo người; mỗi người mỗi ngày **2 đồ ăn + 2 nước** (mức khó: 3 + 3).
   Nhà 3 người + 1 người chơi = 4 người → 56 đồ ăn, 56 nước.
6. **10 sự kiện đêm**, làm chỉn chu, phải gồm đủ 6 sự kiện bạn nêu. Các sự kiện mình viết trước đây cất vào mục E (để sau).
7. **Đánh cướp:** thời gian thực trong 3D.
8. **Vác xác:** xác để trong hầm làm giảm tinh thần, phải vác ra ngoài vứt.
9. **Bản đồ:** thay bản đồ hiện tại, nhưng làm vừa phải: khoảng **một nửa như cũ, một nửa kiểu Việt Nam**, xen kẽ lẻ tẻ chứ không chia đôi.
10. **Bỏ súng trường**, chỉ còn súng lục.
11. **Mọi món đồ đều nhặt trực tiếp** trong thế giới (không còn bảng "lục tủ"); món đang trỏ vào được **viền sáng**.
12. **Chơi một mình:** quái tháp kém cảnh giác hơn; vẫn phải đặt máy xuống để đánh rồi vác tiếp.
13. **Hội thoại:** chơi một mình thì dừng cảnh; co-op thì chỉ khoá điều khiển người đang nói chuyện.

### B2. Mặc định mình tự chọn (bạn chưa phản đối; nói mình nếu muốn khác)
- Giữ đoạn cắt cảnh nhà sập; lối ra vào hầm nằm ở đống đổ nát trước cửa nhà.
- Giữ cuốn sổ chia khẩu phần mỗi ngày (chủ phòng ghi, cả phòng thấy).
- Hạn chót thuốc cho con gái: hết ngày 4 chưa có thuốc thì con không qua khỏi.
- Mỗi món ăn / món uống trong tủ tính là 1 phần, không quy đổi theo loại. Chăn: mỗi người 1 cái.
- Đêm 2 và đêm 5 là đêm nhiệm vụ; các đêm còn lại sau ngày 5 không có sự kiện.
- Kích thước bản đồ giữ như hiện tại; khoảng 1/3 số nhà vào được.
- Giữ khu tập thể, công trường và cần cẩu, rừng công viên, bãi cỏ.
- Đường sắt trên cao: một tuyến cong, 5 ga (gần văn phòng, hồ, bệnh viện, trường, gần nhà), 2 đoạn gãy cụt, 1 đoạn gãy một bên, 2 đoàn tàu hỏng.
  Săn Mồi không với tới cầu cạn.
- Quái tháp không giết được; người đang vác máy bị bắt thì máy rơi tại chỗ.
- Hội thoại: bấm E hiện hết dòng, bấm lần nữa sang dòng sau.
- Âm thanh: thử tải mẫu CC0 trước, không được thì tổng hợp lại kỹ hơn.
- Bỏ phiếu co-op hoà: mỗi bên tung xúc xắc, điểm cao hơn thắng. Bỏ tách đội và gõ cửa giả.

### B3. Hệ quả kỹ thuật cần lưu ý
- **Nhặt trực tiếp mọi món (11):** hiện có khoảng 10.000 chỗ chứa đồ. Không thể dựng sẵn hàng chục nghìn vật 3D,
  nên đồ chỉ được dựng hình khi người chơi ở gần (khoảng 30 m) và gỡ đi khi ra xa. Bảng "lục tủ" bị bỏ; chỉ còn bảng túi đồ và tủ chứa trong hầm.
- **Chỉ ra ngoài ban đêm (3):** nhiệm vụ lấy thuốc và lấy máy đều diễn ra trong bóng tối, nên trường, bệnh viện, biệt phủ, tháp
  cần có nguồn sáng yếu riêng (đèn khẩn cấp, nến) để nhận ra từ xa.
- **Bản đồ nửa cũ nửa mới (9):** giữ khung lưới làm xương sống; khoảng một nửa số ô được gộp thành các mảng ngõ ngách không đều
  (dùng lại bộ sinh của khu tập thể), một số đoạn đường lớn bị cắt hoặc bẻ lệch để không còn đi thẳng một mạch.

---

## C. Danh sách việc

### C1. Nền tảng
- [x] Đồ mới: súng lục + đạn (thay súng trường), máy dò nhu yếu phẩm, kính nhìn đêm, balo xịn, cà phê, chăn, lọ thuốc đặc trị,
      đèn pin, bim bim, nước ngọt, ngô cay, sách vở; hình 3D và biểu tượng cho từng món
- [x] Nhặt trực tiếp mọi món: đồ dựng hình khi ở gần, viền sáng món đang trỏ, bỏ bảng "lục tủ"; đồng bộ co-op
- [x] Hội thoại phụ đề: chữ chạy chậm, dừng cảnh (một mình) / khoá điều khiển (co-op), E để hiện hết / sang dòng
- [x] Tủ chứa đồ trong hầm: kéo thả hai chiều, nút chuyển hết; kho hầm chuyển từ "số phần" sang món đồ thật
- [x] Đèn pin là món đồ có sẵn ở Chương 2, pin vô hạn
- [x] Bỏ phiếu co-op: hoà thì tung xúc xắc
- [x] Bỏ tách đội và gõ cửa giả; cả phòng cùng ra ngoài, về thì chui thẳng xuống hầm
- [x] Âm thanh: kính vỡ, chai vỡ, súng lục, phá cửa, kim loại (mẫu CC0, nguồn ghi ở assets/sfx/NGUON-AM-THANH.txt); súng nổ thì quái trong 230m kéo tới

### C1b. Thanh công cụ (thêm theo yêu cầu)
- [x] 4 ô (phím 1-4, lăn chuột) + tay trái (F đổi tay); ô trống thì tay không; nhặt vũ khí/đèn pin tự vào ô trống
- [x] Cầm đèn pin: chuột trái bật/tắt; tay trái: chuột phải; đồ ăn/thuốc trên tay: chuột trái để dùng; máy dò: chuột trái để quét
- [x] E chỉ để nhặt/tương tác; Tab mở/đóng túi đồ (sửa lỗi Tab chuyển ô); kéo món vào ô công cụ trong túi đồ, hoặc trỏ vào món rồi bấm 1-4 / F

### C2. Bản đồ nửa cũ nửa Việt Nam
- [x] Sương mù chỉ 10%
- [x] Đồ cất trong tủ kín (tủ lạnh, ngăn kéo, thùng, thi thể) mở bảng danh sách; chỉ đồ bày lộ ra ngoài (kệ hàng, đồ rơi) mới nhặt trực tiếp
- [x] Chọn khoảng một nửa số ô, gộp lẻ tẻ thành các mảng ngõ ngách không đều (13 khu, cỡ 1×1 tới 2×2: 34/70 ô dân cư)
- [x] Cắt các đoạn đường lớn đi qua khu ngõ ngách; thêm chướng ngại (38 đoạn đường bị chặn)
- [x] Nhà mặt tiền đóng cửa / đổ nát không vào được (60% nhà dân, cửa cuốn); biển hiệu hàng quán trên 40% số nhà đóng cửa
- [x] Hồ hình tự nhiên có đảo nhỏ, đình, cầu cong đỏ
- [x] Đường đi của quái lớn theo mạng đường mới; bản đồ lớn và bản đồ nhỏ vẽ lại
- [x] Cập nhật các bài kiểm thử

### C3. Công trình đặc thù
- [x] Bệnh viện: toà chính 4 tầng + khoa cấp cứu, sân, xe cứu thương, két sắt có mật mã chứa lọ thuốc (khoá mật mã: làm cùng cốt truyện)
- [x] Trường học: dãy lớp 3 tầng, nhà thể chất, sân, ~300 tủ khoá (một tủ có lọ thuốc), tủ phòng giáo viên có xà beng
- [x] Biệt phủ ×2: tường rào, cổng, vườn, bể bơi; phòng kho có máy dò, kính nhìn đêm, balo xịn, áo giáp, súng lục, xà beng
- [x] Đại siêu thị 104×80m (lớn hơn mặt hồ), ~470 kệ hàng bày thật, bãi đỗ xe
- [x] Quán cà phê (nhiều nước, cà phê), cửa hàng xe máy, cửa hàng đồ ăn (đã có sẵn, đổi bảng đồ)
- [x] Trạm phát sóng: tháp thép 72m trắng đỏ, phòng máy (máy phát tín hiệu: làm cùng cốt truyện)
- [x] Xà beng chỉ có ở nhà ông Tư, trường học, biệt phủ
- [x] Nguồn sáng yếu ban đêm cho các điểm nhiệm vụ: đèn khẩn cấp đỏ chập chờn ở bệnh viện (trên mái + cạnh két), đèn bão ở trường, đèn máy phát ở biệt phủ, biển lối thoát xanh ở đại siêu thị, đèn thiết bị xanh trong phòng máy, đèn đỏ nhấp nháy trên đỉnh tháp
- [x] Kính nhìn đêm: đeo ở ô Mắt, phím N bật/tắt; khuếch đại ánh sáng, ảnh xanh lục có hạt nhiễu và khung ống kính, không phát sáng nên không lộ vị trí như đèn pin

### C4. Đường sắt trên cao
- [x] Cầu cạn theo đường cong: trụ, dầm, ray, lan can (bản đồ nới từ 14 lên 18 cột; tuyến dài 1,4km, 4 khúc cua tròn + lượn nhẹ)
- [x] 5 ga: cầu thang, chiếu nghỉ, sân ga, mái vòm, rào chắn nhảy qua được
- [x] 2 đoạn gãy cụt, 1 đoạn gãy một bên, đống đổ nát bên dưới để nhảy xuống
- [x] 2 đoàn tàu hỏng trên ray (một đoàn trật bánh)
- [x] Trên cầu cạn chỉ Thủy Quái và Dực Quái phát hiện được

### C4b. Sửa thêm (theo góp ý)
- [x] Mở đầu Chương 1: tỉnh dậy chưa có mục tiêu về nhà ("Chuyện gì đang xảy ra ngoài kia?"), chưa có đường chỉ dẫn, la bàn và bản đồ chưa đánh dấu nhà
- [x] Thủy Quái trồi lên khỏi hồ → nhân vật chính nghĩ tới vợ con (lời thoại) → lúc đó mới có mục tiêu và đường chỉ dẫn về nhà
- [x] Đường chỉ dẫn tính lại: bắt đầu từ đúng mặt đường cạnh chỗ đứng (không quay ngược về ngã tư phía sau), ít ngã rẽ nhất có thể, đoạn cuối đi theo đường tới trước cửa nhà thay vì cắt xuyên khối nhà
- [x] Góc cua bo tròn (cung cong), vẽ thành một nét liền mềm trên cả bản đồ nhỏ lẫn bản đồ lớn

### C5b. Sửa thêm trước bước 6 (theo góp ý)
- [x] Đêm mất điện tối hẳn: trăng rất thấp phía đông nên chỉ vài đoạn phố chạy đông-tây có vệt trăng, phố bắc-nam / ngõ / sân trong tối mịt; tắt ánh sáng hắt từ bầu trời, trời đêm gần đen
- [x] Quỷ Mắt to hơn nhiều: khối thịt gần 20m ôm thân tháp, mạch máu đỏ, 8 con mắt trên thân, 10 xúc tu quấn quanh tháp đung đưa, xúc tu có mắt dày gấp đôi (một mình 4, co-op 7); da hơi phát sáng để nhìn ra trong đêm
- [x] Cầm đèn pin kiểu Phasmophobia: tay đưa ra góc dưới màn hình, đèn chĩa thẳng theo hướng nhìn; ánh sáng phát ra từ mặt kính đèn (không còn rọi ngược vào tay)
- [x] Tay góc nhìn thứ nhất: cẳng tay thon, tay áo xắn có mép gấp, bàn tay nắm có từng ngón, đốt ngón, ngón cái
- [x] Hình người (người chơi, dân, NPC, kẻ cướp, gia đình): cổ, mặt có mắt / mũi / miệng / tai / lông mày, 4 kiểu tóc (Mai và bé Na tóc dài), vai tròn, ngực, thắt lưng, bàn tay có ngón cái, giày có đế; dùng chung mesh/vật liệu, chi tiết nhỏ chỉ vẽ trong 22m (chậm hơn khoảng 3%)

### C5c. Tay góc nhìn thứ nhất bằng model thật
- [x] Dùng model người có khung xương "Universal Base Characters" của Quaternius (CC0, nguồn ghi ở assets/models/hero/NGUON.txt)
- [x] IK hai khớp vai → khuỷu → cổ tay tới đúng điểm cầm; bàn tay xoay theo trục cán; từng đốt ngón gập quanh cán; tay không thì nắm đấm (ngón cái gập ngang)
- [x] Tay áo xắn theo màu áo đang mặc; giữ nguyên hoạt ảnh cũ (vung đánh, nhún bước, cầm đèn pin chĩa thẳng, cầm tay lái xe)

### C5d. Model người thật cho nhân vật ở gần
- [x] Cầm đèn pin: nắm chéo thân đèn như tay thật, ngón cái ép trên đầu đèn, cổ tay thẳng hàng cẳng tay; đèn pin có nắp đuôi, vòng khía, nút bấm, đầu loe, viền kim loại
- [x] Gia đình (Mai, bé Na), kẻ cướp, đồng nghiệp, người bị thương, người chơi khác: model người thật (nam / nữ) có tóc, lông mày, mắt
- [x] Quần áo tô theo vùng cơ thể và nhuộm màu riêng từng người (một vật liệu dùng chung); dùng lại hoạt ảnh cũ (đi, chạy, ngồi, bơi, đánh, ngã)
- [x] Kẻ cướp: khăn che mũi miệng gắn theo đầu, gậy nắm trong tay
- [ ] Đám đông dân thường (130 người) vẫn dùng model nhẹ để giữ tốc độ khung hình

### C9. Góp ý đợt 17/11
- [x] Biệt phủ chiếm 2 ô: dinh thự 36×22m 3 tầng (hành lang + 10-12 phòng mỗi tầng: phòng ngủ, khách, làm việc), nhà khách 2 tầng, gara; phòng kho đồ xịn nằm ngẫu nhiên ở một phòng
- [x] Đồ trên kệ cố định chỗ (lấy một món các món khác không xê dịch; có bài thử loot_test)
- [x] Đường sắt: thêm GA HÀNG ĐẬU giữa ga 1 và ga 2 (6 ga); mỗi ga 2 lối lên ở 2 bên đường; dọn vật cản chân cầu thang
- [x] Đứng dưới mái vòm ga: không con nào thấy (kể cả Thủy Quái, Dực Quái)
- [x] Quỷ Mắt hiện cả ở chương 1; trạm phát sóng thành trạm nghiên cứu tròn bán kính 11m, mái vòm cầu có gân thép, đĩa ăng-ten, dải đèn xanh, bàn điều khiển vòng quanh
- [x] Ngón cái gập gọn (nắm đấm và cầm đồ đều theo kiểu đã duyệt)
- [x] Tay chương 2 giống chương 1; vũ khí cán dài (gậy, ống, xà beng) cầm cùng kiểu nắm đã duyệt
- [x] Cua Quỷ: 10 chân nhện dài cong vút toả quanh mai, mỗi chân khua một nhịp riêng mọi hướng; miệng hốc lớn trên lưng (môi thịt đỏ, 2 vòng răng, phập phồng, há to khi đuổi)
- [x] Tầm nhìn quái: ban đêm giảm 20%; ngồi giảm thêm (ban đêm còn nhiều hơn); chạy tăng 30%; bật đèn pin ban đêm tăng 70% với quái dưới đất (Săn Mồi, Cua Quỷ...)
- [x] Quái ban đêm chậm 20% (mọi loài); Thủy Quái ban đêm thỉnh thoảng giẫm nát bừa một nhà gần đó (trừ nhà cốt truyện), Dực Quái thỉnh thoảng phun lửa bừa
- [x] Vòng tầm nhìn quái trên bản đồ chỉ hiện ở chế độ thần
- [x] Ống thông khí ở sân sau nhà, có hình ống gãy (đoạn trên văng ra đất, miệng ống lởm chởm, phụt bụi), giữ E 5 giây (có thanh tiến độ) mới nối lại
- [x] Nắp hầm nằm trong căn nhà đã sập (tường bao còn trơ, gạch dồn về góc), nắp thép vuông rỉ sét có đinh tán, gân, tay nắm hàn
- [x] Bé Na: tỉ lệ trẻ con (đầu to, người nhỏ, vai hẹp)
- [x] Bản đồ: bệnh viện ngay phía nam nhà, 2 biệt phủ xa vừa, trường học xa nhất (góc tây nam)
- [x] Thổ Trùng to gấp rưỡi, thỉnh thoảng tự phóng vọt lên khỏi mặt đất (để người chơi thấy nó)
- [x] Tiếng bước trên cỏ: sột soạt trầm, dịu (tools/make_grass_steps.py)
- [x] Đại siêu thị 3 tầng, trần cao 7m, 2 giếng thang cuốn hỏng ở hai bên lối giữa (lan can kính), mỗi tầng một nhóm hàng (thực phẩm / thời trang-giày-balo / dụng cụ-thuốc-phụ tùng)
- [x] Bệnh viện: 3 toà xếp chữ U quanh sân trong, hành lang + phòng nhỏ (phòng bệnh 2 giường, phòng khám, khoa dược nhiều tủ thuốc kính chữ thập đỏ, phòng trưởng khoa có két)

### C5. Quái vật tháp phát sóng
- [x] Hình dáng: khối thịt bám tháp ở độ cao 44m, xúc tu cong võng xuống, đầu mỗi xúc tu một con mắt rọi đèn (nón sáng + vòng sáng trên đất)
- [x] Hành vi: vệt sáng lượn quanh sân trạm; chỉ thấy thứ đang chuyển động (đứng/ngồi im thì không thấy; vác máy hoặc bật đèn pin thì đứng im cũng bị thấy); mái nhà che được. Thấy thì vệt sáng chuyển đỏ và đuổi, kịp thì quấn và nhấc người lên 2,4m, siết mất máu; đập 3-4 cú (đồ nặng tính 2, súng tính 2) thì nhả, rụt lên tháp 22-30 giây. Đồng đội đập/bắn cũng cứu được
- [x] Chơi một mình: 3 xúc tu (co-op 5), quét chậm hơn, vệt sáng nhỏ hơn, phải nhìn 1,6 giây mới chắc (co-op 0,8), đuổi 4,4m/s (co-op 6), siết nhẹ hơn, 3 cú là thoát (co-op 4)
- [x] Vác máy: tốc độ giảm 40%, không nhảy, không đánh; đặt xuống / nhặt lên; bị bắt thì rơi máy; đồng bộ co-op (bài thử net3)

### C6. Cốt truyện Chương 2
- [x] Mở đầu: lời thoại về lọ thuốc rơi ở trường
- [x] Đêm 2: lấy thuốc (lục tủ ở trường, hoặc biệt phủ → máy dò → két bệnh viện); hạn chót hết ngày 4
- [x] Đêm 5: radio báo trạm phát sóng; mang máy về, đặt vào chỗ đặt máy trong hầm
- [x] Đếm ngược 3 ngày tới lúc thả bom; bảng yêu cầu: mỗi người 2 ăn + 2 nước × 7 ngày (khó: 3 + 3), mỗi người 1 chăn
- [x] Kết tốt (đủ đồ): màn chữ 7 ngày sau, 2 năm sau. Kết xấu (hết 3 ngày chưa đủ)
- [x] Lời thoại phụ đề cho: vợ bảo tìm xà beng (sáng ngày 2), loa phát thanh (ngày 5), kết game, các nhân vật

### C7. Mười sự kiện ban đêm (đêm 1, 3, 4)
- [x] 1. Kẻ lừa đảo (cho thì bị cười nhạo, không cho thì bị chửi)
- [x] 2. Người đáng thương (giống hệt bề ngoài kẻ lừa đảo, nhưng khổ thật)
- [x] 3. Bọn cướp (xin 1 món → 30% bỏ đi / 70% phá cửa → đánh thời gian thực)
- [x] 4. Người kêu cứu (bị cướp trấn lột ngoài ngõ: ra cứu hoặc ngủ tiếp)
- [x] 5. Hết đồ ăn (cả phòng ra ngoài gom đồ, có thể chạm mặt cướp)
- [x] 6. Đường ống dẫn khí hỏng (phải lên sửa, tiện gom đồ)
- [x] 7–10. Giọng bác Tư (người giả giọng), Người mặc áo blouse (y tá đổi thuốc), Tiếng trẻ con khóc, Đêm mưa (nước ngập) — lấy từ bộ sự kiện cũ, viết lại cho hợp lịch mới; bạn duyệt lại nhé
- [x] NPC cướp: máu, vũ khí, tấn công; hạ gục thì lục đồ; vác xác; xác trong hầm làm giảm tinh thần

### C8. Kiểm thử và đóng gói
- [x] Bài tự chơi hết Chương 2 mới (một mình), có cả kết tốt và kết xấu (shelter_test) + bài Quỷ Mắt (tower_test) + bài đường chỉ dẫn / mở đầu (route_test)
- [x] Bài thử co-op hai tiến trình cho Chương 2 mới (bỏ phiếu, hoà thì xúc xắc, cả nhóm cùng ngủ / cùng ra ngoài)
- [x] Ảnh chụp các khu mới để duyệt hình ảnh
- [x] Đóng gói Windows

---

## D. Thứ tự triển khai
1. **C1** nền tảng (đồ mới, nhặt trực tiếp, hội thoại, tủ chứa)
2. **C2** bản đồ
3. **C3 + C4** công trình và đường sắt
4. **C6 + C7** cốt truyện và sự kiện
5. **C5** quái tháp
6. **C8** kiểm thử, đóng gói

Mỗi bước xong sẽ gửi bản chơi được và ảnh chụp để duyệt trước khi sang bước sau.

---

## E. Để sau (đã viết, tạm cất)
Các sự kiện của bản Chương 2 trước: giọng ông Tư giả và ông Tư thật, cô y tá Hạnh, người mẹ bế con, kẻ nhại giọng (tiếng trẻ khóc, loa cứu hộ giả),
cậu lính đào ngũ và đội tuần tra, bà Sáu bán xôi, anh Dũng kế toán, người đàn ông và cái vali, con Mực, đêm cuối;
ngoài phố: hai ông bà già, người kẹt dưới tường, người đẩy xe hàng, đứa bé trong ô tô, người lính tựa cột đèn, mẹ của Mai;
buổi sáng: chuột, con thỏ bông, nước có mùi lạ, câu hỏi của bé Na. Nội dung nằm trong `scripts/shelter_events.gd`.
