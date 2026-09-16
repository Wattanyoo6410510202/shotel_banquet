# API ส่งออกข้อมูลใบเสนอราคา (สำหรับระบบภายนอก)

เอกสารนี้สำหรับทีมพัฒนาเว็บจัดเลี้ยงอีกเว็บ ที่ต้องการดึงข้อมูลใบเสนอราคาทั้งหมดของเว็บนี้ไปใช้งาน

Endpoint นี้เป็น **Supabase RPC โดยตรง** — ไม่มีเซิร์ฟเวอร์กลางของเว็บนี้เกี่ยวข้อง เรียกได้ทันทีจากฝั่ง server ของเว็บปลายทาง

## Endpoint

```
POST https://govmturozgtfvllvnvap.supabase.co/rest/v1/rpc/export_quotations
```

เรียกแบบ `GET` ก็ได้เช่นกัน (ดูตัวอย่างด้านล่าง)

## การยืนยันตัวตน (Auth)

ต้องส่ง **2 อย่าง** พร้อมกันทุกครั้ง:

1. Header `apikey` — public key คงที่ของโปรเจกต์นี้:
   ```
   sb_publishable_N9psu9QmYz3hcIcPiasFdw_sMzcFukU
   ```
2. พารามิเตอร์ `p_key` (ใน body หรือ query string) — รหัสลับเฉพาะของ endpoint นี้:
   ```
   NNP3FB1CApxXNDuEDmkXG5NGwnhUe0zW
   ```
   ถ้า `p_key` ผิดหรือไม่ได้ส่งมา จะได้ error กลับไปทันที ไม่มีข้อมูลหลุดออกไป

> **สำคัญ:** ห้ามฝัง `p_key` ไว้ในโค้ดฝั่ง browser/frontend ของเว็บปลายทางเด็ดขาด ให้เรียก endpoint นี้จากฝั่ง server เท่านั้น (Node/PHP/Python ฯลฯ) แล้วค่อยส่งข้อมูลต่อให้ frontend ของตัวเอง

## ตัวอย่างการเรียกใช้

### cURL — POST
```bash
curl -X POST 'https://govmturozgtfvllvnvap.supabase.co/rest/v1/rpc/export_quotations' \
  -H 'apikey: sb_publishable_N9psu9QmYz3hcIcPiasFdw_sMzcFukU' \
  -H 'Content-Type: application/json' \
  -d '{"p_key": "NNP3FB1CApxXNDuEDmkXG5NGwnhUe0zW"}'
```

### cURL — GET
```bash
curl 'https://govmturozgtfvllvnvap.supabase.co/rest/v1/rpc/export_quotations?p_key=NNP3FB1CApxXNDuEDmkXG5NGwnhUe0zW' \
  -H 'apikey: sb_publishable_N9psu9QmYz3hcIcPiasFdw_sMzcFukU'
```

### JavaScript (Node.js / server-side fetch)
```js
const res = await fetch('https://govmturozgtfvllvnvap.supabase.co/rest/v1/rpc/export_quotations', {
  method: 'POST',
  headers: {
    apikey: 'sb_publishable_N9psu9QmYz3hcIcPiasFdw_sMzcFukU',
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ p_key: 'NNP3FB1CApxXNDuEDmkXG5NGwnhUe0zW' }),
});
if (!res.ok) throw new Error('export failed: ' + res.status);
const quotations = await res.json();
```

### PHP
```php
$ch = curl_init('https://govmturozgtfvllvnvap.supabase.co/rest/v1/rpc/export_quotations');
curl_setopt_array($ch, [
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => json_encode(['p_key' => 'NNP3FB1CApxXNDuEDmkXG5NGwnhUe0zW']),
    CURLOPT_HTTPHEADER => [
        'apikey: sb_publishable_N9psu9QmYz3hcIcPiasFdw_sMzcFukU',
        'Content-Type: application/json',
    ],
    CURLOPT_RETURNTRANSFER => true,
]);
$quotations = json_decode(curl_exec($ch), true);
curl_close($ch);
```

## Response

