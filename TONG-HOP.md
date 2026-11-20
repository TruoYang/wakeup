# Thức Giấc — Tổng hợp dự án

Game sinh tồn lén lút 3D góc nhìn thứ nhất, bối cảnh một thành phố kiểu Hà Nội bị quái vật khổng lồ tấn công.
Phong cách hình ảnh vẽ tay (toon). Chơi một mình hoặc co-op qua mạng (tối đa 4 người).
Làm bằng Godot 4.7.2, GDScript; thành phố, nhà cửa, đồ vật đều dựng bằng code.

Cập nhật: 19/11/2026.

---

## 1. Chạy game

- **Bản Windows:** giải nén `ThucGiac-windows.zip`, chạy `ThucGiac.exe` (giữ `ThucGiac.pck` cạnh file .exe).
- **Từ mã nguồn:** mở Godot 4.7.2 → Import `project.godot` → F5.
- **Chơi chung:** một người bấm *Mở phòng*, đọc IP cho bạn bè; bạn bè nhập IP rồi *Vào phòng*.
  Cần cùng mạng LAN hoặc mạng ảo (Radmin VPN, Hamachi, Tailscale, ZeroTier). Cổng UDP 24680.
- Máy yếu: Esc → Đồ hoạ: Thấp.

## 2. Điều khiển

| Phím | Việc |
|---|---|
| W A S D | Đi |
| Shift | Chạy |
| C | Ngồi (dưới nước: lặn) |
| Space | Nhảy (dưới nước: nổi lên) |
| E | Tương tác: nhặt đồ, mở tủ, nói chuyện, lên/xuống xe máy, đặt đồ đang vác xuống |
| Giữ E | Lấy hết đồ trong tủ |
| Chuột trái | Dùng món đang cầm: đánh, bắn, bật/tắt đèn pin, ăn uống, quét máy dò |
| Chuột phải | Dùng món ở tay trái |
| 1 – 4, lăn chuột | Chọn ô trên thanh công cụ |
| F | Đổi món giữa tay phải và tay trái |
| Q | Ném pháo / chai |
| Tab | Mở/đóng túi đồ |
| M | Bản đồ lớn · Z: phóng bản đồ nhỏ |
| L | Bật/tắt đèn pin |
| N | Bật/tắt kính nhìn đêm (phải đeo kính ở ô Mắt) |
| V | Đổi góc nhìn thứ nhất / thứ ba |
| Esc | Tạm dừng, cài đặt |

---

## 3. Cốt truyện

### Chương 1 — Về nhà
1. Tỉnh dậy trong văn phòng, gục trên bàn phím. Mặt đất rung, bên ngoài có tiếng gầm. Chưa có mục tiêu hay chỉ dẫn.
2. Giây 25: **Thủy Quái** trồi lên từ hồ. Nhân vật nghĩ tới vợ con, lúc này mới có mục tiêu "Về nhà, tìm vợ con" và đường chỉ dẫn.
3. Về tới nhà: Mai (vợ) và bé Na (con) đang đợi; cửa hầm kẹt, cần xà beng.
4. Sang nhà bác Tư lấy xà beng (nhà trống, có vệt máu, phải tự lục).
5. Mang xà beng về cạy cửa hầm → cảnh căn nhà đổ sập → hết chương.

### Chương 2 — Dưới hầm (chỉ ra ngoài vào ban đêm, thành phố mất điện)
- **Ban ngày:** mở sổ chia khẩu phần (chủ phòng ghi, cả phòng cùng thấy). Nghe radio, nói chuyện với gia đình.
- **Ban đêm:** một sự kiện ở cửa hầm, rồi cả nhóm bỏ phiếu *ngủ tới sáng* hoặc *cùng lên tìm đồ* (30% bị phục kích). Hoà phiếu thì tung xúc xắc.
- **Ngày 1:** lời thoại mở đầu, bé Na nhắc cái cặp để quên ở trường.
- **Ngày 2:** Na lên cơn. Mai dặn phải có thuốc trước hết ngày 4, nếu không con sẽ mất. Có 2 cách lấy thuốc:
  - cạy tủ khoá ở **trường học** (phải có xà beng; bác Tư, phòng giáo viên ở trường, biệt phủ đều có);
  - lấy **máy dò** ở **biệt phủ**, quét lần đầu sẽ hiện mã két, rồi mở **két bệnh viện**.
  Cầm thuốc trên tay rồi nói chuyện với Na để cho con uống.
