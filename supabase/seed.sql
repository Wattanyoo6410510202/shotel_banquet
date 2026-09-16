-- =====================================================================
--  ข้อมูลตัวอย่างเมนูงานจัดเลี้ยง (รันหลัง schema.sql — ไม่บังคับ)
--  จะเพิ่มข้อมูลเฉพาะตอนที่ยังไม่มีหมวดหมู่เลย (รันซ้ำไม่ซ้ำข้อมูล)
-- =====================================================================

do $seed$
begin
if exists (select 1 from public.menu_categories) then
  raise notice 'มีข้อมูลเมนูอยู่แล้ว ข้ามการเพิ่มข้อมูลตัวอย่าง';
  return;
end if;

insert into public.menu_categories (name, sort_order) values
  ('อาหารว่าง (Coffee Break)', 10),
  ('ค็อกเทล & คานาเป้', 20),
  ('สลัด & ยำ', 30),
  ('ซุป', 40),
  ('อาหารจานหลัก - ไทย', 50),
  ('อาหารจานหลัก - นานาชาติ', 60),
  ('ข้าว & เส้น', 70),
  ('สถานีอาหาร (Live Station)', 80),
  ('ของหวาน', 90),
  ('เครื่องดื่ม', 100),
  ('บริการเสริม', 110);

