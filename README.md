# Thức Giấc — bản Godot 4.7

Game sinh tồn lén lút 3D, chơi đơn hoặc co-op tối đa 4 người.

## Chạy game
- **Bản đóng gói:** giải nén `ThucGiac-windows.zip`, chạy `ThucGiac.exe` (giữ `ThucGiac.pck` cạnh nó).
- **Từ mã nguồn:** mở Godot 4.7.2, Import `project.godot`, bấm F5.

## Điều khiển
WASD đi · Shift chạy · C ngồi · Space nhảy · E tương tác (nhặt đồ, mở tủ, nói chuyện, lên/xuống xe máy) · Giữ E lấy hết đồ trong tủ
Chuột trái dùng món đang cầm · Chuột phải dùng món tay trái · 1–4 / lăn chuột chọn ô · F đổi tay · Q ném pháo/chai
Tab túi đồ · M bản đồ · Z phóng bản đồ nhỏ · L đèn pin · N kính nhìn đêm · V đổi góc nhìn · Esc tạm dừng/cài đặt
Dưới nước: Space nổi lên · C lặn · nhìn xuống + W bơi xuống · sát bờ giữ Space để leo lên.

## Chơi chung
Một người bấm **Mở phòng** và đọc địa chỉ IP (hiện ở menu và góc màn hình) cho bạn bè; bạn bè nhập IP rồi **Vào phòng**.
Cần cùng mạng LAN hoặc cùng mạng ảo (Radmin VPN, Hamachi, Tailscale, ZeroTier). Cổng UDP 24680.

## Cấu trúc
- `scripts/main.gd` — thế giới: người chơi, nhiệm vụ, điều phối.
- `scripts/world/` — `city.gd` dựng thành phố bằng code; `weather.gd` thời tiết + ngày đêm; `loot.gd` đồ đạc; `npcs.gd`; `fx.gd`.
- `scripts/monsters/` — 5 loại quái vật + `manager.gd` (trí khôn chạy ở máy chủ phòng).
- `scripts/ui/` — HUD, túi đồ, bản đồ, tạm dừng, kết thúc.
- `scripts/game.gd` — chỉ số, thương tích, túi đồ của người chơi. `scripts/net.gd` — mạng.
- `assets/tex` — texture CC0 từ ambientCG. `assets/sfx` — âm thanh tổng hợp bằng `tools/make_sfx.py`.
- `tests/` — kiểm thử tự động: `smoke` (chơi đơn), `monster_test`, `net_test` (2 tiến trình), `shot` (chụp ảnh).

Chạy kiểm thử: `godot --headless --path . --fixed-fps 60 res://tests/smoke.tscn`

Đóng gói Windows (không cần export templates): `godot --headless --path . --export-pack Windows <thư mục>/ThucGiac.pck`, rồi chép file `Godot_v4.7.2-stable_win64.exe` vào cùng thư mục và đổi tên thành `ThucGiac.exe`.