- **Ngày 5:** radio báo có máy phát tín hiệu ở **trạm phát sóng**, trên tháp có một thứ "nhìn thấy mọi thứ chuyển động".
  - Vác máy: đi chậm 40%, không nhảy, không đánh được.
  - Đặt máy lên bệ trong hầm thì 3 ngày sau bom rơi.
  - Cần dự trữ: mỗi người 2 đồ ăn + 2 nước × 7 ngày (độ khó cao: 3 + 3), và 1 chăn.
- **Kết thúc:**
  - Kết tốt *BÌNH YÊN* / *CÒN SỐNG*: đủ đồ, có đoạn "7 ngày sau… Hai năm sau…".
  - Kết xấu *KHÔNG KỊP*: bom rơi mà kho thiếu đồ.
  - Kết xấu *BỊ LÃNG QUÊN*: tới ngày 14 vẫn chưa mang máy về.

### Mười sự kiện ban đêm (đêm 1, 3, 4)
1. **Kẻ lừa đảo:** mở đầu giống hệt người đáng thương; cho đồ thì bị cười nhạo, không cho thì bị chửi.
2. **Người đáng thương:** khổ thật; cho đồ thì vài ngày sau có quà trả ơn trước cửa hầm.
3. **Ba gã đàn ông (bọn cướp):** đòi đồ; 30% bỏ đi, 70% phá cửa xông xuống, đánh nhau thời gian thực.
4. **Tiếng kêu cứu:** có người bị cướp trấn lột ngoài ngõ; ra cứu hoặc ngủ tiếp.
5. **Kệ trống:** hết đồ ăn, cả phòng phải ra ngoài gom đồ.
6. **Không khí:** ống dẫn khí hỏng, phải lên sửa. Không sửa thì mất máu và Mai đổ bệnh.
7. **Giọng bác Tư:** có kẻ giả giọng bác Tư gọi cửa.
8. **Người mặc áo blouse:** người tự xưng y tá, muốn đổi thuốc.
9. **Tiếng trẻ con khóc.**
10. **Đêm mưa:** nước ngập hầm.

Sự kiện 7–10 lấy từ bộ sự kiện cũ, viết lại cho hợp lịch mới, **chưa được duyệt**.
Phản ứng của nhân vật sau mỗi lựa chọn cho biết mình đã chọn đúng hay sai, nhưng không nói thẳng ra.

---

## 4. Bản đồ

- **Kích thước:** 18 cột × 7 hàng khối nhà. Khoảng một nửa là lưới phố cũ, nửa còn lại là khu ngõ ngách lẻ tẻ.
  Có đoạn đường bị đổ nát chặn lối, và hồ hình tự nhiên với đảo nhỏ, đình, cầu cong đỏ.
- **Nhà cửa:** 60% nhà dân đóng cửa cuốn, không vào được; nhiều nhà có biển hiệu hàng quán.
- **Đường sắt trên cao (theo kiểu tuyến Cát Linh):**
  - Tuyến dài 1,4 km, có 4 khúc cua.
  - 6 ga (thêm GA HÀNG ĐẬU giữa ga 1 và ga 2), mỗi ga có 2 lối lên ở hai bên đường.
  - Đứng dưới mái vòm ga thì không con quái nào thấy.
  - 2 đoạn gãy cụt, 1 đoạn gãy một bên, 2 đoàn tàu hỏng.
  - Đứng trên cầu cạn thì chỉ Thủy Quái và Dực Quái nhìn thấy.
- **Công trình đặc thù:**
  - **Vị trí:** bệnh viện sát nhà (phía nam), 2 biệt phủ xa vừa, trường học xa nhất (góc tây nam).
  - **Bệnh viện:** 3 toà 3 tầng xếp chữ U quanh sân trong; hành lang và phòng nhỏ (phòng bệnh 2 giường, phòng khám, khoa dược nhiều tủ thuốc kính chữ thập đỏ); két sắt khoá số ở phòng trưởng khoa.
  - **Trường học:** khoảng 300 tủ khoá, một tủ có thuốc; phòng giáo viên có xà beng.
  - **Biệt phủ ×2 (mỗi cái 2 ô):** dinh thự 3 tầng nhiều phòng, nhà khách, gara, bể bơi; phòng kho đồ xịn (máy dò, kính nhìn đêm, súng...) nằm ngẫu nhiên ở một phòng.
  - **Đại siêu thị:** 104 × 80 m, 3 tầng trần cao 7 m, 2 giếng thang cuốn hỏng; tầng 1 thực phẩm, tầng 2 thời trang-giày-balo, tầng 3 dụng cụ-thuốc-phụ tùng.
  - **Trạm phát sóng:** tháp thép trắng đỏ cao 72 m (Quỷ Mắt bám trên đó) và trạm nghiên cứu hình tròn mái vòm cầu.
  - Quán cà phê, cửa hàng xe máy, cửa hàng đồ ăn.
