
# API ส่งออกข้อมูลใบเสนอราคา (ระบบ manage_banquet นี้)

เอกสารนี้สำหรับทีมพัฒนาเว็บอื่นที่ต้องการดึงข้อมูลใบเสนอราคา**ทั้งหมด**ของระบบนี้ (`quotation_list.php`) ไปใช้งาน

Endpoint นี้รันอยู่บนเซิร์ฟเวอร์ PHP ของระบบนี้เอง — เรียกได้จากฝั่ง server ของเว็บปลายทางเท่านั้น (ห้ามฝัง key ไว้ฝั่ง browser)

## Endpoint

```
GET/POST https://nas909ssf.myqnapcloud.com:8081/manage_banquet/api/export_quotations.php
```

## การยืนยันตัวตน (Auth)

ส่ง secret key มาด้วยวิธีใดวิธีหนึ่ง:

1. Header `X-API-Key: <key>` (แนะนำ), หรือ
2. พารามิเตอร์ `key` (query string หรือ POST body)

ค่า key ปัจจุบันกำหนดไว้ในไฟล์ `api/export_quotations.php` (ค่าคงที่ `EXPORT_QUOTES_KEY`) — ถ้า key ผิดหรือไม่ได้ส่งมา จะได้ `401 unauthorized` ทันที

> **สำคัญ:** ห้ามฝัง key นี้ไว้ในโค้ดฝั่ง browser/frontend ของเว็บปลายทางเด็ดขาด ให้เรียก endpoint นี้จากฝั่ง server เท่านั้น แล้วค่อยส่งข้อมูลต่อให้ frontend ของตัวเอง

## ตัวอย่างการเรียกใช้

### cURL
```bash
curl 'https://<โดเมน>/api/export_quotations.php' \
  -H 'X-API-Key: <key>'
```

### PHP
```php
$ch = curl_init('https://<โดเมน>/api/export_quotations.php');
curl_setopt_array($ch, [
    CURLOPT_HTTPHEADER => ['X-API-Key: <key>'],
    CURLOPT_RETURNTRANSFER => true,
]);
$result = json_decode(curl_exec($ch), true);
curl_close($ch);
$quotations = $result['data'];
```

## Response

`200 OK`

```json
{
  "status": "success",
  "count": 61,
  "data": [
    {
      "id": 19,
      "quote_no": "QT-20260704-1518",
      "status": "Approved",
      "workflow_status": "Draft",
      "event_name": "งานสัมมนาและประชุม",
      "event_date": "2026-07-09",
      "expiry_date": "2026-07-09",
      "project_id": 27,
      "project_name": "งานสัมมนาและประชุม",
      "customer": {
        "id": 15,
        "name": "BNI",
        "contact_name": "คุณปอย",
        "phone": "",
        "email": "",
        "tax_id": "",
        "address": "",
        "sales_name": "น.ส. นิยะดา ชาปาน "
      },
      "subtotal": 15560.75,
      "discount": 0,
      "service_charge": 0,
      "vat": 1089.25,
      "vat_type": "include",
      "grand_total": 16650.00,
      "is_selected": false,
      "remarks": "",
      "lead_source": "",
      "result": "",
      "created_by": 21,
      "approved_by": 17,
      "approved_at": "2026-07-04 14:20:56",
      "created_at": "2026-07-04 07:20:42",
      "updated_at": "2026-07-11 08:15:27",
      "items": [
        {
          "id": 330,
          "item_name": "ห้องตะวัน จำนวน 50 ท่าน 13.00-17.00 น.",
          "quantity": 1,
          "unit_price": 12000,
          "total_price": 12000,
          "item_type": "Food"
        }
      ]
    }
  ]
}
```

## คำอธิบายฟิลด์