insert into public.menu_items (category_id, name, name_en, description, price, unit, per_person, sort_order)
select c.id, v.name, v.name_en, v.description, v.price, v.unit, v.per_person, v.sort_order
from (values
  -- Coffee Break
  ('อาหารว่าง (Coffee Break)', 'ชุดเบรกเช้า A', 'Morning Break A', 'กาแฟ ชา น้ำผลไม้ + ขนม 2 อย่าง', 150, 'ท่าน', true, 1),
  ('อาหารว่าง (Coffee Break)', 'ชุดเบรกเช้า B', 'Morning Break B', 'กาแฟ ชา น้ำผลไม้ + ขนม 3 อย่าง + ผลไม้', 220, 'ท่าน', true, 2),
  ('อาหารว่าง (Coffee Break)', 'ครัวซองต์เนยสด', 'Butter Croissant', 'อบสดใหม่จากเบเกอรี่ของโรงแรม', 45, 'ท่าน', true, 3),
  ('อาหารว่าง (Coffee Break)', 'ขนมไทยรวม', 'Assorted Thai Desserts', 'ขนมชั้น ทองหยิบ ข้าวเหนียวสังขยา', 55, 'ท่าน', true, 4),

  -- Cocktail
  ('ค็อกเทล & คานาเป้', 'คานาเป้แซลมอนรมควัน', 'Smoked Salmon Canapé', 'ครีมชีส เคเปอร์ บนขนมปังกรอบ', 65, 'ท่าน', true, 1),
  ('ค็อกเทล & คานาเป้', 'ไก่สะเต๊ะ', 'Chicken Satay', 'พร้อมน้ำจิ้มถั่วและอาจาด', 45, 'ท่าน', true, 2),
  ('ค็อกเทล & คานาเป้', 'ทอดมันกุ้ง', 'Shrimp Cake', 'พร้อมน้ำจิ้มบ๊วย', 55, 'ท่าน', true, 3),
  ('ค็อกเทล & คานาเป้', 'มินิพิซซ่า', 'Mini Pizza', 'หน้าฮาวายเอี้ยนและเปปเปอโรนี', 40, 'ท่าน', true, 4),

  -- Salad
  ('สลัด & ยำ', 'สลัดบาร์', 'Salad Bar', 'ผักสลัดสด 6 ชนิด พร้อมน้ำสลัด 3 แบบ', 90, 'ท่าน', true, 1),
  ('สลัด & ยำ', 'ยำวุ้นเส้นทะเล', 'Spicy Glass Noodle Seafood Salad', null, 60, 'ท่าน', true, 2),
  ('สลัด & ยำ', 'ส้มตำไทย', 'Papaya Salad', null, 40, 'ท่าน', true, 3),

  -- Soup
  ('ซุป', 'ต้มยำกุ้งน้ำข้น', 'Tom Yum Goong', null, 70, 'ท่าน', true, 1),
  ('ซุป', 'ต้มข่าไก่', 'Chicken in Coconut Soup', null, 50, 'ท่าน', true, 2),
  ('ซุป', 'ซุปครีมเห็ด', 'Cream of Mushroom Soup', 'พร้อมขนมปังกระเทียม', 55, 'ท่าน', true, 3),

  -- Thai main
  ('อาหารจานหลัก - ไทย', 'แกงเขียวหวานไก่', 'Green Curry with Chicken', null, 60, 'ท่าน', true, 1),
  ('อาหารจานหลัก - ไทย', 'ปลากะพงราดพริก', 'Crispy Sea Bass with Chili Sauce', null, 95, 'ท่าน', true, 2),
  ('อาหารจานหลัก - ไทย', 'หมูผัดพริกไทยดำ', 'Stir-fried Pork with Black Pepper', null, 55, 'ท่าน', true, 3),
  ('อาหารจานหลัก - ไทย', 'แกงมัสมั่นเนื้อ', 'Beef Massaman Curry', null, 85, 'ท่าน', true, 4),
  ('อาหารจานหลัก - ไทย', 'ผัดผักรวมมิตร', 'Stir-fried Mixed Vegetables', null, 35, 'ท่าน', true, 5),

  -- International
  ('อาหารจานหลัก - นานาชาติ', 'สเต๊กไก่ซอสเห็ด', 'Chicken Steak with Mushroom Sauce', null, 90, 'ท่าน', true, 1),
  ('อาหารจานหลัก - นานาชาติ', 'แซลมอนย่างซอสเลมอนเนย', 'Grilled Salmon Lemon Butter', null, 160, 'ท่าน', true, 2),
  ('อาหารจานหลัก - นานาชาติ', 'สปาเก็ตตี้คาโบนาร่า', 'Spaghetti Carbonara', null, 60, 'ท่าน', true, 3),

  -- Rice & noodles
  ('ข้าว & เส้น', 'ข้าวหอมมะลิ', 'Steamed Jasmine Rice', null, 15, 'ท่าน', true, 1),
  ('ข้าว & เส้น', 'ข้าวผัดสับปะรด', 'Pineapple Fried Rice', null, 45, 'ท่าน', true, 2),
  ('ข้าว & เส้น', 'ผัดไทยกุ้งสด', 'Pad Thai with Shrimp', null, 65, 'ท่าน', true, 3),

  -- Live station
  ('สถานีอาหาร (Live Station)', 'สถานีซูชิ & ซาชิมิ', 'Sushi & Sashimi Station', 'เชฟปั้นสดหน้างาน', 180, 'ท่าน', true, 1),
  ('สถานีอาหาร (Live Station)', 'สถานีเนื้อโรสต์บีฟ', 'Roast Beef Carving Station', 'พร้อมซอสเกรวี่และมัสตาร์ด', 220, 'ท่าน', true, 2),
  ('สถานีอาหาร (Live Station)', 'สถานีก๋วยเตี๋ยวเรือ', 'Boat Noodle Station', null, 60, 'ท่าน', true, 3),
  ('สถานีอาหาร (Live Station)', 'หมูหันทั้งตัว', 'Whole Roasted Suckling Pig', 'ขนาด 5-6 กก. สำหรับ 40-50 ท่าน', 4500, 'ตัว', false, 4),

  -- Dessert
  ('ของหวาน', 'ผลไม้ตามฤดูกาล', 'Seasonal Fresh Fruits', null, 40, 'ท่าน', true, 1),
  ('ของหวาน', 'ข้าวเหนียวมะม่วง', 'Mango Sticky Rice', null, 60, 'ท่าน', true, 2),
  ('ของหวาน', 'ช็อกโกแลตฟาวน์เทน', 'Chocolate Fountain', 'พร้อมผลไม้และมาร์ชเมลโล่', 6500, 'ชุด', false, 3),
  ('ของหวาน', 'เค้กมินิรวม', 'Assorted Mini Cakes', null, 55, 'ท่าน', true, 4),

  -- Drinks
  ('เครื่องดื่ม', 'น้ำดื่ม & น้ำอัดลม (Free flow)', 'Soft Drinks Free Flow', 'ตลอดระยะเวลาจัดงาน', 90, 'ท่าน', true, 1),
  ('เครื่องดื่ม', 'น้ำผลไม้รวม', 'Assorted Juices', null, 60, 'ท่าน', true, 2),
  ('เครื่องดื่ม', 'เบียร์สด', 'Draught Beer', 'ถังขนาด 30 ลิตร', 7500, 'ถัง', false, 3),

  -- Extras
  ('บริการเสริม', 'ตกแต่งดอกไม้เวที', 'Stage Flower Decoration', null, 8000, 'งาน', false, 1),
  ('บริการเสริม', 'ระบบเสียง & โปรเจกเตอร์', 'Sound System & Projector', null, 5000, 'งาน', false, 2),
  ('บริการเสริม', 'พิธีกร', 'MC', 'ระยะเวลา 4 ชั่วโมง', 12000, 'งาน', false, 3),
  ('บริการเสริม', 'ป้ายต้อนรับหน้างาน', 'Welcome Signage', null, 1500, 'ชิ้น', false, 4)
) as v(cat, name, name_en, description, price, unit, per_person, sort_order)
join public.menu_categories c on c.name = v.cat;

end $seed$;