- **Ánh sáng ban đêm (chương 2, mất điện):**
  - Trăng treo thấp phía đông nên chỉ vài đoạn phố có vệt trăng, còn lại tối mịt.
  - Điểm nhiệm vụ có đèn yếu: đèn khẩn cấp đỏ chập chờn ở bệnh viện, đèn bão ở trường, đèn máy phát ở biệt phủ, biển lối thoát xanh ở siêu thị, đèn đỏ nhấp nháy trên đỉnh tháp.
  - Sương mù chỉ xuất hiện 10% số ngày.
- **Đường chỉ dẫn:**
  - Bắt đầu từ mặt đường cạnh chỗ đứng, chọn đường ít ngã rẽ.
  - Góc cua bo tròn, vẽ thành nét liền trên cả bản đồ nhỏ lẫn bản đồ lớn.
  - Tính mỗi đường mất khoảng 3 ms; đứng yên thì dùng lại đường đã tính.

---

## 5. Quái vật và kẻ thù

| Tên | Đặc điểm |
|---|---|
| **Thủy Quái** | Khổng lồ, trồi lên từ hồ ở giây 25. Đi dọc đường, nhìn từ trên cao, giẫm nát nhà. Ban đêm không nhìn thấy. |
| **Thổ Trùng** | To lớn, đi ngầm dưới đất, trồi lên ngay chỗ có tiếng động; thỉnh thoảng tự phóng vọt lên khỏi mặt đất. |
| **Săn Mồi** | Săn ban đêm, nhanh, đuổi theo và cắn. |
| **Dực Quái** | Bay, nhìn từ trên cao, kêu gọi Thủy Quái tới. |
| **Bạch Trùng** | Con sâu dài bò lang thang trên phố. |
| **Cua Quỷ** | 12 con trồi lên từng đợt từ khe nứt và hồ. Kiểu "Chomper" (19/11): khối thịt hồng nhợt góc cạnh, miệng hốc khổng lồ ngả ra trước với môi đỏ và hai vòng răng, chùm mắt đen phía trước, 10 chân nhện dài khua mọi hướng. Vào nhà thì chậm, đập 5 cú là chết. |
| **Kẻ cướp** | 6 tên, bịt mặt, cầm gậy. Phá cửa hầm hoặc phục kích ngoài phố. Gục thì rơi đồ, xác vác đi được; để xác trong hầm qua đêm thì cả nhà mất tinh thần. |
| **Quỷ Mắt** (chương 2) | Khối thịt khoảng 20 m bám trên tháp phát sóng, 8 mắt trên thân, 10 xúc tu quấn tháp. Xúc tu có mắt rọi đèn quét sân trạm, **chỉ thấy thứ đang chuyển động** (vác máy hoặc bật đèn thì đứng im cũng bị thấy). Bắt được người thì nhấc lên, siết mất máu và làm rơi máy; đập 3–4 cú thì nó nhả. |

Một mình thì Quỷ Mắt dễ hơn co-op:

| | Một mình | Co-op |
|---|---|---|
| Xúc tu có mắt | 4 | 7 |
| Thời gian nhìn trước khi chắc chắn thấy | 1,6 giây | 0,8 giây |
| Tốc độ đuổi | 4,4 m/s | 6 m/s |