| ฟิลด์ | ชนิด | คำอธิบาย |
|---|---|---|
| `id` | int | รหัสใบเสนอราคา |
| `quote_no` | text | เลขที่เอกสาร |
| `status` | text | `Draft` / `Sent` / `Approved` / `Cancelled` |
| `workflow_status` | text \| null | สถานะ pipeline การติดตามงาน (เช่น Follow Up, ลูกค้าเซ็นยืนยัน ฯลฯ) |
| `event_name` | text \| null | ชื่องาน |
| `event_date` | date \| null | วันที่จัดงาน |
| `expiry_date` | date \| null | วันหมดอายุใบเสนอราคา |
| `project_id` / `project_name` | int/text \| null | โครงการที่ใบนี้สังกัด (ถ้ามี) |
| `customer` | object | ข้อมูลลูกค้า (ดูตารางย่อยด้านล่าง) |
| `subtotal` | numeric | รวมก่อนหักส่วนลด/ค่าบริการ/ภาษี |
| `discount` | numeric | ส่วนลด (บาท) |
| `service_charge` | numeric | ค่าบริการ (บาท) |
| `vat` | numeric | ภาษีมูลค่าเพิ่ม (บาท) |
| `vat_type` | text | `include`/`exclude` |
| `grand_total` | numeric | ยอดรวมสุทธิ |
| `is_selected` | boolean | ใบที่ถูกเลือกใช้งานจริงในโครงการ |
| `remarks` | text \| null | หมายเหตุ |
| `lead_source` | text \| null | ช่องทางที่ได้ลูกค้ามา |
| `result` | text \| null | ผลการติดตามงาน |
| `created_by` / `approved_by` | int \| null | รหัสผู้ใช้งานภายในที่สร้าง/อนุมัติ |
| `approved_at` / `created_at` / `updated_at` | datetime | เวลาที่เกี่ยวข้อง |
| `items` | array | รายการอาหาร/บริการในใบนี้ |

### `customer`

| ฟิลด์ | คำอธิบาย |
|---|---|
| `id` | รหัสลูกค้า |
| `name` | ชื่อลูกค้า/บริษัท |
| `contact_name` | ชื่อผู้ติดต่อ |
| `phone` / `email` | ข้อมูลติดต่อ |
| `tax_id` / `address` | เลขผู้เสียภาษี / ที่อยู่ |
| `sales_name` | ชื่อเซลล์ที่ดูแล |

### `items[]`

| ฟิลด์ | คำอธิบาย |
|---|---|
| `id` | รหัสรายการ |
| `item_name` | ชื่อรายการ |
| `quantity` | จำนวน |
| `unit_price` | ราคาต่อหน่วย |
| `total_price` | `quantity × unit_price` |
| `item_type` | `Food` / `Beverage` / `Room` / `Equipment` / `Other` |

## ขอบเขตข้อมูล

ส่งออก**ใบเสนอราคาทุกสถานะ** (Draft, Sent, Approved, Cancelled) เรียงจากสร้างล่าสุดไปเก่าสุด (`created_at` desc)

## รหัสข้อผิดพลาด

| กรณี | ผลลัพธ์ |
|---|---|
| เรียกสำเร็จ | `200 OK` + `{"status":"success", ...}` |
| key ผิดหรือไม่ได้ส่ง | `401` + `{"status":"error","message":"unauthorized"}` |
| query ผิดพลาดฝั่งเซิร์ฟเวอร์ | `500` + `{"status":"error","message":"query failed"}` |

## ความปลอดภัย / ข้อควรระวัง

- ข้อมูลนี้มี**ข้อมูลส่วนบุคคลของลูกค้าจริง** (ชื่อ เบอร์โทร อีเมล ที่อยู่) — ใช้เท่าที่จำเป็น ห้ามเผยแพร่ต่อหรือเก็บไว้นานเกินความจำเป็น
- key ห้ามฝังในโค้ดฝั่ง browser/frontend เด็ดขาด ให้เรียกจากฝั่ง server เท่านั้น
- Endpoint นี้เป็น **read-only** — ดึงข้อมูลได้อย่างเดียว แก้ไข/ลบข้อมูลไม่ได้
- key หมุนได้ทุกเมื่อ (แก้ค่า `EXPORT_QUOTES_KEY` ใน `api/export_quotations.php`) — ถ้าหมุนแล้วต้องแจ้งทีมเว็บปลายทางให้เปลี่ยนตามด้วย
