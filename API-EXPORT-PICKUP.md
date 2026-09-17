# API ส่งออกข้อมูล "ลิงก์เลือกอาหาร" (สำหรับระบบภายนอก)

เอกสารนี้สำหรับทีมพัฒนาเว็บจัดเลี้ยงอีกเว็บ (manage_banquet) ที่ต้องการดึงข้อมูลว่าลูกค้าเลือกเมนูอาหารอะไรไว้ผ่านลิงก์ "เลือกเมนูอาหาร" (food-pick.html) ของเว็บนี้

Endpoint นี้เป็น **Supabase RPC โดยตรง** — ไม่มีเซิร์ฟเวอร์กลางของเว็บนี้เกี่ยวข้อง เรียกได้ทันทีจากฝั่ง server ของเว็บปลายทาง เหมือนกับ `export_quotations` (ดู `API-EXPORT.md`) — ใช้รหัสลับ `p_key` ตัวเดียวกัน

## Endpoint

```
POST https://govmturozgtfvllvnvap.supabase.co/rest/v1/rpc/export_pickup_selections
```

เรียกแบบ `GET` ก็ได้เช่นกัน

## การยืนยันตัวตน (Auth)

ต้องส่ง **2 อย่าง** พร้อมกันทุกครั้ง:

1. Header `apikey` — public key คงที่ของโปรเจกต์นี้:
   ```
   sb_publishable_N9psu9QmYz3hcIcPiasFdw_sMzcFukU
   ```
2. พารามิเตอร์ `p_key` (ใน body หรือ query string) — รหัสลับ (ตัวเดียวกับ `export_quotations`):
   ```
   NNP3FB1CApxXNDuEDmkXG5NGwnhUe0zW
   ```
   ถ้า `p_key` ผิดหรือไม่ได้ส่งมา จะได้ error กลับไปทันที ไม่มีข้อมูลหลุดออกไป

> **สำคัญ:** ห้ามฝัง `p_key` ไว้ในโค้ดฝั่ง browser/frontend ของเว็บปลายทางเด็ดขาด ให้เรียก endpoint นี้จากฝั่ง server เท่านั้น

## ตัวอย่างการเรียกใช้

### cURL — POST
```bash
curl -X POST 'https://govmturozgtfvllvnvap.supabase.co/rest/v1/rpc/export_pickup_selections' \
  -H 'apikey: sb_publishable_N9psu9QmYz3hcIcPiasFdw_sMzcFukU' \
  -H 'Content-Type: application/json' \
  -d '{"p_key": "NNP3FB1CApxXNDuEDmkXG5NGwnhUe0zW"}'
```

### JavaScript (Node.js / server-side fetch)
```js
const res = await fetch('https://govmturozgtfvllvnvap.supabase.co/rest/v1/rpc/export_pickup_selections', {
  method: 'POST',
  headers: {
    apikey: 'sb_publishable_N9psu9QmYz3hcIcPiasFdw_sMzcFukU',
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ p_key: 'NNP3FB1CApxXNDuEDmkXG5NGwnhUe0zW' }),
});
if (!res.ok) throw new Error('export failed: ' + res.status);
const links = await res.json();
```

### PHP
```php
$ch = curl_init('https://govmturozgtfvllvnvap.supabase.co/rest/v1/rpc/export_pickup_selections');
curl_setopt_array($ch, [
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => json_encode(['p_key' => 'NNP3FB1CApxXNDuEDmkXG5NGwnhUe0zW']),
    CURLOPT_HTTPHEADER => [
        'apikey: sb_publishable_N9psu9QmYz3hcIcPiasFdw_sMzcFukU',
        'Content-Type: application/json',
    ],
    CURLOPT_RETURNTRANSFER => true,
]);
$links = json_decode(curl_exec($ch), true);
curl_close($ch);
```

## Response

`200 OK` — คืน JSON array ของลิงก์เลือกอาหาร**ทุกลิงก์ ทุกสถานะ** (ทั้งที่ลูกค้ายังไม่เลือกและเลือกแล้ว) เรียงจากสร้างล่าสุดไปเก่าสุด (`created_at` desc)

### ตัวอย่างโครงสร้าง — ลิงก์ที่ลูกค้าเลือกเมนูแล้ว