`200 OK` — คืน JSON array ของใบเสนอราคา**ทั้งหมด** เรียงจากสร้างล่าสุดไปเก่าสุด (`created_at` desc) แต่ละรายการมีทุกฟิลด์ของใบเสนอราคา บวกฟิลด์ `items` (array ของรายการอาหารในใบนั้น)

### ตัวอย่างโครงสร้าง

```json
[
  {
    "id": "5f1c2e3a-...-uuid",
    "quote_no": "QT2609-0001",
    "status": "sent",
    "customer_name": "คุณสมชาย ใจดี",
    "company": "บริษัท ABC จำกัด",
    "phone": "0812345678",
    "email": "somchai@example.com",
    "event_name": "งานเลี้ยงปีใหม่บริษัท",
    "event_type": "งานเลี้ยงบริษัท",
    "event_date": "2026-12-05",
    "event_time": "ช่วงเย็น",
    "venue": null,
    "guest_count": 200,
    "notes": "แพ้อาหารทะเล 3 ท่าน",
    "discount": 0,
    "service_charge_pct": 10,
    "vat_pct": 7,
    "subtotal": 60000,
    "service_charge": 6000,
    "vat": 4620,
    "grand_total": 70620,
    "valid_until": "2026-12-31",
    "access_token": "a1b2c3d4-...-uuid",
    "source": "web",
    "internal_note": null,
    "created_by": null,
    "created_at": "2026-09-14T10:00:00+00:00",
    "updated_at": "2026-09-14T10:05:00+00:00",
    "items": [
      {
        "id": 101,
        "quotation_id": "5f1c2e3a-...-uuid",
        "menu_item_id": 12,
        "category_name": "อาหารว่าง (Coffee Break)",
        "name": "Coffee Break เบเกอรี่ 150.-",
        "description": "คัสตาร์ดเค้ก เอแคร์ ...",
        "unit": "ท่าน",
        "per_person": true,
        "qty": 200,
        "unit_price": 150,
        "amount": 30000,
        "sort_order": 1
      }
    ]
  }
]
```

## คำอธิบายฟิลด์

### ใบเสนอราคา (แต่ละ object ใน array)

| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| `id` | uuid | รหัสใบเสนอราคา |
| `quote_no` | text | เลขที่เอกสาร เช่น `QT2609-0001` (รีเซ็ตทุกเดือน) |
| `status` | text | `new` (คำขอใหม่) / `draft` (ฉบับร่าง) / `sent` (ส่งลูกค้าแล้ว) / `confirmed` (ยืนยันแล้ว) / `cancelled` (ยกเลิก) |
| `customer_name` | text | ชื่อผู้ติดต่อ |
| `company` | text \| null | บริษัท/หน่วยงาน |
| `phone` | text \| null | เบอร์โทรศัพท์ |
| `email` | text \| null | อีเมล |
| `event_name` | text \| null | ชื่องาน |
| `event_type` | text \| null | ประเภทงาน: `สัมมนา / ประชุม`, `งานเลี้ยงบริษัท`, `งานแต่งงาน`, `งานวันเกิด`, `อื่นๆ` |
| `event_date` | date \| null | วันที่จัดงาน (`YYYY-MM-DD`) |
| `event_time` | text \| null | ช่วงเวลา: `ช่วงเช้า`, `ช่วงกลางวัน`, `ช่วงเย็น`, `ทั้งวัน` |
| `venue` | text \| null | สถานที่/ห้องจัดเลี้ยง |
| `guest_count` | int | จำนวนแขก (ท่าน) |
| `notes` | text \| null | หมายเหตุจากลูกค้า |
| `discount` | numeric | ส่วนลด (บาท) |
| `service_charge_pct` | numeric | % ค่าบริการ |
| `vat_pct` | numeric | % ภาษีมูลค่าเพิ่ม |
| `subtotal` | numeric | รวมค่าอาหารก่อนหักส่วนลด/ค่าบริการ/ภาษี |
| `service_charge` | numeric | ค่าบริการ (บาท) |
| `vat` | numeric | ภาษีมูลค่าเพิ่ม (บาท) |
| `grand_total` | numeric | ยอดรวมสุทธิ |
| `valid_until` | date \| null | ใบเสนอราคายืนราคาถึงวันที่ |
| `access_token` | uuid | โทเค็นที่ลูกค้าใช้ดูใบเสนอราคาของตัวเอง (ใช้กับ `request.html?t=<access_token>` ของเว็บนี้) |
| `source` | text | `web` (ลูกค้าส่งคำขอเอง) หรือ `staff` (พนักงานสร้างให้) |
| `internal_note` | text \| null | โน้ตภายใน ใช้เฉพาะพนักงานเว็บนี้ |
| `created_by` | uuid \| null | รหัสพนักงานที่สร้าง (`null` ถ้าลูกค้าส่งเอง) |
| `created_at` | timestamptz | วันเวลาที่สร้าง (ISO 8601, timezone UTC) |
| `updated_at` | timestamptz | วันเวลาที่แก้ไขล่าสุด |
| `items` | array | รายการอาหาร/แพ็กเกจในใบนี้ (โครงสร้างด้านล่าง) |

