// ตัวกลางดึงใบเสนอราคาจาก manage_banquet (ใช้แทน api/manage_banquet_export.php เมื่อรันบน Netlify)
// - รหัส API ของ manage_banquet อยู่ใน Environment variable ชื่อ MANAGE_BANQUET_KEY (ห้ามเขียนลงไฟล์)
// - ต้องแนบ header X-Staff-Token = access token ของพนักงานที่ล็อกอินกับ Supabase แล้ว

const REMOTE_URL = 'https://nas909ssf.myqnapcloud.com:8081/manage_banquet/api/export_quotations.php';
const SUPABASE_URL = 'https://govmturozgtfvllvnvap.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_N9psu9QmYz3hcIcPiasFdw_sMzcFukU';
// Netlify ให้ฟังก์ชันรันได้ไม่เกิน 60 วินาที
const TOTAL_BUDGET_MS = 55000;

const HEADERS = { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' };
const reply = (status, obj) => new Response(JSON.stringify(obj), { status, headers: HEADERS });
const fail = (status, message) => reply(status, { status: 'error', message });

export default async (req) => {
  const started = Date.now();

  const token = (req.headers.get('x-staff-token') || '').trim();
  if (!token) return fail(401, 'unauthorized');

  const remoteKey = Netlify.env.get('MANAGE_BANQUET_KEY');
  if (!remoteKey) {
    return fail(500, 'ยังไม่ได้ตั้งค่า MANAGE_BANQUET_KEY ใน Netlify (Site configuration → Environment variables)');
  }

  let authStatus = 0;
  try {
    const r = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(8000),
    });
    authStatus = r.status;
  } catch (_) { /* ถือว่าไม่ผ่าน */ }
  if (authStatus !== 200) return fail(401, 'unauthorized');

  // NAS ตอบช้ามากในครั้งแรกหลังว่างนาน (วัดได้ ~50 วินาที) จึงรอให้เต็มเวลาที่ Netlify อนุญาต
  let lastError = '';
  for (let attempt = 1; attempt <= 2; attempt++) {
    const remaining = TOTAL_BUDGET_MS - (Date.now() - started);
    if (remaining < 3000) break;
    try {
      const r = await fetch(REMOTE_URL, {
        headers: { 'X-API-Key': remoteKey },
        signal: AbortSignal.timeout(remaining - 1000),
      });
      const text = await r.text();
      let parsed = null;
      try { parsed = JSON.parse(text); } catch (_) { /* ไม่ใช่ JSON */ }
      if (parsed !== null && typeof parsed === 'object') {
        return new Response(text, { status: r.status || 500, headers: HEADERS });
      }
      const snippet = text.replace(/<[^>]*>/g, ' ').trim().slice(0, 150);
      lastError = `ระบบ manage_banquet ตอบกลับมาไม่ใช่ JSON (HTTP ${r.status})${snippet ? ': ' + snippet : ' — ตอบกลับว่างเปล่า'}`;
    } catch (err) {
      lastError = err && err.name === 'TimeoutError'
        ? 'ระบบ manage_banquet ตอบช้าเกินเวลาที่รอได้ ลองกดใหม่อีกครั้ง'
        : `เชื่อมต่อระบบ manage_banquet ไม่ได้: ${err && err.message}`;
    }
  }
  return fail(502, lastError || 'เชื่อมต่อระบบ manage_banquet ไม่ได้');
};

// ผูกกับ URL เดิมที่หน้าเว็บเรียกอยู่ ฟังก์ชันจะถูกเรียกก่อนไฟล์ static ที่ path เดียวกัน
export const config = { path: '/api/manage_banquet_export.php' };
