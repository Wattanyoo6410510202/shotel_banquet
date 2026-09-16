/* =====================================================================
 *  core.js — ใช้ร่วมกันทั้งหน้าบ้านและหลังบ้าน
 *  ต้องโหลดหลัง supabase-js และ config.js
 * ===================================================================== */

/* ---------- ธีมสว่าง/มืด ----------
 * ค่าเริ่มต้นตามการตั้งค่าของเครื่อง, กดปุ่มแล้วจำไว้ใน localStorage
 * (ในแต่ละหน้ามีสคริปต์สั้นๆ ใน <head> ตั้งค่าธีมก่อนโหลด CSS เพื่อไม่ให้หน้าจอกะพริบ) */
function currentTheme() {
  const t = document.documentElement.dataset.theme;
  if (t === 'dark' || t === 'light') return t;
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function setTheme(theme) {
  document.documentElement.dataset.theme = theme;
  try { localStorage.setItem('theme', theme); } catch { /* ignore */ }
  document.dispatchEvent(new Event('themechange'));
}

function themeToggleButton(extraClass = '') {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = `theme-toggle ${extraClass}`.trim();
  const sync = () => {
    const dark = currentTheme() === 'dark';
    btn.textContent = dark ? '☀️' : '🌙';
    btn.title = dark ? 'เปลี่ยนเป็นธีมสว่าง' : 'เปลี่ยนเป็นธีมมืด';
    btn.setAttribute('aria-label', btn.title);
  };
  sync();
  btn.addEventListener('click', () => setTheme(currentTheme() === 'dark' ? 'light' : 'dark'));
  document.addEventListener('themechange', sync);
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', sync);
  return btn;
}

const APP = window.APP_CONFIG || {};
const IS_CONFIGURED =
  !!APP.SUPABASE_URL && !APP.SUPABASE_URL.includes('YOUR_') &&
  !!APP.SUPABASE_ANON_KEY && !APP.SUPABASE_ANON_KEY.includes('YOUR_');

if (!IS_CONFIGURED) {
  document.addEventListener('DOMContentLoaded', () => {
    document.body.innerHTML = `
      <main class="container">
        <div class="card setup-warning">
          <h2>ยังไม่ได้ตั้งค่าการเชื่อมต่อฐานข้อมูล</h2>
          <p>เปิดไฟล์ <code>config.js</code> แล้วใส่ <code>SUPABASE_URL</code> และ <code>SUPABASE_ANON_KEY</code></p>
          <p class="muted">ดูขั้นตอนทั้งหมดใน README.md</p>
        </div>
      </main>`;
  });
  throw new Error('Supabase is not configured. Edit config.js');
}

const sb = supabase.createClient(APP.SUPABASE_URL, APP.SUPABASE_ANON_KEY);

// โฟลเดอร์หลักของเว็บ (หาจากตำแหน่งไฟล์นี้ assets/js/core.js) ใช้ได้ทั้งหน้าบ้านและ admin/
const SITE_ROOT = new URL('../../', document.currentScript?.src || location.href).href;
const DEFAULT_LOGO = new URL('assets/img/logo.png', SITE_ROOT).href;

/* ---------- DOM helpers ---------- */
const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

function esc(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
  ));
}

function qs(name) {
  return new URLSearchParams(location.search).get(name);
}