### รายการอาหาร (แต่ละ object ใน `items`)

| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| `id` | bigint | รหัสรายการ |
| `quotation_id` | uuid | อ้างอิงใบเสนอราคาที่รายการนี้อยู่ |
| `menu_item_id` | bigint \| null | อ้างอิงเมนูต้นทาง (`null` ถ้าเป็นรายการพิมพ์เอง หรือเมนูต้นทางถูกลบไปแล้ว) |
| `category_name` | text \| null | ชื่อหมวดหมู่ ณ ตอนบันทึก (แพ็กเกจจะเป็น `"แพ็กเกจอาหาร"`) |
| `name` | text | ชื่อเมนู/แพ็กเกจ |
| `description` | text \| null | คำอธิบาย — ถ้าเป็นแพ็กเกจจะมีรายละเอียดคอร์ส/เมนูที่เลือกอยู่ในนี้ (คั่นด้วยขึ้นบรรทัดใหม่) |
| `unit` | text | หน่วย เช่น `ท่าน`, `โต๊ะ`, `จาน` |
| `per_person` | boolean | คิดราคาต่อท่านหรือไม่ (ถ้าใช่ `qty` = จำนวนแขกของใบนั้น) |
| `qty` | numeric | จำนวน |
| `unit_price` | numeric | ราคาต่อหน่วย (บาท) |
| `amount` | numeric | `qty × unit_price` (คำนวณอัตโนมัติ) |
| `sort_order` | int | ลำดับการแสดงผล |

## รหัสข้อผิดพลาด

| กรณี | ผลลัพธ์ |
|---|---|
| เรียกสำเร็จ | `200 OK` + JSON array |
| `p_key` ผิดหรือไม่ได้ส่ง | error พร้อมข้อความ `unauthorized` |
| header `apikey` ผิดหรือไม่ได้ส่ง | `401`/`403` จาก Supabase (ไปไม่ถึงฟังก์ชันของเรา) |

## ความปลอดภัย / ข้อควรระวัง

- ข้อมูลนี้มี**ข้อมูลส่วนบุคคลของลูกค้าจริง** (ชื่อ เบอร์โทร อีเมล) — ใช้เท่าที่จำเป็น ห้ามเผยแพร่ต่อหรือเก็บไว้นานเกินความจำเป็น
- `p_key` ห้ามฝังในโค้ดฝั่ง browser/frontend เด็ดขาด ให้เรียกจากฝั่ง server เท่านั้น
- Endpoint นี้เป็น **read-only** — ดึงข้อมูลได้อย่างเดียว แก้ไข/ลบข้อมูลไม่ได้
- รหัสลับหมุนได้ทุกเมื่อ (แก้ค่า `v_secret` ในฟังก์ชัน `export_quotations` บน Supabase SQL Editor แล้วรันใหม่) — ถ้าหมุนแล้วต้องแจ้งทีมเว็บปลายทางให้เปลี่ยนตามด้วย