```json
[
  {
    "token": "440c019a-fa1e-4193-b913-a48da1064037",
    "external_quote_no": "QT-20260729-0836/2",
    "customer_name": "พิสชา อัศวเดชกำจร",
    "phone": "086-968-8345",
    "event_name": "งานเลี้ยงเกษียณ",
    "event_date": "2026-09-11",
    "guest_count": null,
    "note": null,
    "status": "submitted",
    "packages": [
      { "id": 1, "name": "Thai Set 3,000", "unit_price": 3000, "unit": "โต๊ะ", "per_person": false, "serves": 10 }
    ],
    "selections": [
      {
        "package_id": 1,
        "package_name": "Thai Set 3,000",
        "description": "เมนูผัด: ไข่เยี่ยวม้าผัดใบกะเพรากรอบ\nเมนูทอด: ไข่ลูกเขย\nเมนูยำ: ยำไข่ดาว\nเมนูแกง/เมนูต้ม: แกงไตปลาปักษ์ใต้\nรายการที่ 6: เฉาก๋วย",
        "note": null,
        "unit_price": 3000,
        "unit": "โต๊ะ",
        "per_person": false,
        "serves": 10
      }
    ],
    "extra_items": [
      { "menu_item_id": 200, "name": "Soft Drink", "unit": "โต๊ะ", "per_person": false, "qty": 3, "unit_price": 200 }
    ],
    "created_at": "2026-09-17T02:10:00+00:00",
    "submitted_at": "2026-09-17T03:05:00+00:00"
  }
]
```

ลิงก์ที่ลูกค้ายังไม่ได้เลือก (`status: "pending"`) จะมี `selections`, `extra_items`, `submitted_at` เป็น `null`

## คำอธิบายฟิลด์

| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| `token` | uuid | โทเค็นของลิงก์ (ใช้ต่อกับ `food-pick.html?t=<token>` ของเว็บนี้ได้) |
| `external_quote_no` | text \| null | เลขที่อ้างอิงใบเสนอราคาฝั่ง manage_banquet ที่ผูกกับลิงก์นี้ตอนสร้าง |
| `customer_name` | text | ชื่อผู้ติดต่อ |
| `phone` | text \| null | เบอร์โทรศัพท์ |
| `event_name` | text \| null | ชื่องาน |
| `event_date` | date \| null | วันที่จัดงาน |
| `guest_count` | int \| null | จำนวนแขก (ท่าน) — ถ้าตอนสร้างลิงก์ไม่ได้กรอกไว้จะเป็น `null` |
| `note` | text \| null | หมายเหตุตอนสร้างลิงก์ (ฝั่งพนักงาน) |
| `status` | text | `pending` (รอลูกค้าเลือก) หรือ `submitted` (ลูกค้าเลือกแล้ว) |
| `packages` | array | แพ็กเกจที่อนุญาตให้เลือกในลิงก์นี้ พร้อมราคา — มีค่าเสมอไม่ว่าจะ submit แล้วหรือยัง (ดูโครงสร้างด้านล่าง) |
| `selections` | array \| null | รายการที่ลูกค้าเลือกจริง ต่อแพ็กเกจ (`null` ถ้ายังไม่ submit) — ดูโครงสร้างด้านล่าง |
| `extra_items` | array \| null | เมนูเสริมนอกแพ็กเกจที่ลูกค้าเลือกเพิ่ม เช่น Coffee Break/เครื่องดื่ม (`null` ถ้ายังไม่ submit หรือไม่ได้เลือกอะไรเพิ่ม) |
| `created_at` | timestamptz | วันเวลาที่สร้างลิงก์ |
| `submitted_at` | timestamptz \| null | วันเวลาที่ลูกค้ากดส่ง (`null` ถ้ายังไม่ submit) |

### `packages[]`

| ฟิลด์ | คำอธิบาย |
|---|---|
| `id` / `name` | รหัส/ชื่อแพ็กเกจ |
| `unit_price` | ราคาต่อหน่วย ณ **ปัจจุบัน** (บาท) — ไม่ใช่ราคา ณ วันที่ลูกค้าเลือก ถ้าพนักงานแก้ราคาแพ็กเกจทีหลัง ค่านี้จะเปลี่ยนตาม |
| `unit` | หน่วยราคา เช่น `โต๊ะ` |
| `per_person` | คิดราคาต่อท่านหรือไม่ (ถ้าใช่ ต้องคูณด้วยจำนวนแขกของงานนั้นเอง — ระบบนี้ไม่ได้เก็บจำนวนแขกที่แน่นอนไว้ในทุกลิงก์) |
| `serves` | 1 หน่วย (เช่น 1 โต๊ะ) นั่งได้กี่ท่าน — ใช้คำนวณจำนวนหน่วยจากจำนวนแขกเองได้ ถ้า `per_person` เป็น false |

