/* =====================================================================
 *  admin.js — ใช้เฉพาะหลังบ้าน (โหลดหลัง core.js)
 * ===================================================================== */

async function requireAuth() {
  const { data: { session } } = await sb.auth.getSession();
  if (!session) {
    const next = location.pathname.split('/').pop() + location.search;
    location.replace('login.html?next=' + encodeURIComponent(next));
    return new Promise(() => {}); // หยุดโค้ดของหน้าไว้ระหว่าง redirect
  }
  sb.auth.onAuthStateChange((event) => {
    if (event === 'SIGNED_OUT') location.replace('login.html');
  });
  return session;
}

function safeNext(next) {
  return next && /^[a-z0-9_-]+\.html(\?[^#]*)?$/i.test(next) ? next : 'index.html';
}

async function loadSettings() {
  const { data, error } = await sb.from('settings').select('*').eq('id', 1).maybeSingle();
  if (error) throw error;
  return data || { company_name: '', service_charge_pct: 10, vat_pct: 7, valid_days: 30, terms: '' };
}

// ลิงก์ที่ส่งให้ลูกค้าเปิดดูคำขอของตัวเอง
function customerLink(token) {
  return new URL(`../request.html?t=${token}`, location.href).href;
}

// ลิงก์เลือกอาหาร (จากหน้า "ลิงก์เลือกอาหาร") ที่ส่งให้ลูกค้าเลือกเมนูในแพ็กเกจที่กำหนดไว้
function foodPickLink(token) {
  return new URL(`../food-pick.html?t=${token}`, location.href).href;
}

function renderHeader(active, session) {
  const links = [
    ['index.html', 'รายการที่บันทึก', 'quotes'],
    ['quote-edit.html', '+ สร้างใบใหม่', 'new'],
    ['menu.html', 'เมนูอาหาร', 'menu'],
    ['packages.html', 'แพ็กเกจ', 'packages'],
    ['food-links.html', 'ลิงก์เลือกอาหาร', 'foodlinks'],
    ['settings.html', 'ตั้งค่า', 'settings'],
  ];
  const header = document.createElement('header');
  header.className = 'topbar no-print';
  header.innerHTML = `
    <div class="topbar-inner">
      <a class="brand" href="index.html"><img class="brand-logo" src="${DEFAULT_LOGO}" alt=""> หลังบ้าน</a>
      <nav class="nav">
        ${links.map(([href, label, key]) =>
          `<a href="${href}" class="${key === active ? 'active' : ''}">${label}</a>`).join('')}
        <a href="../index.html" target="_blank" rel="noopener">ดูหน้าบ้าน ↗</a>
      </nav>
      <div class="user-box">
        <span class="user-email">${esc(session?.user?.email)}</span>
        <button type="button" id="btnLogout">ออกจากระบบ</button>
      </div>
    </div>`;
  document.body.prepend(header);
  $('.user-box', header).insertBefore(themeToggleButton(), $('#btnLogout', header));
  $('#btnLogout', header).addEventListener('click', async () => {
    await sb.auth.signOut();
    location.replace('login.html');
  });
}
