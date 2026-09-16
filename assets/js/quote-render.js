/* =====================================================================
 *  quote-render.js — สร้าง HTML ใบเสนอราคา A4
 *  ใช้ทั้งหน้าบ้าน (request.html) และหลังบ้าน (admin/quote-view.html)
 * ===================================================================== */

/**
 * @param {object} s      ข้อมูลโรงแรม
 * @param {object} q      ใบเสนอราคา
 * @param {Array}  items  รายการ
 * @param {object} opts   { preliminary: bool } — true = "ใบเสนอราคาเบื้องต้น"
 */
function renderQuotationHtml(s, q, items, opts = {}) {
  const sorted = [...items].sort((a, b) => a.sort_order - b.sort_order);
  const companyInfo = [
    s.address,
    [s.phone && `โทร ${s.phone}`, s.email && `อีเมล ${s.email}`].filter(Boolean).join('  '),
    s.tax_id && `เลขประจำตัวผู้เสียภาษี ${s.tax_id}`,
  ].filter(Boolean).join('\n');

  const row = (label, value) => value ? `<tr><td>${label}</td><td>${esc(value)}</td></tr>` : '';
  const discount = Number(q.discount) || 0;
  const title = opts.preliminary ? 'ใบเสนอราคาเบื้องต้น' : 'ใบเสนอราคา';

  return `
    <header class="q-head">
      <div class="q-company">
        <img src="${esc(s.logo_url || DEFAULT_LOGO)}" alt="logo" onerror="this.remove()">
        <div>
          <div class="name">${esc(s.company_name)}</div>
          ${s.company_name_en ? `<div class="name-en">${esc(s.company_name_en)}</div>` : ''}
          <div class="info">${esc(companyInfo)}</div>
        </div>
      </div>
      <div class="q-title">
        <div class="th">${title}</div>
        <div class="en">QUOTATION</div>
        <table class="q-meta">
          <tr><td>เลขที่</td><td>${esc(q.quote_no)}</td></tr>
          <tr><td>วันที่</td><td>${thaiDate(q.created_at)}</td></tr>
          ${q.valid_until ? `<tr><td>ใช้ได้ถึง</td><td>${thaiDate(q.valid_until)}</td></tr>` : ''}
        </table>
      </div>
    </header>

    <section class="q-parties">
      <div class="q-box">
        <h3>ลูกค้า / CUSTOMER</h3>
        <table>
          ${row('ชื่อผู้ติดต่อ', q.customer_name)}
          ${row('บริษัท', q.company)}
          ${row('โทรศัพท์', formatPhone(q.phone))}
          ${row('อีเมล', q.email)}
        </table>
      </div>
      <div class="q-box">
        <h3>รายละเอียดงาน / EVENT</h3>
        <table>
          ${row('ประเภทงาน', q.event_type)}
          ${row('ชื่องาน', q.event_name)}
          ${q.event_date || q.event_time
            ? `<tr><td>วัน-เวลา</td><td>${q.event_date ? thaiDate(q.event_date) : ''} ${esc(q.event_time || '')}</td></tr>`
            : ''}
          ${row('สถานที่', q.venue)}
          <tr><td>จำนวนแขก</td><td>${num(q.guest_count)} ท่าน</td></tr>
        </table>
      </div>
    </section>

    <div class="q-items-wrap">
      <table class="q-items">
        <thead>
          <tr>
            <th class="c-no">#</th>
            <th>รายการ</th>
            <th class="num">จำนวน</th>
            <th>หน่วย</th>
            <th class="num">ราคา/หน่วย</th>
            <th class="num">จำนวนเงิน</th>
          </tr>
        </thead>
        <tbody>${quotationItemRows(sorted)}</tbody>
      </table>
    </div>

    <section class="q-summary">
      <div class="q-baht">(${bahtText(q.grand_total)})</div>
      <table class="q-totals">
        <tr><td>รวมเป็นเงิน</td><td>${money(q.subtotal)}</td></tr>
        ${discount ? `
          <tr><td>ส่วนลด</td><td>-${money(discount)}</td></tr>
          <tr><td>ยอดหลังหักส่วนลด</td><td>${money(Math.max(q.subtotal - discount, 0))}</td></tr>` : ''}
        ${Number(q.service_charge_pct) ? `<tr><td>ค่าบริการ ${num(q.service_charge_pct)}%</td><td>${money(q.service_charge)}</td></tr>` : ''}
        ${Number(q.vat_pct) ? `<tr><td>ภาษีมูลค่าเพิ่ม ${num(q.vat_pct)}%</td><td>${money(q.vat)}</td></tr>` : ''}
        <tr class="grand"><td>ยอดรวมสุทธิ</td><td>${money(q.grand_total)}</td></tr>
      </table>
    </section>

    ${opts.preliminary ? `
      <p class="q-prelim-note">* ราคานี้เป็นราคาประเมินเบื้องต้นจากรายการที่เลือก เจ้าหน้าที่จะติดต่อกลับเพื่อยืนยันรายละเอียดและราคาอีกครั้ง</p>` : ''}

    ${q.notes || s.terms ? `
      <section class="q-terms">
        ${q.notes ? `<h3>หมายเหตุ</h3><p>${esc(q.notes)}</p>` : ''}
        ${s.terms ? `<h3>เงื่อนไข</h3><p>${esc(s.terms)}</p>` : ''}
      </section>` : ''}

    <section class="q-sign">
      <div>
        <div class="line"></div>
        <div>ผู้เสนอราคา</div>
        <div class="muted">วันที่ ......./......./.......</div>
      </div>
      <div>
        <div class="line"></div>
        <div>ผู้อนุมัติ (ลูกค้า)</div>
        <div class="muted">วันที่ ......./......./.......</div>
      </div>
    </section>`;
}

function quotationItemRows(items) {
  if (!items.length) return '<tr><td colspan="6" class="empty">ไม่มีรายการ</td></tr>';
  let html = '';
  let currentCat = null;
  items.forEach((it, i) => {
    if ((it.category_name || '') !== currentCat) {
      currentCat = it.category_name || '';
      if (currentCat) html += `<tr class="cat-row"><td></td><td colspan="5">${esc(currentCat)}</td></tr>`;
    }
    html += `
      <tr>
        <td class="c-no">${i + 1}</td>
        <td>${esc(it.name)}${it.description ? `<div class="desc">${esc(it.description)}</div>` : ''}</td>
        <td class="num">${num(it.qty)}</td>
        <td>${esc(it.unit)}</td>
        <td class="num">${money(it.unit_price)}</td>
        <td class="num">${money(it.amount)}</td>
      </tr>`;
  });
  return html;
}