/* ---------- Formatting ---------- */
function money(n) {
  return (Number(n) || 0).toLocaleString('th-TH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function money0(n) {
  return (Number(n) || 0).toLocaleString('th-TH', { maximumFractionDigits: 2 });
}

function num(n) {
  return (Number(n) || 0).toLocaleString('th-TH', { maximumFractionDigits: 2 });
}

// 0811112222 -> 081-111-2222, 021234567 -> 02-123-4567
function formatPhone(phone) {
  const p = String(phone || '');
  if (/^0\d{9}$/.test(p)) return `${p.slice(0, 3)}-${p.slice(3, 6)}-${p.slice(6)}`;
  if (/^0\d{8}$/.test(p)) return `${p.slice(0, 2)}-${p.slice(2, 5)}-${p.slice(5)}`;
  return p;
}

function parseDate(d) {
  if (!d) return null;
  // 'YYYY-MM-DD' ต้องตีความเป็นวันที่ท้องถิ่น ไม่ใช่ UTC
  return /^\d{4}-\d{2}-\d{2}$/.test(d) ? new Date(d + 'T00:00:00') : new Date(d);
}

function thaiDate(d, month = 'long') {
  const dt = parseDate(d);
  if (!dt || isNaN(dt)) return '-';
  return dt.toLocaleDateString('th-TH', { year: 'numeric', month, day: 'numeric' });
}

// วันที่รูปแบบ YYYY-MM-DD ตามเวลาท้องถิ่น
function isoDate(offsetDays = 0) {
  const d = new Date();
  d.setDate(d.getDate() + offsetDays);
  return d.toLocaleDateString('sv-SE');
}

function round2(n) {
  return Math.round((Number(n) + Number.EPSILON) * 100) / 100;
}

/* ---------- จำนวนเงินเป็นตัวอักษรไทย ---------- */
function bahtText(amount) {
  const DIGITS = ['ศูนย์', 'หนึ่ง', 'สอง', 'สาม', 'สี่', 'ห้า', 'หก', 'เจ็ด', 'แปด', 'เก้า'];
  const PLACES = ['', 'สิบ', 'ร้อย', 'พัน', 'หมื่น', 'แสน'];

  // อ่านเลขไม่เกิน 6 หลัก; hasHigher = มีหลักล้านขึ้นไปนำหน้า (ใช้ตัดสิน "เอ็ด")
  function readSix(s, hasHigher) {
    s = s.replace(/^0+/, '');
    let out = '';
    const len = s.length;
    for (let i = 0; i < len; i++) {
      const d = +s[i];
      const p = len - i - 1;
      if (d === 0) continue;
      if (p === 0 && d === 1 && (len > 1 || hasHigher)) out += 'เอ็ด';
      else if (p === 1 && d === 1) out += 'สิบ';
      else if (p === 1 && d === 2) out += 'ยี่สิบ';
      else out += DIGITS[d] + PLACES[p];
    }
    return out;
  }

  function readInt(s) {
    s = s.replace(/^0+/, '');
    if (!s) return '';
    if (s.length > 6) {
      return readInt(s.slice(0, -6)) + 'ล้าน' + readSix(s.slice(-6), true);
    }
    return readSix(s, false);
  }

  const n = round2(Math.abs(Number(amount) || 0));
  const [intPart, decPart] = n.toFixed(2).split('.');
  const bahtWords = readInt(intPart);
  const satangWords = readSix(decPart, false);

  if (!bahtWords && !satangWords) return 'ศูนย์บาทถ้วน';
  let text = '';
  if (bahtWords) text += bahtWords + 'บาท';
  text += satangWords ? satangWords + 'สตางค์' : 'ถ้วน';
  return (Number(amount) < 0 ? 'ลบ' : '') + text;
}

/* ---------- Business logic ---------- */
const STATUS = {
  new: 'คำขอใหม่',
  draft: 'ฉบับร่าง',
  sent: 'ส่งลูกค้าแล้ว',
  confirmed: 'ยืนยันแล้ว',
  cancelled: 'ยกเลิก',
};

// ข้อความสถานะที่ลูกค้าเห็น
const STATUS_CUSTOMER = {
  new: 'รอเจ้าหน้าที่ตรวจสอบ',
  draft: 'กำลังจัดทำใบเสนอราคา',
  sent: 'ใบเสนอราคาพร้อมแล้ว',
  confirmed: 'ยืนยันการจองแล้ว',
  cancelled: 'ยกเลิก',
};

const EVENT_TYPES = ['สัมมนา / ประชุม', 'งานเลี้ยงบริษัท', 'งานแต่งงาน', 'งานวันเกิด', 'อื่นๆ'];

function statusBadge(status, labels = STATUS) {
  return `<span class="badge st-${esc(status)}">${esc(labels[status] || status)}</span>`;
}

function statusOptions(selected) {
  return Object.entries(STATUS)
    .map(([k, v]) => `<option value="${k}" ${k === selected ? 'selected' : ''}>${v}</option>`)
    .join('');
}

// ต้องตรงกับสูตรใน supabase/schema.sql
function calcTotals(lines, discount, scPct, vatPct) {
  const subtotal = round2(lines.reduce((s, l) => s + round2((Number(l.qty) || 0) * (Number(l.unit_price) || 0)), 0));
  const disc = Math.max(Number(discount) || 0, 0);
  const base = round2(Math.max(subtotal - disc, 0));
  const serviceCharge = round2(base * (Number(scPct) || 0) / 100);
  const vat = round2((base + serviceCharge) * (Number(vatPct) || 0) / 100);
  return { subtotal, discount: disc, base, serviceCharge, vat, grandTotal: round2(base + serviceCharge + vat) };
}

/* ---------- Toast / errors ---------- */
function toast(message, type = 'ok', ms = 3000) {
  let host = $('.toast-host');
  if (!host) {
    host = document.createElement('div');
    host.className = 'toast-host';
    document.body.appendChild(host);
  }
  const el = document.createElement('div');
  el.className = `toast ${type}`;
  el.textContent = message;
  host.appendChild(el);
  setTimeout(() => el.remove(), ms);
}

function errorMessage(err) {
  const msg = err?.message || String(err);
  if (/Failed to fetch|NetworkError/i.test(msg)) return 'เชื่อมต่อไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่';
  return msg;
}

function showError(err) {
  console.error(err);
  toast(errorMessage(err), 'error', 5000);
}

async function withBusy(button, fn, busyLabel = 'กำลังดำเนินการ...') {
  const label = button.innerHTML;
  button.disabled = true;
  button.innerHTML = busyLabel;
  try {
    return await fn();
  } finally {
    button.disabled = false;
    button.innerHTML = label;
  }
}
