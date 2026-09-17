-- =====================================================================
--  export_pickup_selections: เพิ่มราคาเข้าไปในข้อมูลที่ส่งออก — 2026-09-17
--  วางทั้งไฟล์นี้ใน Supabase Dashboard > SQL Editor แล้วกด Run ได้เลย (รันซ้ำได้ปลอดภัย)
--  แทนที่ฟังก์ชันเดิมทั้งตัว (create or replace) — ไม่กระทบข้อมูลหรือฟังก์ชันอื่น
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
        select coalesce(jsonb_agg(jsonb_build_object(
                 'id', p.id, 'name', p.name, 'unit_price', p.price, 'unit', p.unit,
                 'per_person', p.per_person, 'serves', p.serves
               ) order by p.id), '[]'::jsonb)
          from menu_packages p where p.id = any(l.package_ids)
      ),
      -- ราคาไม่ได้เก็บไว้ตอนลูกค้า submit (เก็บแค่รายละเอียดคอร์ส/เมนู) จึงต้อง join กับ
      -- menu_packages/menu_items ตอนส่งออกทุกครั้ง โดยอิงราคา ณ ปัจจุบัน ไม่ใช่ราคา ณ วันที่เลือก
      'selections',         (
        case when l.selections is null then null else (
          select coalesce(jsonb_agg(
                   sel.value || jsonb_build_object(
                     'unit_price',  pk.price,
                     'unit',        pk.unit,
                     'per_person',  pk.per_person,
                     'serves',      pk.serves
                   ) order by sel.ord
                 ), '[]'::jsonb)
            from jsonb_array_elements(l.selections) with ordinality as sel(value, ord)
            left join menu_packages pk on pk.id = (sel.value->>'package_id')::bigint
        ) end
      ),
      'extra_items',        (
        case when l.extra_items is null then null else (
          select coalesce(jsonb_agg(
                   it.value || jsonb_build_object('unit_price', mi.price)
                   order by it.ord
                 ), '[]'::jsonb)
            from jsonb_array_elements(l.extra_items) with ordinality as it(value, ord)
            left join menu_items mi on mi.id = (it.value->>'menu_item_id')::bigint
        ) end
      ),
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
