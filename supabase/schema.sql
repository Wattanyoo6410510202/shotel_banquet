-- =====================================================================
--  Banquet Quotation System — Supabase schema v0.2
--  หน้าบ้าน (ลูกค้า, ไม่ล็อกอิน) + หลังบ้าน (พนักงาน, ล็อกอิน)
--  วิธีใช้: Supabase Dashboard > SQL Editor > วางไฟล์นี้ทั้งหมด > Run
--  รันซ้ำได้ (ไม่ลบข้อมูลเดิม)
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- ตั้งค่าโรงแรม (มีแถวเดียว id = 1)
-- ---------------------------------------------------------------------
create table if not exists public.settings (
  id                 int primary key default 1 check (id = 1),
  company_name       text not null default 'ชื่อโรงแรมของคุณ',
  company_name_en    text,
  address            text,
  tax_id             text,
  phone              text,
  email              text,
  logo_url           text,
  service_charge_pct numeric(5,2) not null default 10,
  vat_pct            numeric(5,2) not null default 7,
  valid_days         int not null default 30,
  terms              text,
  updated_at         timestamptz not null default now()
);
alter table public.settings add column if not exists welcome_text    text;
alter table public.settings add column if not exists accept_requests boolean not null default true;

insert into public.settings (id, welcome_text, terms) values (1,
'เลือกเมนูอาหารสำหรับงานของคุณได้ง่ายๆ ใน 3 ขั้นตอน พร้อมรับใบเสนอราคาเบื้องต้นทันที',
'1. กรุณาชำระเงินมัดจำ 50% ของยอดรวมสุทธิ เพื่อยืนยันการจอง
2. กรุณายืนยันจำนวนผู้เข้าร่วมงานล่วงหน้าอย่างน้อย 7 วันก่อนวันงาน
3. ราคานี้สำหรับระยะเวลาจัดงานไม่เกิน 4 ชั่วโมง
4. ใบเสนอราคานี้มีผลถึงวันที่ระบุไว้ข้างต้น')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- หมวดหมู่เมนู / รายการเมนู
--   per_person = true  -> ราคาต่อท่าน (จำนวน = จำนวนแขก)
--   per_person = false -> ราคาต่อหน่วย (โต๊ะ, ตัว, งาน ฯลฯ)
-- ---------------------------------------------------------------------
create table if not exists public.menu_categories (
  id          bigint generated always as identity primary key,
  name        text not null,
  sort_order  int not null default 0,
  created_at  timestamptz not null default now()
);

create table if not exists public.menu_items (
  id           bigint generated always as identity primary key,
  category_id  bigint references public.menu_categories(id) on delete set null,
  name         text not null,
  name_en      text,
  description  text,
  price        numeric(12,2) not null default 0 check (price >= 0),
  unit         text not null default 'ท่าน',
  per_person   boolean not null default true,
  image_url    text,
  is_active    boolean not null default true,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists menu_items_category_idx on public.menu_items(category_id);

-- ---------------------------------------------------------------------
-- แพ็กเกจ / เซ็ตเมนู (เช่น โต๊ะจีน, Thai-set) — ราคาต่อโต๊ะ/ชุด หรือต่อท่าน
--   1 แพ็กเกจ มีหลาย "คอร์ส" (เช่น อาหารผัด, อาหารทอด) แต่ละคอร์สเลือกได้ pick_count อย่าง
--   จากตัวเลือกที่กำหนดไว้ (ซึ่งอ้างถึง menu_items เดิม — ใช้ได้แม้เมนูนั้นจะปิดขายแบบสั่งเดี่ยวอยู่ก็ตาม)
-- ---------------------------------------------------------------------
create table if not exists public.menu_packages (
  id           bigint generated always as identity primary key,
  name         text not null,
  name_en      text,
  description  text,
  price        numeric(12,2) not null default 0 check (price >= 0),
  unit         text not null default 'โต๊ะ',
  per_person   boolean not null default false,
  serves       int,                    -- จำนวนท่านต่อโต๊ะ/ชุด (ถ้ามี ใช้แสดงผลเฉยๆ)
  image_url    text,
  is_active    boolean not null default true,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table if not exists public.menu_package_courses (
  id           bigint generated always as identity primary key,
  package_id   bigint not null references public.menu_packages(id) on delete cascade,
  name         text not null,
  pick_count   int not null default 1 check (pick_count >= 1),
  sort_order   int not null default 0
);
create index if not exists menu_package_courses_pkg_idx on public.menu_package_courses(package_id);

create table if not exists public.menu_package_course_items (
  id           bigint generated always as identity primary key,
  course_id    bigint not null references public.menu_package_courses(id) on delete cascade,
  menu_item_id bigint not null references public.menu_items(id) on delete cascade,
  sort_order   int not null default 0,
  unique (course_id, menu_item_id)
);
create index if not exists menu_package_course_items_course_idx on public.menu_package_course_items(course_id);

-- ---------------------------------------------------------------------
-- ใบเสนอราคา / คำขอจากลูกค้า
-- ---------------------------------------------------------------------
create table if not exists public.quotations (
  id                 uuid primary key default gen_random_uuid(),
  quote_no           text unique,
  status             text not null default 'draft',
  customer_name      text not null,
  company            text,
  phone              text,
  email              text,
  event_name         text,
  event_date         date,
  event_time         text,
  venue              text,
  guest_count        int not null default 0 check (guest_count >= 0),
  notes              text,
  discount           numeric(12,2) not null default 0 check (discount >= 0),
  service_charge_pct numeric(5,2) not null default 10,
  vat_pct            numeric(5,2) not null default 7,
  subtotal           numeric(12,2) not null default 0,
  service_charge     numeric(12,2) not null default 0,
  vat                numeric(12,2) not null default 0,
  grand_total        numeric(12,2) not null default 0,
  valid_until        date,
  created_by         uuid default auth.uid() references auth.users(id) on delete set null,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
alter table public.quotations add column if not exists access_token  uuid not null default gen_random_uuid();
alter table public.quotations add column if not exists source        text not null default 'staff';
alter table public.quotations add column if not exists event_type    text;
alter table public.quotations add column if not exists internal_note text;

alter table public.quotations drop constraint if exists quotations_status_check;
alter table public.quotations add  constraint quotations_status_check
  check (status in ('new','draft','sent','confirmed','cancelled'));
alter table public.quotations drop constraint if exists quotations_source_check;
alter table public.quotations add  constraint quotations_source_check
  check (source in ('web','staff'));

create unique index if not exists quotations_access_token_idx on public.quotations(access_token);
create index if not exists quotations_created_idx on public.quotations(created_at desc);
create index if not exists quotations_status_idx  on public.quotations(status);
create index if not exists quotations_phone_idx   on public.quotations(phone, created_at);

create table if not exists public.quotation_items (
  id             bigint generated always as identity primary key,
  quotation_id   uuid not null references public.quotations(id) on delete cascade,
  menu_item_id   bigint references public.menu_items(id) on delete set null,
  category_name  text,
  name           text not null,
  description    text,
  unit           text not null default 'รายการ',
  per_person     boolean not null default false,
  qty            numeric(12,2) not null default 1 check (qty >= 0),
  unit_price     numeric(12,2) not null default 0 check (unit_price >= 0),
  amount         numeric(12,2) generated always as (round(qty * unit_price, 2)) stored,
  sort_order     int not null default 0
);
create index if not exists quotation_items_quote_idx on public.quotation_items(quotation_id);

-- ---------------------------------------------------------------------
-- ลิงก์เลือกอาหาร: สำหรับใบเสนอราคาที่มาจากระบบภายนอก (manage_banquet)
-- พนักงานเลือกแพ็กเกจอาหารที่จะเปิดให้ลูกค้าเลือกได้ สร้างลิงก์ส่งให้ลูกค้า
-- ลูกค้าเปิดลิงก์แล้วเห็นแค่ฟอร์มเลือกเมนูในแพ็กเกจที่กำหนดไว้เท่านั้น ไม่ใช่หน้าเว็บปกติทั้งหมด
-- ผลลัพธ์เก็บแยกจากตาราง quotations เพราะไม่ใช่ใบเสนอราคาของระบบนี้ (แค่บันทึกว่าลูกค้าเลือกอะไร)
-- ---------------------------------------------------------------------
create table if not exists public.pickup_links (
  id                 uuid primary key default gen_random_uuid(),
  token              uuid not null default gen_random_uuid(),
  external_quote_no  text,
  customer_name      text not null,
  phone              text,
  event_name         text,
  event_date         date,
  guest_count        int,
  package_ids        bigint[] not null default '{}',
  note               text,
  status             text not null default 'pending' check (status in ('pending', 'submitted')),
  selections         jsonb,
  extra_items        jsonb,
  submitted_at       timestamptz,
  created_by         uuid default auth.uid() references auth.users(id) on delete set null,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create unique index if not exists pickup_links_token_idx   on public.pickup_links(token);
create index if not exists pickup_links_created_idx on public.pickup_links(created_at desc);

-- ---------------------------------------------------------------------
-- เลขที่เอกสารอัตโนมัติ: QT<YYMM>-0001 (รีเซ็ตทุกเดือน)
-- ---------------------------------------------------------------------
create table if not exists public.quote_counters (
  period   text primary key,
  last_no  int not null
);

create or replace function public.set_quote_no()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  p text := to_char(now() at time zone 'Asia/Bangkok', 'YYMM');
  n int;
begin
  if new.quote_no is null or new.quote_no = '' then
    insert into quote_counters (period, last_no) values (p, 1)
    on conflict (period) do update set last_no = quote_counters.last_no + 1
    returning last_no into n;
    new.quote_no := 'QT' || p || '-' || lpad(n::text, 4, '0');
  end if;
  return new;
end $$;

drop trigger if exists trg_quote_no on public.quotations;
create trigger trg_quote_no before insert on public.quotations
  for each row execute function public.set_quote_no();

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists trg_touch_quotations on public.quotations;
create trigger trg_touch_quotations before update on public.quotations
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_touch_menu_items on public.menu_items;
create trigger trg_touch_menu_items before update on public.menu_items
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_touch_settings on public.settings;
create trigger trg_touch_settings before update on public.settings
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_touch_packages on public.menu_packages;
create trigger trg_touch_packages before update on public.menu_packages
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_touch_pickup_links on public.pickup_links;
create trigger trg_touch_pickup_links before update on public.pickup_links
  for each row execute function public.touch_updated_at();

-- =====================================================================
--  ฟังก์ชันสำหรับหน้าบ้าน (ลูกค้า)
-- =====================================================================

-- ข้อมูลโรงแรมที่เปิดเผยได้
create or replace function public.get_public_settings()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'company_name',       s.company_name,
    'company_name_en',    s.company_name_en,
    'address',            s.address,
    'tax_id',             s.tax_id,
    'phone',              s.phone,
    'email',              s.email,
    'logo_url',           s.logo_url,
    'service_charge_pct', s.service_charge_pct,
    'vat_pct',            s.vat_pct,
    'terms',              s.terms,
    'welcome_text',       s.welcome_text,
    'accept_requests',    s.accept_requests
  )
  from settings s
  where s.id = 1;
$$;

-- แพ็กเกจ/เซ็ตเมนูที่เปิดขาย พร้อมคอร์สและตัวเลือกในแต่ละคอร์ส (ใช้ทั้งหน้าบ้านและหลังบ้าน)
create or replace function public.get_public_packages()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(pkg order by pkg.sort_order, pkg.id), '[]'::jsonb)
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
     where p.is_active
  ) pkg;
$$;

-- ลูกค้าส่งคำขอใบเสนอราคา
--   p_request: { customer_name, phone, email, company, event_type, event_name, event_date,
--                event_time, guest_count, notes, website (honeypot ต้องว่าง) }
--   p_items:   รายการผสมกันได้ระหว่าง
--     - เมนูเดี่ยว  { menu_item_id, qty }
--     - แพ็กเกจ     { menu_package_id, qty, choices: [{ course_id, menu_item_id }, ...] }
--   ไม่รับชื่อ/ราคาจากลูกค้า — ระบบดึงจาก menu_items / menu_packages เสมอ
create or replace function public.submit_request(p_request jsonb, p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  s            settings%rowtype;
  v_today      date := (now() at time zone 'Asia/Bangkok')::date;
  v_name       text := left(trim(coalesce(p_request->>'customer_name', '')), 200);
  v_phone      text := regexp_replace(coalesce(p_request->>'phone', ''), '[^0-9+]', '', 'g');
  v_email      text := nullif(left(trim(coalesce(p_request->>'email', '')), 200), '');
  v_type       text := left(trim(coalesce(p_request->>'event_type', '')), 50);
  v_date       date;
  v_guests     int;
  v_wanted     int;
  v_valid      int;
  v_recent     int;
  v_id         uuid;
  v_no         text;
  v_token      uuid;
  v_sub        numeric(12,2);
  v_sc         numeric(12,2);
  v_vat        numeric(12,2);
  v_pkg_item   jsonb;
  v_pkg_id     bigint;
  pkg          menu_packages%rowtype;
  v_course     record;
  v_chosen_ids bigint[];
  v_chosen_cnt int;
  v_valid_cnt  int;
  v_course_desc text;
  v_desc_parts text[];
  v_pkg_qty    int;
  v_pkg_sort   int := 100000; -- ให้แพ็กเกจเรียงอยู่ท้ายเมนูเดี่ยวเสมอ
begin
  select * into s from settings where id = 1;
  if not found or not s.accept_requests then
    raise exception 'ขณะนี้ปิดรับคำขอใบเสนอราคาออนไลน์ กรุณาติดต่อโรงแรมโดยตรง';
  end if;

  if coalesce(p_request->>'website', '') <> '' then
    raise exception 'คำขอไม่ถูกต้อง';
  end if;

  if v_name = '' then
    raise exception 'กรุณากรอกชื่อผู้ติดต่อ';
  end if;
  if length(v_phone) not between 9 and 15 then
    raise exception 'กรุณากรอกเบอร์โทรศัพท์ให้ถูกต้อง';
  end if;
  if v_email is not null and v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'รูปแบบอีเมลไม่ถูกต้อง';
  end if;
  if v_type = '' then
    raise exception 'กรุณาเลือกประเภทงาน';
  end if;

  if coalesce(p_request->>'event_date', '') !~ '^\d{4}-\d{2}-\d{2}$' then
    raise exception 'กรุณาเลือกวันที่จัดงาน';
  end if;
  v_date := (p_request->>'event_date')::date;
  if v_date < v_today then
    raise exception 'วันที่จัดงานต้องไม่ใช่วันที่ผ่านมาแล้ว';
  end if;

  if coalesce(p_request->>'guest_count', '') !~ '^\d{1,5}$' then
    raise exception 'กรุณากรอกจำนวนแขก';
  end if;
  v_guests := (p_request->>'guest_count')::int;
  if v_guests not between 1 and 5000 then
    raise exception 'จำนวนแขกต้องอยู่ระหว่าง 1 - 5,000 ท่าน';
  end if;

  if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'กรุณาเลือกเมนูอย่างน้อย 1 รายการ';
  end if;
  if jsonb_array_length(p_items) > 100 then
    raise exception 'เลือกเมนูได้ไม่เกิน 100 รายการ';
  end if;

  -- ตรวจว่าเมนูเดี่ยวที่เลือก (ไม่ใช่แพ็กเกจ) ยังเปิดขายอยู่ทุกตัว
  select count(distinct e->>'menu_item_id'),
         count(distinct m.id)
    into v_wanted, v_valid
    from jsonb_array_elements(p_items) e
    left join menu_items m
           on m.id = case when e->>'menu_item_id' ~ '^\d{1,18}$'
                          then (e->>'menu_item_id')::bigint end
          and m.is_active
   where e ? 'menu_item_id' and not (e ? 'menu_package_id');
  if v_wanted > 0 and (v_valid = 0 or v_valid <> v_wanted) then
    raise exception 'บางเมนูไม่พร้อมให้บริการแล้ว กรุณาโหลดหน้าใหม่แล้วเลือกอีกครั้ง';
  end if;

  -- กันส่งถี่เกินไปจากเบอร์เดียวกัน
  select count(*) into v_recent
    from quotations
   where source = 'web' and phone = v_phone and created_at > now() - interval '1 hour';
  if v_recent >= 5 then
    raise exception 'ส่งคำขอบ่อยเกินไป กรุณาลองใหม่ภายหลัง หรือติดต่อโรงแรมโดยตรง';
  end if;

  insert into quotations (
    source, status, customer_name, company, phone, email,
    event_type, event_name, event_date, event_time, guest_count, notes,
    discount, service_charge_pct, vat_pct, valid_until, created_by
  ) values (
    'web', 'new', v_name,
    nullif(left(trim(coalesce(p_request->>'company', '')), 200), ''),
    v_phone, v_email, v_type,
    nullif(left(trim(coalesce(p_request->>'event_name', '')), 200), ''),
    v_date,
    nullif(left(trim(coalesce(p_request->>'event_time', '')), 100), ''),
    v_guests,
    nullif(left(trim(coalesce(p_request->>'notes', '')), 2000), ''),
    0, s.service_charge_pct, s.vat_pct, v_today + s.valid_days, null
  )
  returning id, quote_no, access_token into v_id, v_no, v_token;

  -- เมนูเดี่ยว: ชื่อ/หน่วย/ราคา มาจาก menu_items เท่านั้น
  insert into quotation_items (
    quotation_id, menu_item_id, category_name, name, description, unit, per_person, qty, unit_price, sort_order
  )
  select v_id, m.id, c.name, m.name, m.description, m.unit, m.per_person,
         case when m.per_person then v_guests
              else least(greatest(coalesce(r.qty, 1), 1), 100) end,
         m.price,
         row_number() over (order by coalesce(c.sort_order, 2147483647), c.name, m.sort_order, m.name)
    from (
      select distinct on (id) id, qty
        from (
          select case when e->>'menu_item_id' ~ '^\d{1,18}$' then (e->>'menu_item_id')::bigint end as id,
                 case when e->>'qty' ~ '^\d{1,6}$' then (e->>'qty')::int end as qty
            from jsonb_array_elements(p_items) e
           where e ? 'menu_item_id' and not (e ? 'menu_package_id')
        ) x
       where id is not null
       order by id
    ) r
    join menu_items m on m.id = r.id and m.is_active
    left join menu_categories c on c.id = m.category_id;

  -- แพ็กเกจ: ตรวจทุกคอร์สว่าเลือกครบตามกติกา (pick_count) และตัวเลือกที่เลือกอยู่ในคอร์สนั้นจริง
  for v_pkg_item in
    select value from jsonb_array_elements(p_items) as value where value ? 'menu_package_id'
  loop
    v_pkg_id := case when v_pkg_item->>'menu_package_id' ~ '^\d{1,18}$'
                     then (v_pkg_item->>'menu_package_id')::bigint end;
    select * into pkg from menu_packages where id = v_pkg_id and is_active;
    if not found then
      raise exception 'แพ็กเกจที่เลือกไม่พร้อมให้บริการแล้ว กรุณาโหลดหน้าใหม่แล้วเลือกอีกครั้ง';
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
            from jsonb_array_elements(coalesce(v_pkg_item->'choices', '[]'::jsonb)) ch
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

      select v_course.name || ': ' || string_agg(m.name, ', ' order by m.name)
        into v_course_desc
        from menu_items m where m.id = any(v_chosen_ids);
      v_desc_parts := v_desc_parts || v_course_desc;
    end loop;

    v_pkg_qty := case when v_pkg_item->>'qty' ~ '^\d{1,6}$' then (v_pkg_item->>'qty')::int else 1 end;
    v_pkg_sort := v_pkg_sort + 1;

    insert into quotation_items (
      quotation_id, menu_item_id, category_name, name, description, unit, per_person, qty, unit_price, sort_order
    ) values (
      v_id, null, 'แพ็กเกจอาหาร', pkg.name,
      array_to_string(v_desc_parts, E'\n'),
      pkg.unit, pkg.per_person,
      case when pkg.per_person then v_guests else least(greatest(v_pkg_qty, 1), 100) end,
      pkg.price, v_pkg_sort
    );
  end loop;

  select coalesce(sum(amount), 0) into v_sub from quotation_items where quotation_id = v_id;
  v_sc  := round(v_sub * s.service_charge_pct / 100, 2);
  v_vat := round((v_sub + v_sc) * s.vat_pct / 100, 2);

  update quotations
     set subtotal = v_sub, service_charge = v_sc, vat = v_vat, grand_total = v_sub + v_sc + v_vat
   where id = v_id;

  return jsonb_build_object('quote_no', v_no, 'access_token', v_token);
end $$;

-- ลูกค้าดูคำขอของตัวเองผ่าน token (ไม่มีหมายเหตุภายใน)
create or replace function public.get_request_by_token(p_token uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'quote', to_jsonb(q) - 'id' - 'access_token' - 'internal_note' - 'created_by' - 'source',
    'items', coalesce((
      select jsonb_agg(to_jsonb(i) - 'id' - 'quotation_id' - 'menu_item_id' order by i.sort_order)
        from quotation_items i
       where i.quotation_id = q.id
    ), '[]'::jsonb),
    'settings', public.get_public_settings()
  )
  from quotations q
  where q.access_token = p_token;
$$;

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

  if jsonb_typeof(p_selections) is distinct from 'array' or jsonb_array_length(p_selections) = 0 then
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
  for v_item in select value from jsonb_array_elements(coalesce(p_items, '[]'::jsonb))
  loop
    v_item_id := case when v_item->>'menu_item_id' ~ '^\d{1,18}$' then (v_item->>'menu_item_id')::bigint end;
    if v_item_id is null then
      continue;
    end if;
    select * into m from menu_items where id = v_item_id and is_active;
    if not found then
      raise exception 'เมนูที่เลือกไม่พร้อมให้บริการแล้ว กรุณาโหลดหน้าใหม่แล้วเลือกอีกครั้ง';
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

  update pickup_links
     set selections = v_final, extra_items = v_items_final, status = 'submitted', submitted_at = now()
   where id = l.id;

  return jsonb_build_object('ok', true);
end $$;

-- ส่งออกใบเสนอราคาทั้งหมด (ทุกฟิลด์ + รายการอาหาร) ให้ระบบภายนอก (เว็บจัดเลี้ยงอีกเว็บ) ผ่าน API ของ Supabase เอง
-- ต้องส่ง p_key ให้ตรงกับรหัสลับด้านล่างเท่านั้น ไม่งั้น error 'unauthorized'
-- เรียกได้ทั้ง GET และ POST ที่ https://<project>.supabase.co/rest/v1/rpc/export_quotations (ดูตัวอย่างเรียกใช้ใน README.md)
create or replace function public.export_quotations(p_key text)
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
    to_jsonb(quo) || jsonb_build_object('items', (
      select coalesce(jsonb_agg(to_jsonb(it) order by it.sort_order, it.id), '[]'::jsonb)
        from quotation_items it
       where it.quotation_id = quo.id
    ))
    order by quo.created_at desc
  ), '[]'::jsonb)
  from quotations quo;
end;
$$;

-- ส่งออกข้อมูล "ลิงก์เลือกอาหาร" ทั้งหมด (สถานะ + รายการที่ลูกค้าเลือกแล้ว) ให้ระบบภายนอกดึงไปใช้
-- ใช้รหัสลับเดียวกับ export_quotations (ทีมภายนอกที่ได้ p_key นี้แล้วเรียกได้ทั้ง 2 endpoint)
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

-- =====================================================================
--  ฟังก์ชันสำหรับหลังบ้าน (พนักงาน)
-- =====================================================================

-- บันทึกใบเสนอราคา + รายการ ในธุรกรรมเดียว คำนวณยอดฝั่งเซิร์ฟเวอร์
create or replace function public.save_quotation(p_quote jsonb, p_items jsonb)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id    uuid := nullif(p_quote->>'id', '')::uuid;
  v_disc  numeric := coalesce(nullif(p_quote->>'discount', '')::numeric, 0);
  v_scp   numeric := coalesce(nullif(p_quote->>'service_charge_pct', '')::numeric, 0);
  v_vatp  numeric := coalesce(nullif(p_quote->>'vat_pct', '')::numeric, 0);
  v_sub   numeric(12,2);
  v_base  numeric(12,2);
  v_sc    numeric(12,2);
  v_vat   numeric(12,2);
begin
  if coalesce(trim(p_quote->>'customer_name'), '') = '' then
    raise exception 'กรุณาระบุชื่อลูกค้า';
  end if;

  select coalesce(sum(round(coalesce((i->>'qty')::numeric, 0) * coalesce((i->>'unit_price')::numeric, 0), 2)), 0)
    into v_sub
    from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) as i
   where coalesce(trim(i->>'name'), '') <> '';

  v_base := greatest(v_sub - v_disc, 0);
  v_sc   := round(v_base * v_scp / 100, 2);
  v_vat  := round((v_base + v_sc) * v_vatp / 100, 2);

  if v_id is null then
    insert into quotations (
      source, status, customer_name, company, phone, email, event_type, event_name, event_date, event_time,
      venue, guest_count, notes, internal_note, discount, service_charge_pct, vat_pct,
      subtotal, service_charge, vat, grand_total, valid_until
    ) values (
      'staff',
      coalesce(nullif(p_quote->>'status', ''), 'draft'),
      trim(p_quote->>'customer_name'),
      nullif(trim(p_quote->>'company'), ''),
      nullif(trim(p_quote->>'phone'), ''),
      nullif(trim(p_quote->>'email'), ''),
      nullif(trim(p_quote->>'event_type'), ''),
      nullif(trim(p_quote->>'event_name'), ''),
      nullif(p_quote->>'event_date', '')::date,
      nullif(trim(p_quote->>'event_time'), ''),
      nullif(trim(p_quote->>'venue'), ''),
      coalesce(nullif(p_quote->>'guest_count', '')::int, 0),
      nullif(trim(p_quote->>'notes'), ''),
      nullif(trim(p_quote->>'internal_note'), ''),
      v_disc, v_scp, v_vatp,
      v_sub, v_sc, v_vat, v_base + v_sc + v_vat,
      nullif(p_quote->>'valid_until', '')::date
    )
    returning id into v_id;
  else
    update quotations set
      status             = coalesce(nullif(p_quote->>'status', ''), status),
      customer_name      = trim(p_quote->>'customer_name'),
      company            = nullif(trim(p_quote->>'company'), ''),
      phone              = nullif(trim(p_quote->>'phone'), ''),
      email              = nullif(trim(p_quote->>'email'), ''),
      event_type         = nullif(trim(p_quote->>'event_type'), ''),
      event_name         = nullif(trim(p_quote->>'event_name'), ''),
      event_date         = nullif(p_quote->>'event_date', '')::date,
      event_time         = nullif(trim(p_quote->>'event_time'), ''),
      venue              = nullif(trim(p_quote->>'venue'), ''),
      guest_count        = coalesce(nullif(p_quote->>'guest_count', '')::int, 0),
      notes              = nullif(trim(p_quote->>'notes'), ''),
      internal_note      = nullif(trim(p_quote->>'internal_note'), ''),
      discount           = v_disc,
      service_charge_pct = v_scp,
      vat_pct            = v_vatp,
      subtotal           = v_sub,
      service_charge     = v_sc,
      vat                = v_vat,
      grand_total        = v_base + v_sc + v_vat,
      valid_until        = nullif(p_quote->>'valid_until', '')::date
    where id = v_id;

    if not found then
      raise exception 'ไม่พบใบเสนอราคา หรือไม่มีสิทธิ์แก้ไข';
    end if;

    delete from quotation_items where quotation_id = v_id;
  end if;

  insert into quotation_items (
    quotation_id, menu_item_id, category_name, name, description, unit, per_person, qty, unit_price, sort_order
  )
  select v_id,
         nullif(t.i->>'menu_item_id', '')::bigint,
         nullif(t.i->>'category_name', ''),
         trim(t.i->>'name'),
         nullif(t.i->>'description', ''),
         coalesce(nullif(t.i->>'unit', ''), 'รายการ'),
         coalesce((t.i->>'per_person')::boolean, false),
         coalesce((t.i->>'qty')::numeric, 0),
         coalesce((t.i->>'unit_price')::numeric, 0),
         t.ord
    from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) with ordinality as t(i, ord)
   where coalesce(trim(t.i->>'name'), '') <> '';

  return v_id;
