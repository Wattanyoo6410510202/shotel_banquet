<?php
/**
 * พรอกซีดึงข้อมูลใบเสนอราคาจากระบบ manage_banquet (ดู API-EXPORT-QUOTATIONS.md)
 * - เก็บ API key ของ manage_banquet ไว้ฝั่งนี้เท่านั้น ไม่ส่งให้ browser เห็นเด็ดขาด
 * - ต้องแนบ header X-Staff-Token: <supabase access token ของพนักงานที่ล็อกอินแล้ว>
 *   เพื่อกันคนนอกยิงตรงมาดึงข้อมูลลูกค้าออกไปได้โดยไม่ผ่านระบบหลังบ้าน
 *   (ไม่ใช้ header "Authorization" เพราะ Apache/PHP บน XAMPP ไม่ส่งต่อ header นี้ให้ตามค่าเริ่มต้น)
 */

const REMOTE_URL        = 'https://nas909ssf.myqnapcloud.com:8081/manage_banquet/api/export_quotations.php';
// รหัสอ่านจาก env MANAGE_BANQUET_KEY หรือไฟล์ api/manage_banquet_key.txt (ไฟล์นี้อยู่ใน .gitignore ห้ามเขียนรหัสลงในโค้ด)
$remoteKey = getenv('MANAGE_BANQUET_KEY') ?: (is_file(__DIR__ . '/manage_banquet_key.txt') ? trim(file_get_contents(__DIR__ . '/manage_banquet_key.txt')) : '');
const SUPABASE_URL      = 'https://govmturozgtfvllvnvap.supabase.co';
const SUPABASE_ANON_KEY  = 'sb_publishable_N9psu9QmYz3hcIcPiasFdw_sMzcFukU';

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

function fail($code, $message) {
    http_response_code($code);
    echo json_encode(['status' => 'error', 'message' => $message], JSON_UNESCAPED_UNICODE);
    exit;
}

// หมายเหตุ: ใช้ header ชื่อเอง (ไม่ใช่ Authorization) เพราะ Apache/PHP บน XAMPP
// ค่าเริ่มต้นไม่ส่งต่อ header "Authorization" ให้สคริปต์ PHP เห็น
if ($remoteKey === '') {
    fail(500, 'ยังไม่ได้ตั้งรหัส manage_banquet (ใส่ใน api/manage_banquet_key.txt หรือ env MANAGE_BANQUET_KEY)');
}

$token = trim($_SERVER['HTTP_X_STAFF_TOKEN'] ?? '');
if ($token === '') {
    fail(401, 'unauthorized');
}

// ตรวจว่า token นี้เป็นพนักงานที่ล็อกอินจริงกับ Supabase ของระบบนี้ ก่อนยอมพรอกซีให้
$chAuth = curl_init(SUPABASE_URL . '/auth/v1/user');
curl_setopt_array($chAuth, [
    CURLOPT_HTTPHEADER => [
        'apikey: ' . SUPABASE_ANON_KEY,
        'Authorization: Bearer ' . $token,
    ],
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_TIMEOUT => 10,
]);
curl_exec($chAuth);
$authStatus = curl_getinfo($chAuth, CURLINFO_HTTP_CODE);
curl_close($chAuth);

if ($authStatus !== 200) {
    fail(401, 'unauthorized');
}

// NAS ของ manage_banquet ตอบช้ามากในครั้งแรกหลังว่างนาน (วัดได้ ~50 วินาที) จึงรอนานและลองซ้ำอีก 1 ครั้ง
set_time_limit(120);
$body = false;
$status = 0;
$err = '';
$json = null;
for ($attempt = 1; $attempt <= 2; $attempt++) {
    $ch = curl_init(REMOTE_URL);
    curl_setopt_array($ch, [
        CURLOPT_HTTPHEADER => ['X-API-Key: ' . $remoteKey],
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_TIMEOUT => 50,
    ]);
    $body = curl_exec($ch);
    $status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $err = curl_error($ch);
    curl_close($ch);

    $json = ($body === false) ? null : json_decode($body, true);
    if (is_array($json)) {
        break;
    }
}

if ($body === false) {
    fail(502, 'เชื่อมต่อระบบ manage_banquet ไม่ได้: ' . $err);
}
if (!is_array($json)) {
    $snippet = mb_substr(trim(strip_tags((string) $body)), 0, 150);
    fail(502, 'ระบบ manage_banquet ตอบกลับมาไม่ใช่ JSON (HTTP ' . $status . ')' . ($snippet !== '' ? ': ' . $snippet : ' — ตอบกลับว่างเปล่า'));
}

http_response_code($status ?: 500);
echo $body;
