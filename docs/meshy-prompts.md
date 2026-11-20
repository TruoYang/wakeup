# Prompt Meshy cho Thức Giấc (bản web miễn phí)

## Cách làm
1. Vào meshy.ai → **Text to 3D**.
2. Dán **Prompt** vào ô mô tả. Nếu có ô **Negative prompt** thì dán phần đó vào.
3. Cài đặt nên chọn (nếu có):
   - **Topology:** Triangle
   - **Polycount:** thấp nhất có thể (khoảng 10k cho người, 15k cho quái)
   - **Pose:** A-pose hoặc T-pose với nhân vật người (để gắn khung xương)
4. Ra 4 bản nháp, chọn bản góc cạnh nhất → bấm **Texture** / **Refine**.
5. Tải về định dạng **GLB**, đặt tên đúng như dưới, chép vào `assets/models/meshy/`.
6. Báo tôi để tôi đưa vào game, gắn khung xương, hoạt ảnh và chụp ảnh duyệt.

## Đoạn phong cách chung (đã có sẵn trong từng prompt)
`stylized low-poly, faceted, hard edges, flat shading, chunky simple shapes, flat painted colors, no small details`

## Negative prompt chung
`realistic, photorealistic, smooth subdivided surface, high detail, fine wrinkles, noisy texture, text, logo`

---

## 1. Anh (nhân vật chính) — `hero_man.glb`
Vietnamese office worker man in his 30s, short black hair, light blue rolled-up shirt, dark trousers, sneakers, tired face, full body, A-pose, stylized low-poly, faceted, hard edges, flat shading, chunky simple shapes, flat painted colors, no small details

## 2. Mai (vợ) — `mai.glb`
Vietnamese woman in her 30s, long straight black hair, simple pink t-shirt, dark long pants, house slippers, gentle worried face, full body, A-pose, stylized low-poly, faceted, hard edges, flat shading, chunky simple shapes, flat painted colors, no small details

## 3. Bé Na (con gái) — `na.glb`
Vietnamese girl about 7 years old, child proportions with big head and small body, long black hair, yellow t-shirt, blue jeans, small sneakers, full body, A-pose, stylized low-poly, faceted, hard edges, flat shading, chunky simple shapes, flat painted colors, no small details

## 4. Kẻ cướp — `robber.glb`
Thin rough man, dark hoodie, cloth mask covering nose and mouth, worn cargo pants, boots, menacing posture, full body, A-pose, stylized low-poly, faceted, hard edges, flat shading, chunky simple shapes, dark muted flat colors, no small details

## 5. Dân thường (làm vài bản, đổi màu áo) — `civ_1.glb`, `civ_2.glb`…
Ordinary Vietnamese city person, casual clothes, t-shirt and jeans, full body, A-pose, very low-poly, faceted, hard edges, flat shading, very simple shapes, flat colors, no small details

## 6. Cua Quỷ (kiểu Chomper Beast) — `crab_demon.glb`
Horror monster: a bloated pale pink flesh body with a huge gaping mouth on its back full of two rings of jagged teeth, red swollen lips, ten long thin curved spider legs spreading around the body, many small black eyes clustered on the front, bumpy skin with dark red veins, menacing, stylized low-poly, faceted, hard edges, flat shading, chunky simple shapes, flat painted colors, no small details

Mẹo: nếu ra quá dễ thương, thêm `grotesque, disturbing, horror creature` vào đầu prompt. Nếu chân bị dính vào nhau, thử **Image to 3D**: tải ảnh mẫu Chomper Beast rồi ghi chú thêm chân nhện.