end $$;

-- นำเข้าเมนูจำนวนมากจากไฟล์ CSV (แปลงเป็น jsonb แล้วส่งมาจากหน้าเว็บ) — เฉพาะพนักงาน
--   p_rows: [{ id, category, name, name_en, description, price, unit, per_person, image_url, is_active, sort_order }]
--   id ว่าง -> เพิ่มรายการใหม่ · id มีค่า -> แก้ไขรายการเดิม (ไม่พบ = error)
--   category เป็น "ชื่อ" หมวดหมู่ ไม่ใช่ id — ถ้ายังไม่มีหมวดนี้จะสร้างให้อัตโนมัติ
--   แต่ละแถวทำงานแยกกัน (1 แถวพังไม่กระทบแถวอื่น) แล้วคืนสรุปจำนวนที่ทำสำเร็จ/ผิดพลาด
create or replace function public.import_menu_items(p_rows jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  r            jsonb;
  v_cat_name   text;
  v_cat_id     bigint;
  v_id         bigint;
  v_per_person text;
  v_is_active  text;
  v_inserted   int := 0;
  v_updated    int := 0;
  v_errors     jsonb := '[]'::jsonb;
  v_idx        int := 0;
begin
  if jsonb_typeof(p_rows) is distinct from 'array' then
    raise exception 'รูปแบบข้อมูลไม่ถูกต้อง';
  end if;
  if jsonb_array_length(p_rows) = 0 then
    raise exception 'ไม่มีข้อมูลให้นำเข้า';
  end if;
  if jsonb_array_length(p_rows) > 2000 then
    raise exception 'นำเข้าได้ไม่เกิน 2000 แถวต่อครั้ง';
  end if;

  for r in select value from jsonb_array_elements(p_rows) as value
  loop
    v_idx := v_idx + 1;
    begin
      if coalesce(trim(r->>'name'), '') = '' then
        raise exception 'ไม่มีชื่อเมนู';
      end if;
      if coalesce(r->>'price', '') !~ '^\d+(\.\d+)?$' then
        raise exception 'ราคาไม่ถูกต้อง ("%")', coalesce(r->>'price', '');
      end if;

      v_cat_id := null;
      v_cat_name := nullif(trim(r->>'category'), '');
      if v_cat_name is not null then
        select id into v_cat_id from menu_categories where lower(name) = lower(v_cat_name) limit 1;
        if v_cat_id is null then
          insert into menu_categories (name, sort_order)
          values (v_cat_name, coalesce((select max(sort_order) from menu_categories), 0) + 10)
          returning id into v_cat_id;
        end if;
      end if;

      v_per_person := lower(trim(coalesce(r->>'per_person', '')));
      v_is_active  := lower(trim(coalesce(r->>'is_active', '')));
      v_id := case when r->>'id' ~ '^\d+$' then (r->>'id')::bigint end;

      if v_id is not null then
        update menu_items set
          category_id = v_cat_id,
          name        = trim(r->>'name'),
          name_en     = nullif(trim(r->>'name_en'), ''),
          description = nullif(trim(r->>'description'), ''),
          price       = (r->>'price')::numeric,
          unit        = coalesce(nullif(trim(r->>'unit'), ''), 'ท่าน'),
          per_person  = v_per_person not in ('0', 'false', 'no', 'ไม่ใช่', 'n'),
          image_url   = nullif(trim(r->>'image_url'), ''),
          is_active   = v_is_active not in ('0', 'false', 'no', 'ไม่ใช่', 'n'),
          sort_order  = coalesce(nullif(r->>'sort_order', '')::int, 0)
        where id = v_id;

        if found then v_updated := v_updated + 1;
        else raise exception 'ไม่พบรายการ id=%', v_id;
        end if;
      else
        insert into menu_items (
          category_id, name, name_en, description, price, unit, per_person, image_url, is_active, sort_order
        ) values (
          v_cat_id, trim(r->>'name'), nullif(trim(r->>'name_en'), ''), nullif(trim(r->>'description'), ''),
          (r->>'price')::numeric, coalesce(nullif(trim(r->>'unit'), ''), 'ท่าน'),
          v_per_person not in ('0', 'false', 'no', 'ไม่ใช่', 'n'),
          nullif(trim(r->>'image_url'), ''),
          v_is_active not in ('0', 'false', 'no', 'ไม่ใช่', 'n'),
          coalesce(nullif(r->>'sort_order', '')::int, 0)
        );
        v_inserted := v_inserted + 1;
      end if;
    exception when others then
      v_errors := v_errors || jsonb_build_object('row', v_idx, 'message', sqlerrm);
    end;
  end loop;

  return jsonb_build_object('inserted', v_inserted, 'updated', v_updated, 'errors', v_errors);
end $$;

-- สรุปจำนวน/มูลค่าตามสถานะ (การ์ดสรุปหน้ารายการ)
create or replace function public.quotation_stats()
returns table (status text, cnt bigint, total numeric)
language sql
stable
security invoker
set search_path = public
as $$
  select q.status, count(*), coalesce(sum(q.grand_total), 0)
    from quotations q
   group by q.status;
$$;

-- =====================================================================
--  ที่เก็บรูปภาพเมนู/แพ็กเกจ (Supabase Storage)
--  bucket สาธารณะ: ใครก็ดูรูปได้ (จำเป็น เพราะลูกค้าไม่ได้ล็อกอิน) แต่อัปโหลด/ลบได้เฉพาะพนักงาน
-- =====================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('menu-images', 'menu-images', true, 5242880, array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set
  public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif'];

drop policy if exists "public read menu-images"   on storage.objects;
drop policy if exists "staff insert menu-images"  on storage.objects;
drop policy if exists "staff update menu-images"  on storage.objects;
drop policy if exists "staff delete menu-images"  on storage.objects;

create policy "public read menu-images" on storage.objects
  for select using (bucket_id = 'menu-images');
create policy "staff insert menu-images" on storage.objects
  for insert to authenticated with check (bucket_id = 'menu-images');
create policy "staff update menu-images" on storage.objects
  for update to authenticated using (bucket_id = 'menu-images') with check (bucket_id = 'menu-images');
create policy "staff delete menu-images" on storage.objects
  for delete to authenticated using (bucket_id = 'menu-images');

-- =====================================================================
--  สิทธิ์การเข้าถึง
-- =====================================================================
revoke execute on function public.set_quote_no()                     from public, anon, authenticated;
revoke execute on function public.get_public_settings()              from public;
revoke execute on function public.get_public_packages()              from public;
revoke execute on function public.submit_request(jsonb, jsonb)       from public;
revoke execute on function public.get_request_by_token(uuid)         from public;
revoke execute on function public.export_quotations(text)            from public;
revoke execute on function public.export_pickup_selections(text)     from public;
revoke execute on function public.save_quotation(jsonb, jsonb)       from public, anon;
revoke execute on function public.quotation_stats()                  from public, anon;
revoke execute on function public.import_menu_items(jsonb)           from public, anon;
revoke execute on function public.get_pickup_link(uuid)              from public;
revoke execute on function public.submit_pickup_selection(uuid, jsonb, jsonb) from public;

grant execute on function public.get_public_settings()        to anon, authenticated;
grant execute on function public.get_public_packages()        to anon, authenticated;
grant execute on function public.submit_request(jsonb, jsonb) to anon, authenticated;
grant execute on function public.get_request_by_token(uuid)   to anon, authenticated;
grant execute on function public.export_quotations(text)      to anon, authenticated;
grant execute on function public.export_pickup_selections(text) to anon, authenticated;
grant execute on function public.save_quotation(jsonb, jsonb) to authenticated;
grant execute on function public.quotation_stats()            to authenticated;
grant execute on function public.import_menu_items(jsonb)     to authenticated;
grant execute on function public.get_pickup_link(uuid)             to anon, authenticated;
grant execute on function public.submit_pickup_selection(uuid, jsonb, jsonb) to anon, authenticated;

grant usage on schema public to anon, authenticated;

revoke all on public.settings, public.quotations, public.quotation_items, public.quote_counters from anon;
revoke all on public.menu_categories, public.menu_items from anon;
revoke all on public.menu_packages, public.menu_package_courses, public.menu_package_course_items from anon;
revoke all on public.pickup_links from anon;
grant select on public.menu_categories, public.menu_items to anon;
-- หมายเหตุ: แพ็กเกจฝั่งลูกค้าอ่านผ่าน get_public_packages() (security definer) ไม่ได้ให้สิทธิ์อ่านตารางตรงๆ
-- pickup_links ก็เช่นกัน: ลูกค้าเข้าถึงได้เฉพาะผ่าน get_pickup_link()/submit_pickup_selection() เท่านั้น
-- ห้าม grant select ตรงให้ anon เด็ดขาด เพราะแถวมี token + PII ของลูกค้าทุกคน

grant select, update on public.settings to authenticated;
grant select, insert, update, delete on public.menu_categories, public.menu_items,
  public.quotations, public.quotation_items to authenticated;
grant select, insert, update, delete on public.menu_packages, public.menu_package_courses,
  public.menu_package_course_items to authenticated;
grant select, insert, update, delete on public.pickup_links to authenticated;
revoke all on public.quote_counters from authenticated;

alter table public.settings         enable row level security;
alter table public.menu_categories  enable row level security;
alter table public.menu_items       enable row level security;
alter table public.menu_packages             enable row level security;
alter table public.menu_package_courses      enable row level security;
alter table public.menu_package_course_items enable row level security;
alter table public.quotations       enable row level security;
alter table public.quotation_items  enable row level security;
alter table public.quote_counters   enable row level security;
alter table public.pickup_links     enable row level security;

-- ลูกค้า (anon): อ่านหมวดหมู่ และเมนูที่เปิดใช้งาน
drop policy if exists "public read categories" on public.menu_categories;
create policy "public read categories" on public.menu_categories for select to anon using (true);

drop policy if exists "public read active menu" on public.menu_items;
create policy "public read active menu" on public.menu_items for select to anon using (is_active);

-- พนักงาน (authenticated): ทำได้ทุกอย่าง
drop policy if exists "staff read settings"   on public.settings;
drop policy if exists "staff update settings" on public.settings;
create policy "staff read settings"   on public.settings for select to authenticated using (true);
create policy "staff update settings" on public.settings for update to authenticated using (true) with check (true);

drop policy if exists "staff all categories" on public.menu_categories;
create policy "staff all categories" on public.menu_categories for all to authenticated using (true) with check (true);

drop policy if exists "staff all menu items" on public.menu_items;
create policy "staff all menu items" on public.menu_items for all to authenticated using (true) with check (true);

drop policy if exists "staff all quotations" on public.quotations;
create policy "staff all quotations" on public.quotations for all to authenticated using (true) with check (true);

drop policy if exists "staff all quotation items" on public.quotation_items;
create policy "staff all quotation items" on public.quotation_items for all to authenticated using (true) with check (true);

drop policy if exists "staff all packages" on public.menu_packages;
create policy "staff all packages" on public.menu_packages for all to authenticated using (true) with check (true);

drop policy if exists "staff all package courses" on public.menu_package_courses;
create policy "staff all package courses" on public.menu_package_courses for all to authenticated using (true) with check (true);

drop policy if exists "staff all package course items" on public.menu_package_course_items;
create policy "staff all package course items" on public.menu_package_course_items for all to authenticated using (true) with check (true);

drop policy if exists "staff all pickup links" on public.pickup_links;
create policy "staff all pickup links" on public.pickup_links for all to authenticated using (true) with check (true);
