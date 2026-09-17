-- =====================================================================
--  เพิ่ม API ให้ระบบภายนอก "ดึง" ข้อมูลลิงก์เลือกอาหาร (pickup_links) — 2026-09-17
--  วางทั้งไฟล์นี้ใน Supabase Dashboard > SQL Editor แล้วกด Run ได้เลย (รันซ้ำได้ปลอดภัย)
--  สร้างฟังก์ชันใหม่ (ไม่กระทบของเดิม) — ใช้รหัสลับตัวเดียวกับ export_quotations
--  เนื้อหานี้รวมเข้า supabase/schema.sql แล้ว ไฟล์นี้มีไว้แค่ให้รันครั้งเดียวกับ DB จริง
--  ดูวิธีเรียกใช้ + ตัวอย่าง response ใน API-EXPORT-PICKUP.md
-- =====================================================================

create or replace function public.export_pickup_selections(p_key text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_secret constant text := 'NNP3FB1CApxXNDuEDmkXG5NGwnhUe0zW'; -- หมุนรหัสลับได้: แก้ค่านี้แล้วรัน SQL นี้ใหม่บน Supabase
begin
  if p_key is distinct from v_secret then
    raise exception 'unauthorized';
  end if;

  return coalesce(jsonb_agg(
    jsonb_build_object(
      'token',              l.token,
      'external_quote_no',  l.external_quote_no,
      'customer_name',      l.customer_name,
      'phone',              l.phone,
      'event_name',         l.event_name,
      'event_date',         l.event_date,
      'guest_count',        l.guest_count,
      'note',               l.note,
      'status',             l.status,
      'packages',           (
        select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'name', p.name) order by p.id), '[]'::jsonb)
          from menu_packages p where p.id = any(l.package_ids)
      ),
      'selections',         l.selections,
      'extra_items',        l.extra_items,
      'created_at',         l.created_at,
      'submitted_at',       l.submitted_at
    )
    order by l.created_at desc
  ), '[]'::jsonb)
  from pickup_links l;
end;
$$;

revoke execute on function public.export_pickup_selections(text) from public;
grant execute on function public.export_pickup_selections(text) to anon, authenticated;