- **Phục kích khi vác máy phát (chỉ chế độ Khó hoặc co-op, 19/11):** vừa nhấc máy lên là 3 con Cua Quỷ (co-op thêm 1 con mỗi người khác, tối đa 5) trồi lên từ mặt đường cách 28–70 m và mò thẳng tới người vác; sau đó cứ 40–55 giây thêm 2 con cho tới khi đặt máy vào hầm. Bài thử: `ambush_test`.
- **Ban đêm:** mọi quái chậm và nhìn kém đi khoảng 20%. Thủy Quái, Dực Quái không thấy người nhưng thỉnh thoảng giẫm bừa một nhà / phun lửa bừa (không đụng nhà cốt truyện).
- **Lén lút:** ngồi xuống thì khó bị thấy (ban đêm càng khó); chạy thì dễ bị thấy hơn 30%; bật đèn pin ban đêm thì quái dưới đất thấy từ xa hơn 70%.
- Vòng tầm nhìn của quái trên bản đồ chỉ hiện ở chế độ thần.
- Bị săn có tim đập, rung màn hình.
- Đeo đồng hồ định vị thì quái hiện trên bản đồ.
- Tiếng súng kéo quái trong vòng 230 m tới.

---

## 6. Đồ đạc và giao diện

- **Nhặt đồ:**
  - Đồ bày lộ ra ngoài (kệ hàng, đồ rơi) thì nhặt trực tiếp, có viền sáng khi trỏ vào.
  - Đồ cất trong tủ kín (tủ lạnh, ngăn kéo, thùng, thi thể) thì phải mở bảng danh sách.
- **Thanh công cụ:** 4 ô + 1 ô tay trái. Nhặt vũ khí hoặc đèn pin thì tự vào ô trống. Trong túi đồ kéo món vào ô, hoặc trỏ vào món rồi bấm 1–4 / F.
- **Túi đồ:** có ô trang bị (đầu, mắt, áo, giày, balo, cổ tay) và sức chứa theo balo.
- **Tủ chứa trong hầm:** kéo thả hai chiều, Space để chuyển hết.
- **Đồ chính:**
  - Vũ khí: súng lục + đạn, gậy sắt, ống tuýp, xà beng, chảo, bàn phím, cành cây; pháo và chai để ném.
  - Dụng cụ: đèn pin (chương 2 có sẵn, pin vô hạn), máy dò nhu yếu phẩm, kính nhìn đêm.
  - Đồ dùng: balo quân dụng 70 L, áo giáp, chăn, cà phê, thuốc đặc trị, kháng sinh, sơ cứu.
- **Chương 2:** nắp hầm thép rỉ sét nằm trong căn nhà đã sập; ống thông khí ở sân sau, khi gãy phải giữ E 5 giây để nối lại.
- **Kính nhìn đêm (phím N):** ảnh xanh lục có hạt nhiễu và khung ống kính. Nhìn rõ trong đêm mà không phát sáng nên không lộ vị trí.
- **Hội thoại:** phụ đề chữ chạy chậm, E để hiện hết hoặc sang dòng. Chơi một mình thì dừng cảnh khi đang thoại.
- **Xe máy:** E để lên/xuống. Âm thanh động cơ, cầm tay lái.

---

## 7. Hình ảnh nhân vật

- **Tay góc nhìn thứ nhất:**
  - Tay đơn giản đã duyệt (18/11): 4 ngón dính liền xếp dọc quấn quanh cán + 1 ngón cái ngắn gập vào bên phải, bàn tay dẹt, tay trần, ống tay áo khoác.
    Không có khung xương (`scripts/simple_hand.gd`, kiểu "mitt"), mỗi bàn tay gộp thành 1 mesh. Hai tư thế: nắm quanh cán (đèn pin, gậy, ống tuýp...) và nắm đấm (tay không).
    Model có khung xương cũ vẫn còn trong `fp_arms.gd` (tắt bằng `simple = true`).
  - Tay vẽ ở một lớp riêng (camera riêng, góc nhìn 50°) như các game FPS: không bị bộ lọc vẽ tay làm nhoè và không chui vào tường. Mọi nguồn sáng vẫn chiếu lên tay.
  - Da trơn, không găng.
  - Chỉ vẽ tay khi **tay không** hoặc **cầm đèn pin** (19/11). Cầm món khác (gậy, ống tuýp, xà beng, súng, chai...) thì chỉ hiện món đồ, không vẽ tay.
- **Cầm đèn pin (đã duyệt — ảnh mẫu tay 4 ngón, lựa chọn 1):**
  - Tay dựng đứng, thân đèn nằm chéo vào giữa màn hình như ảnh mẫu; ánh đèn vẫn chiếu theo hướng nhìn.
  - Tay trái thì lấy đối xứng; ánh đèn phát ra từ mặt kính.
