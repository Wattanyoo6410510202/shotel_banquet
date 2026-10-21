-- =====================================================================
--  ลิงก์เลือกอาหาร: เปิด/ปิดเมนูเสริม (เบรก/เครื่องดื่ม) ตามใบเสนอราคา — 2026-10-16
--  วางทั้งไฟล์นี้ใน Supabase Dashboard > SQL Editor แล้วกด Run ได้เลย (รันซ้ำได้ปลอดภัย)
--  - เพิ่มคอลัมน์ pickup_links.include_extras (ลิงก์เดิมทั้งหมดได้ค่า true = เหมือนเดิม)
--  - get_pickup_link ส่งค่า include_extras ให้หน้าลูกค้า
--  - submit_pickup_selection ไม่รับเมนูเสริมถ้าลิงก์ปิดไว้
--  - (2026-10-21) รองรับลิงก์ "เฉพาะเบรก" (ไม่มีแพ็กเกจ) — ต้องเลือกเบรกอย่างน้อย 1 รายการ
--  เนื้อหานี้รวมเข้า supabase/schema.sql แล้ว ไฟล์นี้มีไว้แค่ให้รันครั้งเดียวกับ DB จริง
-- =====================================================================

alter table public.pickup_links add column if not exists include_extras boolean not null default true;