### `selections[]`

| ฟิลด์ | คำอธิบาย |
|---|---|
| `package_id` | รหัสแพ็กเกจ |
| `package_name` | ชื่อแพ็กเกจ ณ ตอนที่ลูกค้าเลือก |
| `description` | รายละเอียดที่เลือกในแต่ละคอร์ส คั่นด้วยขึ้นบรรทัดใหม่ (`ชื่อคอร์ส: ชื่อเมนู`) |
| `note` | หมายเหตุที่ลูกค้าใส่ให้แพ็กเกจนี้โดยเฉพาะ (`null` ถ้าไม่ได้ใส่) |
| `unit_price` / `unit` / `per_person` / `serves` | ราคาปัจจุบันของแพ็กเกจนี้ — ความหมายเดียวกับใน `packages[]` ด้านบน (ใส่ซ้ำมาให้ในบรรทัดนี้เลย ไม่ต้องย้อนไปหาใน `packages[]`) |

### `extra_items[]`

| ฟิลด์ | คำอธิบาย |
|---|---|
| `menu_item_id` | รหัสเมนู |
| `name` | ชื่อเมนู |
| `unit` | หน่วย เช่น `ท่าน`, `โต๊ะ` |
| `per_person` | คิดราคาต่อท่านหรือไม่ |
| `qty` | จำนวนที่ลูกค้าเลือก |
| `unit_price` | ราคาต่อหน่วย ณ **ปัจจุบัน** (บาท) — คูณกับ `qty` เองเพื่อได้ยอดรวมของรายการนี้ (ถ้า `per_person` เป็น true คือราคาต่อท่าน ไม่ใช่ราคารวม) |

## รหัสข้อผิดพลาด

| กรณี | ผลลัพธ์ |
|---|---|
| เรียกสำเร็จ | `200 OK` + JSON array |
| `p_key` ผิดหรือไม่ได้ส่ง | error พร้อมข้อความ `unauthorized` |
| header `apikey` ผิดหรือไม่ได้ส่ง | `401`/`403` จาก Supabase (ไปไม่ถึงฟังก์ชันของเรา) |

## ความปลอดภัย / ข้อควรระวัง

- **ราคาที่ส่งออกมา (`unit_price` ทุกจุด) เป็นราคาปัจจุบัน ไม่ใช่ราคา ณ วันที่ลูกค้าเลือกเมนู** — เว็บนี้ไม่ได้เก็บราคาไว้ตอนลูกค้า submit จึงต้องไปดึงราคาล่าสุดจากเมนู/แพ็กเกจมาให้ทุกครั้งที่เรียก API นี้ ถ้าพนักงานแก้ราคาแพ็กเกจ/เมนูทีหลัง ราคาที่เคยดึงไปแล้วจะไม่อัปเดตตาม (ต้องเรียกซ้ำถึงจะได้ราคาใหม่)
- ข้อมูลนี้มี**ข้อมูลส่วนบุคคลของลูกค้าจริง** (ชื่อ เบอร์โทร) — ใช้เท่าที่จำเป็น ห้ามเผยแพร่ต่อหรือเก็บไว้นานเกินความจำเป็น
- `p_key` ห้ามฝังในโค้ดฝั่ง browser/frontend เด็ดขาด ให้เรียกจากฝั่ง server เท่านั้น
- Endpoint นี้เป็น **read-only** — ดึงข้อมูลได้อย่างเดียว แก้ไข/ลบข้อมูลไม่ได้
- รหัสลับตัวนี้ใช้ร่วมกับ `export_quotations` — ถ้าหมุนรหัสลับ (แก้ `v_secret` บน Supabase SQL Editor) ต้องแก้ **ทั้ง 2 ฟังก์ชัน** ให้ตรงกัน แล้วแจ้งทีมเว็บปลายทางให้เปลี่ยนตามด้วย