- **Nhân vật ở gần** (Mai, bé Na, kẻ cướp, đồng nghiệp, người bị thương, người chơi khác):
  - Model người thật nam/nữ, có tóc, lông mày, mắt.
  - Quần áo tô theo vùng cơ thể và nhuộm màu riêng từng người.
  - Dùng lại hoạt ảnh sẵn có (đi, chạy, ngồi, bơi, đánh, ngã).
- **Bé Na (19/11):** model low-poly góc cạnh dựng bằng code (`scripts/lowpoly_humanoid.gd`): đầu to, chân ngắn, tóc đen dài, áo phông vàng, quần jean xắn gấu, giày đỏ đế trắng. Dùng lại hoạt ảnh của Humanoid.
- **Đám đông 130 dân thường:** model khối nhẹ có mặt, tóc, ngón tay; chi tiết nhỏ chỉ vẽ trong vòng 22 m.

---

## 8. Kiểm thử tự động (`tests/`)

Lệnh chạy: `godot --headless --path . --fixed-fps 60 res://tests/<tên>.tscn`.
Bài co-op chạy 2 tiến trình: `-- host`, sau vài giây chạy `-- join`.

| Bài | Kiểm tra |
|---|---|
| `smoke` | Chơi đơn cơ bản chương 1 |
| `hotbar_test` | Thanh công cụ, tay trái, đổi tay |
| `monster_test` | Hành vi từng loài quái (33 con) |
| `shelter_test` | Tự chơi hết chương 2: lấy thuốc qua két, đánh cướp, vác xác, vác máy, kết tốt + 2 kết xấu, đủ 10 sự kiện |
| `tower_test` | Quỷ Mắt: đứng im không bị thấy, đi lại bị bắt, rơi máy, mất máu, đập để thoát, trong nhà an toàn |
| `route_test` | Mở đầu chương 1 và đường chỉ dẫn (60 đường ngẫu nhiên: không gấp góc, không xuyên nhà) |
| `rail_test` | Đường sắt trên cao |
| `soak` | Chơi dài 3 phút để bắt lỗi |
| `net_test`, `net2_test`, `net3_test` | Co-op: đồng bộ cơ bản / chương 2 bỏ phiếu + xúc xắc / Quỷ Mắt bắt người, đồng đội cứu |
| `shot` | Chụp ảnh các cảnh để duyệt hình ảnh |
| `arms_view`, `arms_ref` | Ảnh duyệt tư thế tay cũ (model khung xương) |
| `simple_hand_view` | Ảnh duyệt tay đơn giản (`kiểu:nắm:xoay:fx:nghiêng`) |

**Lần chạy gần nhất:** tất cả đạt. Riêng `shelter_test` có một lần báo lỗi ở bước "đã có một trận cướp phá cửa", chạy lại 2 lần đều đạt. Bài này phụ thuộc yếu tố ngẫu nhiên, cần sửa cho ổn định.

---

## 9. Tài nguyên bên ngoài và giấy phép

| Loại | Nguồn | Giấy phép |
|---|---|---|
| Texture | ambientCG | CC0 |
| Âm thanh (súng, kính vỡ, phá cửa, gỗ, kim loại) | OpenGameArt, nguồn chi tiết ở `assets/sfx/NGUON-AM-THANH.txt` | CC0 |
| Âm thanh khác | Tổng hợp bằng `tools/make_sfx.py` | Tự làm |
| Model người, tóc | Quaternius — Universal Base Characters (bản Standard), ghi ở `assets/models/hero/NGUON.txt` | CC0 |

---

## 10. Cấu trúc mã nguồn

- `scripts/main.gd`: thế giới, người chơi, nhiệm vụ chương 1, tương tác, mạng.
- `scripts/game.gd`: chỉ số, túi đồ, thanh công cụ, cài đặt. `scripts/net.gd`: kết nối mạng.
- `scripts/player.gd`: điều khiển người chơi, tay góc nhìn thứ nhất, đèn pin, xe máy.
- `scripts/fp_arms.gd`: tay góc nhìn thứ nhất (lớp vẽ riêng; đặt bàn tay đơn giản theo điểm nắm).
- `scripts/simple_hand.gd`: dựng bàn tay đơn giản bằng khối tròn rồi gộp thành 1 mesh.
- `scripts/humanoid.gd`: hình người dựng bằng khối và hoạt ảnh. `scripts/hero_humanoid.gd`: hình người dùng model thật.
- `scripts/shelter.gd`, `scripts/shelter_events.gd`: chương 2 (hầm, khẩu phần, sự kiện, cốt truyện, kết thúc).
- `scripts/world/`:
  - `city.gd`: dựng thành phố, công trình, đường chỉ dẫn. `rail.gd`: đường sắt trên cao.
  - `loot.gd`: đồ đạc. `weather.gd`: ngày đêm, thời tiết, mất điện.
  - `npcs.gd`, `civs.gd`: người trong thành phố. `bikes.gd`: xe máy.