-- ลูกค้าเปิดลิงก์เลือกอาหาร (จาก "สร้างลิงก์" ในหลังบ้าน) ดูรายละเอียด + แพ็กเกจที่เลือกได้
create or replace function public.get_pickup_link(p_token uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  l public.pickup_links%rowtype;
  v_pkgs jsonb;
begin
  select * into l from pickup_links where token = p_token;
  if not found then
    raise exception 'ลิงก์นี้ไม่ถูกต้อง หรืออาจถูกลบไปแล้ว';
  end if;

  select coalesce(jsonb_agg(pkg order by pkg.sort_order, pkg.id), '[]'::jsonb)
    into v_pkgs
    from (
      select p.id, p.name, p.name_en, p.description, p.price, p.unit, p.per_person, p.serves,
             p.image_url, p.sort_order,
             (select coalesce(jsonb_agg(crs order by crs.sort_order, crs.id), '[]'::jsonb)
                from (
                  select c.id, c.name, c.pick_count, c.sort_order,
                         (select coalesce(jsonb_agg(jsonb_build_object(
                                'menu_item_id', m.id, 'name', m.name, 'name_en', m.name_en,
                                'description', m.description, 'image_url', m.image_url
                              ) order by ci.sort_order, ci.id), '[]'::jsonb)
                            from menu_package_course_items ci
                            join menu_items m on m.id = ci.menu_item_id
                           where ci.course_id = c.id) as choices
                    from menu_package_courses c
                   where c.package_id = p.id
                ) crs
             ) as courses
        from menu_packages p
       where p.id = any(l.package_ids)
    ) pkg;

  return jsonb_build_object(
    'external_quote_no', l.external_quote_no,
    'customer_name',     l.customer_name,
    'event_name',        l.event_name,
    'event_date',        l.event_date,
    'guest_count',       l.guest_count,
    'note',              l.note,
    'status',            l.status,
    'selections',        l.selections,
    'extra_items',       l.extra_items,
    'include_extras',    l.include_extras,
    'packages',          v_pkgs
  );
end $$;

-- ลูกค้าส่งรายการอาหารที่เลือกผ่านลิงก์
--   p_selections: [{ package_id, choices:[{course_id, menu_item_id}], note }]
--   p_items (ไม่บังคับ): เมนูเดี่ยวเพิ่มเติมนอกแพ็กเกจ เช่น Coffee Break / เครื่องดื่ม — [{ menu_item_id, qty }]
-- เพิ่มพารามิเตอร์ p_items ทีหลัง (ของเดิมมีแค่ p_token, p_selections) — ต้อง drop ของเก่าก่อน ไม่งั้น create or replace
-- จะกลายเป็นสร้างฟังก์ชันซ้อนอีกตัวแทนที่จะแทนที่ของเดิม
drop function if exists public.submit_pickup_selection(uuid, jsonb);
create or replace function public.submit_pickup_selection(p_token uuid, p_selections jsonb, p_items jsonb default '[]'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  l            public.pickup_links%rowtype;
  v_sel_item   jsonb;
  v_pkg_id     bigint;
  pkg          menu_packages%rowtype;
  v_course     record;
  v_chosen_ids bigint[];
  v_chosen_cnt int;
  v_valid_cnt  int;
  v_course_desc text;
  v_desc_parts text[];
  v_seen_pkgs  bigint[] := '{}';
  v_final      jsonb := '[]'::jsonb;
  v_item       jsonb;
  v_item_id    bigint;
  v_item_qty   numeric;
  m            menu_items%rowtype;
  v_items_final jsonb := '[]'::jsonb;
begin
  select * into l from pickup_links where token = p_token for update;
  if not found then
    raise exception 'ลิงก์นี้ไม่ถูกต้อง หรืออาจถูกลบไปแล้ว';
  end if;
  if l.status = 'submitted' then
    raise exception 'ลิงก์นี้ถูกส่งข้อมูลไปแล้ว หากต้องการแก้ไข กรุณาติดต่อโรงแรม';
  end if;

  -- ลิงก์ "เฉพาะเบรก" ไม่มีแพ็กเกจ (package_ids = '{}') → ส่ง p_selections เป็น [] ได้ แต่ต้องเลือกเบรกอย่างน้อย 1 รายการ (เช็กด้านล่าง)
  if jsonb_typeof(p_selections) is distinct from 'array'
     or (jsonb_array_length(p_selections) = 0 and cardinality(l.package_ids) > 0) then
    raise exception 'กรุณาเลือกเมนูอย่างน้อย 1 ชุด';
  end if;

  for v_sel_item in select value from jsonb_array_elements(p_selections)
  loop
    v_pkg_id := case when v_sel_item->>'package_id' ~ '^\d{1,18}$' then (v_sel_item->>'package_id')::bigint end;
    if v_pkg_id is null or not (v_pkg_id = any(l.package_ids)) then
      raise exception 'แพ็กเกจที่เลือกไม่ได้อยู่ในลิงก์นี้';
    end if;
    if v_pkg_id = any(v_seen_pkgs) then
      raise exception 'เลือกแพ็กเกจซ้ำ';
    end if;
    v_seen_pkgs := v_seen_pkgs || v_pkg_id;

    select * into pkg from menu_packages where id = v_pkg_id;
    if not found then
      raise exception 'ไม่พบแพ็กเกจที่เลือก';
    end if;

    v_desc_parts := array[]::text[];

    for v_course in
      select c.id, c.name, c.pick_count
        from menu_package_courses c
       where c.package_id = pkg.id
       order by c.sort_order, c.id
    loop
      select array_agg(distinct x.mid), count(distinct x.mid)
        into v_chosen_ids, v_chosen_cnt
        from (
          select case when ch->>'menu_item_id' ~ '^\d{1,18}$' then (ch->>'menu_item_id')::bigint end as mid
            from jsonb_array_elements(coalesce(v_sel_item->'choices', '[]'::jsonb)) ch
           where (case when ch->>'course_id' ~ '^\d{1,18}$' then (ch->>'course_id')::bigint end) = v_course.id
        ) x
       where x.mid is not null;

      if coalesce(v_chosen_cnt, 0) <> v_course.pick_count then
        raise exception 'กรุณาเลือก "%" ในหมวด "%" ให้ครบ % อย่าง', pkg.name, v_course.name, v_course.pick_count;
      end if;

      select count(*) into v_valid_cnt
        from menu_package_course_items ci
       where ci.course_id = v_course.id and ci.menu_item_id = any(v_chosen_ids);
      if v_valid_cnt <> v_chosen_cnt then
        raise exception 'ตัวเลือกในหมวด "%" ไม่ถูกต้อง กรุณาโหลดหน้าใหม่แล้วเลือกอีกครั้ง', v_course.name;
      end if;

      select v_course.name || ': ' || string_agg(mi.name, ', ' order by mi.name)
        into v_course_desc
        from menu_items mi where mi.id = any(v_chosen_ids);
      v_desc_parts := v_desc_parts || v_course_desc;
    end loop;

    v_final := v_final || jsonb_build_array(jsonb_build_object(
      'package_id',   pkg.id,
      'package_name', pkg.name,
      'description',  array_to_string(v_desc_parts, E'\n'),
      'note',         nullif(left(trim(coalesce(v_sel_item->>'note', '')), 500), '')
    ));
  end loop;

  if array_length(v_seen_pkgs, 1) is distinct from array_length(l.package_ids, 1) then
    raise exception 'กรุณาเลือกเมนูให้ครบทุกชุดที่กำหนดไว้';
  end if;

  -- เมนูเดี่ยวเพิ่มเติมนอกแพ็กเกจ (ไม่บังคับ) เช่น Coffee Break / เครื่องดื่ม — ต้องเป็นเมนูที่เปิดใช้งานอยู่จริง
  -- ลิงก์ที่ปิดเมนูเสริมไว้ (include_extras = false) ไม่รับรายการเหล่านี้เลย
  for v_item in select value from jsonb_array_elements(case when l.include_extras then coalesce(p_items, '[]'::jsonb) else '[]'::jsonb end)
  loop
    v_item_id := case when v_item->>'menu_item_id' ~ '^\d{1,18}$' then (v_item->>'menu_item_id')::bigint end;
    if v_item_id is null then
      continue;
    end if;
    select * into m from menu_items where id = v_item_id and is_active;
    if not found then
      raise exception 'เมนูที่เลือกไม่พร้อมให้บริการแล้ว กรุณาโหลดหน้าใหม่แล้วเลือกอีกครั้ง';
    end if;
    -- ลิงก์ "เฉพาะเบรก" (ไม่มีแพ็กเกจ) รับเฉพาะเมนูในหมวดเบรก ไม่รับเครื่องดื่ม
    if cardinality(l.package_ids) = 0 and not exists (
      select 1 from menu_categories c where c.id = m.category_id and c.name = 'อาหารว่าง (Coffee Break)'
    ) then
      raise exception 'ลิงก์นี้เลือกได้เฉพาะเบรกเท่านั้น';
    end if;
    v_item_qty := case when v_item->>'qty' ~ '^\d{1,6}(\.\d+)?$' then (v_item->>'qty')::numeric else 1 end;
    v_items_final := v_items_final || jsonb_build_array(jsonb_build_object(
      'menu_item_id', m.id,
      'name',         m.name,
      'unit',         m.unit,
      'per_person',   m.per_person,
      'qty',          least(greatest(v_item_qty, 0.01), 9999)
    ));
  end loop;

  if cardinality(l.package_ids) = 0 and jsonb_array_length(v_items_final) = 0 then
    raise exception 'กรุณาเลือกเบรกอย่างน้อย 1 รายการ';
  end if;

  update pickup_links
     set selections = v_final, extra_items = v_items_final, status = 'submitted', submitted_at = now()
   where id = l.id;

  return jsonb_build_object('ok', true);
end $$;


grant execute on function public.get_pickup_link(uuid)             to anon, authenticated;
grant execute on function public.submit_pickup_selection(uuid, jsonb, jsonb) to anon, authenticated;
