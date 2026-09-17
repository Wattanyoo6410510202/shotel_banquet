<?php
/**
 * พรอกซีดึงข้อมูลใบเสนอราคาจากระบบ manage_banquet (ดู API-EXPORT-QUOTATIONS.md)
 * - เก็บ API key ของ manage_banquet ไว้ฝั่งนี้เท่านั้น ไม่ส่งให้ browser เห็นเด็ดขาด
 * - ต้องแนบ header X-Staff-Token: <supabase access token ของพนักงานที่ล็อกอินแล้ว>
 *   เพื่อกันคนนอกยิงตรงมาดึงข้อมูลลูกค้าออกไปได้โดยไม่ผ่านระบบหลังบ้าน
 *   (ไม่ใช้ header "Authorization" เพราะ Apache/PHP บน XAMPP ไม่ส่งต่อ header นี้ให้ตามค่าเริ่มต้น)
 */

const REMOTE_URL        = 'https://nas909ssf.myqnapcloud.com:8081/manage_banquet/api/export_quotations.php';
const REMOTE_KEY         = '82263da08c2d0c6b5d70ee113691f710a4de802617d06521';
const SUPABASE_URL       = 'https://govmturozgtfvllvnvap.supabase.co';
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

// ดึงข้อมูลจาก manage_banquet
$ch = curl_init(REMOTE_URL);
curl_setopt_array($ch, [
    CURLOPT_HTTPHEADER => ['X-API-Key: ' . REMOTE_KEY],
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_TIMEOUT => 15,
]);
$body = curl_exec($ch);
$status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$err = curl_error($ch);
curl_close($ch);

if ($body === false) {
    fail(502, 'เชื่อมต่อระบบ manage_banquet ไม่ได้: ' . $err);
}

http_response_code($status ?: 500);
echo $body;