- `scripts/monsters/`: `manager.gd` và từng loài (`titan`, `worm`, `stalker`, `flyer`, `grub`, `crawler`, `robber`, `tower_eye`).
- `scripts/ui/`: HUD, túi đồ, bản đồ, hội thoại, giao diện hầm, kính nhìn đêm, tạm dừng, kết thúc.
- `shaders/`: lọc vẽ tay, bầu trời, nước, da/quần áo nhân vật, kính nhìn đêm.
- `KE-HOACH.md`: kế hoạch chi tiết và các quyết định đã chốt.

---

## 11. Việc còn dở / chờ duyệt

**Chờ bạn duyệt** (mỗi phần sẽ có ảnh duyệt trước rồi mới đưa vào game):
- [ ] Tư thế cầm gậy và nắm đấm: đã làm theo cùng kiểu nắm phương án A (gậy xuyên qua nắm tay, ngón cái gập vào), cần bạn chơi thử duyệt lại.
- [ ] Kiểu tay áo ở cẳng tay (hiện chỉ là phần áo màu xám).
- [ ] 4 sự kiện đêm 7–10.

**Vấn đề đã biết:**
- [x] Thủy Quái đi xuyên nhà (19/11): gối gập trước/sau thay vì chĩa ngang, chân đặt sát tim đường; lúc đi lang thang mỗi bước chọn chỗ trống gần nhất (lòng đường, vỉa hè, sân, đống đổ nát) cho cả bàn chân. Khi đuổi / giẫm người chơi vẫn giẫm phá nhà thường; nhà cốt truyện luôn tránh. Đi vòng tháp phát sóng. Bài đo `titan_step_test`: chân xuyên nhà từ 57% thời gian xuống 0%.
- [x] Quỷ Mắt (19/11): thân sần sùi loang lổ mạch máu, khoảng 120 hốc sâu lỗ chỗ (vài hốc có mắt nhỏ đảo qua lại); mắt đầu xúc tu nằm trong bọc thịt có mí (chớp, trợn to khi đuổi), con ngươi dọc; bỏ hình nón ánh sáng, ánh rọi dịu màu vàng xanh; xúc tu uốn lượn như sóng.
- [x] Bạch Trùng: thân trườn liền mạch theo đầu (trước đây đứng rồi giật từng nấc 0,5m); Thổ Trùng phóng lên vẽ theo từng khung hình (19/11).
- [x] Cú đánh của người chơi 3 pha: lấy đà (giơ gậy cao bên phải / rụt nắm đấm) → vụt chéo xuống / thúc thẳng → thu tay; cả hai tay lắc theo (19/11). Ảnh: `tests/shot.tscn -- swing`.
- [x] Model người: thay bằng model low-poly góc cạnh dựng bằng code (`scripts/lowpoly_humanoid.gd`) cho gia đình, người chơi (cả co-op), kẻ cướp (áo hoodie trùm đầu, khăn bịt mặt), đồng nghiệp, người bị thương (19/11). Ảnh duyệt: `tests/shot.tscn -- lineup`.
- [x] Crash khi nhặt đồ rơi trên đất (loot.gd `_cl_emptied`) đã sửa, có bài `pickup_test` (19/11).
- [x] Quái xuyên tường: Bạch Trùng trải thân dọc đường khi tạo; Săn Mồi quay dọc đường khi tạo và lùi lại khi lách kẹt sát tường. Bài đo `wall_test` (19/11): Bạch Trùng 0%, mũi Săn Mồi 0,3%.
- [ ] `shelter_test` thỉnh thoảng báo lỗi do yếu tố ngẫu nhiên.
- [x] `README.md` và `HUONG-DAN.txt` đã cập nhật điều khiển mới (19/11).
- [ ] Các con số độ khó (Quỷ Mắt, cướp, khẩu phần) mới chỉnh theo kiểm thử, chưa ai chơi thật.
