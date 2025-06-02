-- ============================================================================
-- 🇦🇷 PRODUCTOS ARGENTINOS COMPLETOS - Base de Datos Realista
-- ============================================================================
-- Archivo: init-scripts/argentina_products_data.sql
-- Propósito: Productos reales del mercado argentino con precios actualizados 2024
-- Dependencias: 00-06 archivos de migración completados
-- ============================================================================

-- 🏷️ CATEGORÍAS ARGENTINAS REALISTAS
INSERT INTO stock.categories (name, description, icon_emoji, sort_order, seo_slug, meta_title, meta_description)
VALUES
    ('Frutas y Verduras', 'Frutas y verduras frescas de estación', '🥬', 1, 'frutas-verduras', 'Frutas y Verduras Frescas', 'Productos frescos directo del Mercado Central'),
    ('Lácteos y Huevos', 'Leche, quesos, yogures, manteca y huevos', '🥛', 2, 'lacteos-huevos', 'Lácteos y Huevos', 'Productos lácteos frescos de marcas argentinas'),
    ('Panadería y Bollería', 'Pan fresco, facturas y productos de panadería', '🍞', 3, 'panaderia-bolleria', 'Panadería Fresca', 'Pan y bollería artesanal del día'),
    ('Carnes y Pollo', 'Carnes frescas, embutidos y productos avícolas', '🥩', 4, 'carnes-pollo', 'Carnes Frescas', 'Carnes premium y productos avícolas'),
    ('Pescados y Mariscos', 'Pescados frescos y productos del mar', '🐟', 5, 'pescados-mariscos', 'Pescados y Mariscos', 'Productos del mar frescos y congelados'),
    ('Bebidas', 'Gaseosas, jugos, aguas y bebidas alcohólicas', '🥤', 6, 'bebidas', 'Bebidas y Refrescos', 'Bebidas nacionales e importadas'),
    ('Almacén y Despensa', 'Productos secos, enlatados y conservas', '🍝', 7, 'almacen-despensa', 'Almacén y Despensa', 'Productos no perecederos para tu despensa'),
    ('Aceites y Condimentos', 'Aceites, vinagres, especias y condimentos', '🫒', 8, 'aceites-condimentos', 'Aceites y Condimentos', 'Condimentos y especias para cocinar'),
    ('Limpieza del Hogar', 'Productos de limpieza y mantenimiento', '🧽', 9, 'limpieza-hogar', 'Limpieza del Hogar', 'Todo para mantener tu hogar limpio'),
    ('Higiene Personal', 'Productos de higiene y cuidado personal', '🧴', 10, 'higiene-personal', 'Higiene Personal', 'Productos para el cuidado personal'),
    ('Perfumería y Cosmética', 'Perfumes, maquillaje y productos de belleza', '💄', 11, 'perfumeria-cosmetica', 'Perfumería y Cosmética', 'Productos de belleza y cuidado'),
    ('Bebé y Mamá', 'Productos para bebés y cuidado maternal', '👶', 12, 'bebe-mama', 'Bebé y Mamá', 'Todo para el cuidado del bebé y la mamá'),
    ('Mascotas', 'Alimentos y accesorios para mascotas', '🐕', 13, 'mascotas', 'Productos para Mascotas', 'Alimento y cuidado para tus mascotas'),
    ('Congelados', 'Productos congelados y helados', '🧊', 14, 'congelados', 'Productos Congelados', 'Alimentos congelados y helados'),
    ('Dietética y Naturales', 'Productos dietéticos, orgánicos y naturales', '🌱', 15, 'dietetica-naturales', 'Dietética y Naturales', 'Productos saludables y orgánicos'),
    ('Snacks y Golosinas', 'Snacks, galletitas, chocolates y golosinas', '🍪', 16, 'snacks-golosinas', 'Snacks y Golosinas', 'Snacks y dulces para todos los gustos'),
    ('Cigarrillos y Tabaco', 'Productos de tabaquería', '🚬', 17, 'cigarrillos-tabaco', 'Cigarrillos y Tabaco', 'Productos de tabaquería para mayores de 18'),
    ('Tecnología y Hogar', 'Productos tecnológicos y para el hogar', '📱', 18, 'tecnologia-hogar', 'Tecnología y Hogar', 'Productos tecnológicos y del hogar')
ON CONFLICT (name) DO NOTHING;

-- 🥬 FRUTAS Y VERDURAS (Categoría 1)
INSERT INTO stock.products (name, description, price, stock_quantity, min_stock_alert, category_id, brand, weight_unit,
                            weight_value, barcode, sku, is_featured, meta_keywords, image_url)
VALUES
    -- Frutas
    ('Manzana Roja', 'Manzana roja argentina, dulce y crujiente', 350.00, 120, 20, 1, 'Argentina', 'kg', 1.0, '2001001001001', 'MANZ-ROJA-001', true, 'manzana,fruta,roja,argentina', 'https://via.placeholder.com/300x300/ff6b6b/ffffff?text=Manzana'),
    ('Manzana Verde', 'Manzana verde Granny Smith, ácida y refrescante', 320.00, 100, 20, 1, 'Argentina', 'kg', 1.0, '2001001001002', 'MANZ-VERDE-001', false, 'manzana,verde,granny smith', 'https://via.placeholder.com/300x300/4ecdc4/ffffff?text=Manzana+Verde'),
    ('Banana', 'Banana ecuatoriana madura, ideal para desayuno', 280.00, 150, 25, 1, 'Ecuador', 'kg', 1.0, '2001001001003', 'BANA-001', true, 'banana,potasio,ecuador', 'https://via.placeholder.com/300x300/ffe66d/ffffff?text=Banana'),
    ('Naranja', 'Naranja argentina dulce, rica en vitamina C', 300.00, 80, 15, 1, 'Argentina', 'kg', 1.0, '2001001001004', 'NARA-001', true, 'naranja,vitamina c,argentina', 'https://via.placeholder.com/300x300/ff8c42/ffffff?text=Naranja'),
    ('Limón', 'Limón tucumano, ideal para condimentar', 450.00, 60, 10, 1, 'Tucumán', 'kg', 1.0, '2001001001005', 'LIMO-001', false, 'limon,tucuman,condimento', 'https://via.placeholder.com/300x300/a8e6cf/ffffff?text=Limón'),
    ('Mandarina', 'Mandarina argentina dulce y jugosa', 420.00, 70, 12, 1, 'Argentina', 'kg', 1.0, '2001001001006', 'MAND-001', false, 'mandarina,dulce,argentina', 'https://via.placeholder.com/300x300/ffaaa5/ffffff?text=Mandarina'),
    ('Pera', 'Pera argentina Williams, dulce y jugosa', 380.00, 50, 10, 1, 'Argentina', 'kg', 1.0, '2001001001007', 'PERA-001', false, 'pera,williams,argentina', 'https://via.placeholder.com/300x300/dda0dd/ffffff?text=Pera'),
    ('Uva Verde', 'Uva verde sin semillas, dulce y refrescante', 650.00, 40, 8, 1, 'Mendoza', 'kg', 1.0, '2001001001008', 'UVA-VERDE-001', false, 'uva,verde,mendoza', 'https://via.placeholder.com/300x300/90ee90/ffffff?text=Uva+Verde'),
    ('Frutilla', 'Frutilla argentina fresca de estación', 890.00, 30, 5, 1, 'Argentina', 'kg', 1.0, '2001001001009', 'FRUT-001', true, 'frutilla,fresca,estacion', 'https://via.placeholder.com/300x300/ff1744/ffffff?text=Frutilla'),
    ('Durazno', 'Durazno argentino maduro y dulce', 520.00, 35, 7, 1, 'Mendoza', 'kg', 1.0, '2001001001010', 'DURA-001', false, 'durazno,mendoza,dulce', 'https://via.placeholder.com/300x300/ffcc02/ffffff?text=Durazno'),

    -- Verduras de Hoja
    ('Lechuga Mantecosa', 'Lechuga mantecosa hidropónica fresca', 280.00, 60, 12, 1, 'Hidropónica', 'unidad', 1.0, '2001001002001', 'LECH-MANT-001', false, 'lechuga,mantecosa,hidroponica', 'https://via.placeholder.com/300x300/98fb98/ffffff?text=Lechuga'),
    ('Lechuga Crespa', 'Lechuga crespa verde, ideal para ensaladas', 250.00, 50, 10, 1, 'Argentina', 'unidad', 1.0, '2001001002002', 'LECH-CRES-001', false, 'lechuga,crespa,ensalada', 'https://via.placeholder.com/300x300/90ee90/ffffff?text=L.Crespa'),
    ('Espinaca', 'Espinaca fresca, rica en hierro', 320.00, 40, 8, 1, 'Argentina', 'atado', 1.0, '2001001002003', 'ESPI-001', false, 'espinaca,hierro,fresca', 'https://via.placeholder.com/300x300/006400/ffffff?text=Espinaca'),
    ('Rúcula', 'Rúcula fresca con sabor levemente picante', 380.00, 35, 7, 1, 'Argentina', 'atado', 1.0, '2001001002004', 'RUCUL-001', false, 'rucula,picante,fresca', 'https://via.placeholder.com/300x300/228b22/ffffff?text=Rúcula'),
    ('Acelga', 'Acelga fresca con tallo blanco', 250.00, 45, 9, 1, 'Argentina', 'atado', 1.0, '2001001002005', 'ACEL-001', false, 'acelga,tallo blanco', 'https://via.placeholder.com/300x300/32cd32/ffffff?text=Acelga'),

    -- Verduras de Fruto
    ('Tomate Redondo', 'Tomate redondo argentino, ideal para ensaladas', 420.00, 80, 15, 1, 'Argentina', 'kg', 1.0, '2001001003001', 'TOMA-RED-001', true, 'tomate,redondo,ensalada', 'https://via.placeholder.com/300x300/ff6347/ffffff?text=Tomate'),
    ('Tomate Cherry', 'Tomate cherry dulce, ideal para aperitivos', 650.00, 30, 6, 1, 'Argentina', 'kg', 1.0, '2001001003002', 'TOMA-CHER-001', false, 'tomate,cherry,dulce', 'https://via.placeholder.com/300x300/ff4500/ffffff?text=T.Cherry'),
    ('Morrón Rojo', 'Morrón rojo dulce, ideal para asados', 580.00, 40, 8, 1, 'Argentina', 'kg', 1.0, '2001001003003', 'MORR-ROJO-001', false, 'morron,rojo,asado', 'https://via.placeholder.com/300x300/dc143c/ffffff?text=Morrón'),
    ('Morrón Verde', 'Morrón verde fresco para cocinar', 520.00, 45, 9, 1, 'Argentina', 'kg', 1.0, '2001001003004', 'MORR-VERDE-001', false, 'morron,verde,cocinar', 'https://via.placeholder.com/300x300/008000/ffffff?text=M.Verde'),
    ('Pepino', 'Pepino fresco hidropónico', 380.00, 35, 7, 1, 'Hidropónico', 'kg', 1.0, '2001001003005', 'PEPI-001', false, 'pepino,hidroponico,fresco', 'https://via.placeholder.com/300x300/9acd32/ffffff?text=Pepino'),
    ('Berenjena', 'Berenjena violeta fresca', 450.00, 25, 5, 1, 'Argentina', 'kg', 1.0, '2001001003006', 'BERE-001', false, 'berenjena,violeta', 'https://via.placeholder.com/300x300/9370db/ffffff?text=Berenjena'),

    -- Verduras de Raíz
    ('Papa', 'Papa argentina blanca para cocinar', 250.00, 200, 40, 1, 'Argentina', 'kg', 1.0, '2001001004001', 'PAPA-001', true, 'papa,blanca,argentina', 'https://via.placeholder.com/300x300/deb887/ffffff?text=Papa'),
    ('Batata', 'Batata dulce argentina', 320.00, 80, 15, 1, 'Argentina', 'kg', 1.0, '2001001004002', 'BATA-001', false, 'batata,dulce,argentina', 'https://via.placeholder.com/300x300/ff8c00/ffffff?text=Batata'),
    ('Zanahoria', 'Zanahoria fresca argentina', 280.00, 60, 12, 1, 'Argentina', 'kg', 1.0, '2001001004003', 'ZANA-001', false, 'zanahoria,fresca', 'https://via.placeholder.com/300x300/ffa500/ffffff?text=Zanahoria'),
    ('Cebolla', 'Cebolla blanca argentina', 220.00, 100, 20, 1, 'Argentina', 'kg', 1.0, '2001001004004', 'CEBO-001', true, 'cebolla,blanca,argentina', 'https://via.placeholder.com/300x300/f5deb3/ffffff?text=Cebolla'),
    ('Cebolla de Verdeo', 'Cebolla de verdeo fresca', 180.00, 40, 8, 1, 'Argentina', 'atado', 1.0, '2001001004005', 'CEBO-VERD-001', false, 'cebolla,verdeo,fresca', 'https://via.placeholder.com/300x300/adff2f/ffffff?text=C.Verdeo'),
    ('Ajo', 'Ajo argentino seco de Mendoza', 650.00, 30, 6, 1, 'Mendoza', 'kg', 1.0, '2001001004006', 'AJO-001', false, 'ajo,mendoza,seco', 'https://via.placeholder.com/300x300/fffacd/ffffff?text=Ajo');

-- 🥛 LÁCTEOS Y HUEVOS (Categoría 2)
INSERT INTO stock.products (name, description, price, stock_quantity, min_stock_alert, category_id, brand, weight_unit,
                            weight_value, barcode, sku, is_featured, meta_keywords, image_url)
VALUES
    -- Leches
    ('Leche Entera La Serenísima', 'Leche entera pasteurizada en sachet', 450.00, 100, 20, 2, 'La Serenísima', 'l', 1.0, '7790070000111', 'LECH-SERE-ENT', true, 'leche,entera,serenisima', 'https://via.placeholder.com/300x300/87ceeb/ffffff?text=Leche+LS'),
    ('Leche Descremada La Serenísima', 'Leche descremada 0% grasa', 470.00, 80, 15, 2, 'La Serenísima', 'l', 1.0, '7790070000222', 'LECH-SERE-DESC', false, 'leche,descremada,0grasa', 'https://via.placeholder.com/300x300/add8e6/ffffff?text=L.Desc'),
    ('Leche Sancor Entera', 'Leche entera Sancor en sachet', 420.00, 90, 18, 2, 'Sancor', 'l', 1.0, '7790070001111', 'LECH-SANC-ENT', false, 'leche,entera,sancor', 'https://via.placeholder.com/300x300/4682b4/ffffff?text=Sancor'),
    ('Leche Larga Vida Entera', 'Leche UHT larga vida entera', 520.00, 60, 12, 2, 'La Serenísima', 'l', 1.0, '7790070000333', 'LECH-UHT-ENT', false, 'leche,uht,larga vida', 'https://via.placeholder.com/300x300/5f9ea0/ffffff?text=UHT'),

    -- Yogures
    ('Yogur Entero Sancor', 'Yogur entero natural', 280.00, 50, 10, 2, 'Sancor', 'g', 125, '7790070002111', 'YOGU-SANC-ENT', false, 'yogur,entero,natural', 'https://via.placeholder.com/300x300/fff8dc/ffffff?text=Yogur'),
    ('Yogur Ser Frutilla', 'Yogur con trozos de frutilla', 320.00, 45, 9, 2, 'Ser', 'g', 160, '7790070002222', 'YOGU-SER-FRUT', true, 'yogur,frutilla,ser', 'https://via.placeholder.com/300x300/ffb6c1/ffffff?text=Y.Frutilla'),
    ('Yogur Ser Vainilla', 'Yogur cremoso sabor vainilla', 320.00, 45, 9, 2, 'Ser', 'g', 160, '7790070002333', 'YOGU-SER-VAIN', false, 'yogur,vainilla,cremoso', 'https://via.placeholder.com/300x300/f0e68c/ffffff?text=Y.Vainilla'),
    ('Yogur Griego Natural', 'Yogur griego natural sin azúcar', 450.00, 30, 6, 2, 'Ilolay', 'g', 150, '7790070002444', 'YOGU-GRIEG-NAT', false, 'yogur,griego,natural', 'https://via.placeholder.com/300x300/f5f5dc/ffffff?text=Y.Griego'),

    -- Quesos
    ('Queso Cremoso Mendicrim', 'Queso cremoso para untar', 650.00, 40, 8, 2, 'Mendicrim', 'g', 200, '7790070003111', 'QUES-MEND-CREM', false, 'queso,cremoso,mendicrim', 'https://via.placeholder.com/300x300/fffacd/ffffff?text=Q.Cremoso'),
    ('Queso Port Salut', 'Queso Port Salut argentino', 850.00, 35, 7, 2, 'Mastellone', 'g', 200, '7790070003222', 'QUES-PORT-SAL', false, 'queso,port salut,mastellone', 'https://via.placeholder.com/300x300/ffd700/ffffff?text=P.Salut'),
    ('Queso Mozzarella', 'Queso mozzarella para pizza', 780.00, 45, 9, 2, 'La Paulina', 'g', 200, '7790070003333', 'QUES-MOZZ', true, 'queso,mozzarella,pizza', 'https://via.placeholder.com/300x300/f0f8ff/ffffff?text=Mozzarella'),
    ('Queso Rallado', 'Queso rallado sardo', 420.00, 50, 10, 2, 'Sancor', 'g', 80, '7790070003444', 'QUES-RALL', false, 'queso,rallado,sardo', 'https://via.placeholder.com/300x300/daa520/ffffff?text=Q.Rallado'),
    ('Queso Barra Sardo', 'Queso sardo en barra para rallar', 1200.00, 25, 5, 2, 'Mastellone', 'kg', 1.0, '7790070003555', 'QUES-SARD-BAR', false, 'queso,sardo,barra', 'https://via.placeholder.com/300x300/b8860b/ffffff?text=Sardo'),

    -- Manteca y Margarina
    ('Manteca La Serenísima', 'Manteca con sal', 480.00, 60, 12, 2, 'La Serenísima', 'g', 200, '7790070004111', 'MANT-SERE', false, 'manteca,sal,serenisima', 'https://via.placeholder.com/300x300/fffacd/ffffff?text=Manteca'),
    ('Margarina Danica', 'Margarina con sal', 380.00, 45, 9, 2, 'Danica', 'g', 200, '7790070004222', 'MARG-DANI', false, 'margarina,sal,danica', 'https://via.placeholder.com/300x300/fff8dc/ffffff?text=Margarina'),

    -- Huevos
    ('Huevos Blancos', 'Huevos blancos grandes', 650.00, 80, 16, 2, 'Granja', 'docena', 12, '7790070005111', 'HUEV-BLAN', true, 'huevos,blancos,grandes', 'https://via.placeholder.com/300x300/f5f5f5/000000?text=Huevos'),
    ('Huevos Rojos', 'Huevos rojos grandes', 680.00, 70, 14, 2, 'Granja', 'docena', 12, '7790070005222', 'HUEV-ROJO', false, 'huevos,rojos,grandes', 'https://via.placeholder.com/300x300/cd853f/ffffff?text=H.Rojos');

-- 🍞 PANADERÍA Y BOLLERÍA (Categoría 3)
INSERT INTO stock.products (name, description, price, stock_quantity, min_stock_alert, category_id, brand, weight_unit,
                            weight_value, barcode, sku, is_featured, meta_keywords, image_url)
VALUES
    -- Pan
    ('Pan Francés', 'Pan francés artesanal del día', 200.00, 50, 10, 3, 'Local', 'unidad', 1.0, '7790080001111', 'PAN-FRAN', true, 'pan,frances,artesanal', 'https://via.placeholder.com/300x300/deb887/ffffff?text=P.Francés'),
    ('Pan de Mesa', 'Pan de mesa redondo', 180.00, 40, 8, 3, 'Local', 'unidad', 1.0, '7790080001222', 'PAN-MESA', false, 'pan,mesa,redondo', 'https://via.placeholder.com/300x300/f4a460/ffffff?text=P.Mesa'),
    ('Pan Integral', 'Pan integral con semillas', 250.00, 30, 6, 3, 'Local', 'unidad', 1.0, '7790080001333', 'PAN-INTE', false, 'pan,integral,semillas', 'https://via.placeholder.com/300x300/8b4513/ffffff?text=P.Integral'),
    ('Pan Lactal Bimbo', 'Pan lactal grande', 420.00, 35, 7, 3, 'Bimbo', 'unidad', 1.0, '7790080001444', 'PAN-LACT-BIM', true, 'pan,lactal,bimbo', 'https://via.placeholder.com/300x300/ffe4b5/ffffff?text=P.Lactal'),
    ('Pan Lactal Fargo', 'Pan lactal blanco', 390.00, 40, 8, 3, 'Fargo', 'unidad', 1.0, '7790080001555', 'PAN-LACT-FAR', false, 'pan,lactal,fargo', 'https://via.placeholder.com/300x300/f5deb3/ffffff?text=Fargo'),

    -- Facturas y Bollería
    ('Facturas Surtidas', 'Facturas dulces variadas por docena', 600.00, 25, 5, 3, 'Local', 'docena', 12, '7790080002111', 'FACT-SURT', true, 'facturas,dulces,docena', 'https://via.placeholder.com/300x300/dda0dd/ffffff?text=Facturas'),
    ('Medialunas', 'Medialunas dulces por media docena', 350.00, 30, 6, 3, 'Local', '1/2 docena', 6, '7790080002222', 'MEDIA-DULC', true, 'medialunas,dulces', 'https://via.placeholder.com/300x300/f0e68c/ffffff?text=Medialunas'),
    ('Medialunas Saladas', 'Medialunas saladas por media docena', 320.00, 25, 5, 3, 'Local', '1/2 docena', 6, '7790080002333', 'MEDIA-SAL', false, 'medialunas,saladas', 'https://via.placeholder.com/300x300/f5deb3/ffffff?text=M.Saladas'),
    ('Churros', 'Churros rellenos con dulce de leche', 280.00, 20, 4, 3, 'Local', 'unidad', 1.0, '7790080002444', 'CHURR', false, 'churros,dulce leche', 'https://via.placeholder.com/300x300/d2691e/ffffff?text=Churros'),

    -- Galletitas y Bizcochos
    ('Galletitas Oreo', 'Galletitas Oreo originales', 520.00, 60, 12, 3, 'Oreo', 'g', 432, '7790080003111', 'GALL-OREO', true, 'galletitas,oreo,chocolate', 'https://via.placeholder.com/300x300/2f4f4f/ffffff?text=Oreo'),
    ('Galletitas Pepitos', 'Galletitas Pepitos con chips de chocolate', 480.00, 50, 10, 3, 'Pepitos', 'g', 300, '7790080003222', 'GALL-PEPI', false, 'galletitas,pepitos,chocolate', 'https://via.placeholder.com/300x300/8b4513/ffffff?text=Pepitos'),
    ('Galletitas Sonrisas', 'Galletitas Sonrisas Bagley', 450.00, 45, 9, 3, 'Bagley', 'g', 300, '7790080003333', 'GALL-SONR', false, 'galletitas,sonrisas,bagley', 'https://via.placeholder.com/300x300/ffd700/ffffff?text=Sonrisas'),
    ('Galletitas Criollitas', 'Galletitas Criollitas Bagley', 380.00, 55, 11, 3, 'Bagley', 'g', 250, '7790080003444', 'GALL-CRIO', false, 'galletitas,criollitas', 'https://via.placeholder.com/300x300/daa520/ffffff?text=Criollitas'),
    ('Bizcochos de Grasa', 'Bizcochos de grasa caseros', 320.00, 20, 4, 3, 'Local', '1/2 docena', 6, '7790080003555', 'BIZC-GRAS', false, 'bizcochos,grasa,caseros', 'https://via.placeholder.com/300x300/f4a460/ffffff?text=Bizcochos');

-- 🥩 CARNES Y POLLO (Categoría 4)
INSERT INTO stock.products (name, description, price, stock_quantity, min_stock_alert, category_id, brand, weight_unit,
                            weight_value, barcode, sku, is_featured, meta_keywords, image_url)
VALUES
    -- Carne Vacuna
    ('Asado', 'Asado de ternera argentino premium', 2800.00, 30, 6, 4, 'Frigorífico', 'kg', 1.0, '7790090001111', 'CARN-ASAD', true, 'asado,ternera,argentino', 'https://via.placeholder.com/300x300/8b0000/ffffff?text=Asado'),
    ('Vacío', 'Vacío de ternera para parrilla', 3200.00, 25, 5, 4, 'Frigorífico', 'kg', 1.0, '7790090001222', 'CARN-VACI', true, 'vacio,ternera,parrilla', 'https://via.placeholder.com/300x300/a0522d/ffffff?text=Vacío'),
    ('Bife de Chorizo', 'Bife de chorizo argentino tierno', 4500.00, 20, 4, 4, 'Frigorífico', 'kg', 1.0, '7790090001333', 'CARN-BIFE-CHOR', true, 'bife,chorizo,tierno', 'https://via.placeholder.com/300x300/cd5c5c/ffffff?text=B.Chorizo'),
    ('Entraña', 'Entraña argentina para parrilla', 3800.00, 18, 3, 4, 'Frigorífico', 'kg', 1.0, '7790090001444', 'CARN-ENTR', false, 'entraña,parrilla', 'https://via.placeholder.com/300x300/b22222/ffffff?text=Entraña'),
    ('Carne Molida Común', 'Carne molida común 80/20', 2200.00, 40, 8, 4, 'Frigorífico', 'kg', 1.0, '7790090001555', 'CARN-MOL-COM', true, 'carne,molida,comun', 'https://via.placeholder.com/300x300/dc143c/ffffff?text=C.Molida'),
    ('Carne Molida Especial', 'Carne molida especial 90/10', 2800.00, 30, 6, 4, 'Frigorífico', 'kg', 1.0, '7790090001666', 'CARN-MOL-ESP', false, 'carne,molida,especial', 'https://via.placeholder.com/300x300/ff0000/ffffff?text=C.Especial'),
    ('Matambre', 'Matambre de ternera para arrollar', 3500.00, 15, 3, 4, 'Frigorífico', 'kg', 1.0, '7790090001777', 'CARN-MATA', false, 'matambre,ternera,arrollar', 'https://via.placeholder.com/300x300/8b4513/ffffff?text=Matambre'),

    -- Pollo
    ('Pollo Entero', 'Pollo entero fresco argentino', 1800.00, 50, 10, 4, 'Granja Tres Arroyos', 'kg', 1.5, '7790090002111', 'POLL-ENT', true, 'pollo,entero,fresco', 'https://via.placeholder.com/300x300/ffd700/ffffff?text=P.Entero'),
    ('Pechuga de Pollo', 'Pechuga de pollo sin hueso', 2500.00, 35, 7, 4, 'Granja Tres Arroyos', 'kg', 1.0, '7790090002222', 'POLL-PECH', true, 'pechuga,pollo,sin hueso', 'https://via.placeholder.com/300x300/fff8dc/ffffff?text=Pechuga'),
    ('Muslo de Pollo', 'Muslo y encuentro de pollo', 1400.00, 40, 8, 4, 'Granja Tres Arroyos', 'kg', 1.0, '7790090002333', 'POLL-MUSL', false, 'muslo,pollo,encuentro', 'https://via.placeholder.com/300x300/daa520/ffffff?text=Muslo'),
    ('Alitas de Pollo', 'Alitas de pollo frescas', 1200.00, 30, 6, 4, 'Granja Tres Arroyos', 'kg', 1.0, '7790090002444', 'POLL-ALIT', false, 'alitas,pollo,frescas', 'https://via.placeholder.com/300x300/f0e68c/ffffff?text=Alitas'),

    -- Cerdo
    ('Bondiola de Cerdo', 'Bondiola de cerdo argentina', 2600.00, 20, 4, 4, 'Frigorífico', 'kg', 1.0, '7790090003111', 'CERD-BOND', false, 'bondiola,cerdo,argentina', 'https://via.placeholder.com/300x300/deb887/ffffff?text=Bondiola'),
    ('Costillas de Cerdo', 'Costillas de cerdo para parrilla', 2200.00, 25, 5, 4, 'Frigorífico', 'kg', 1.0, '7790090003222', 'CERD-COST', false, 'costillas,cerdo,parrilla', 'https://via.placeholder.com/300x300/cd853f/ffffff?text=Costillas'),

    -- Embutidos
    ('Chorizo Parrillero', 'Chorizo parrillero artesanal', 1800.00, 45, 9, 4, 'Embutidos Don Juan', 'kg', 1.0, '7790090004111', 'EMBU-CHOR-PAR', true, 'chorizo,parrillero,artesanal', 'https://via.placeholder.com/300x300/8b0000/ffffff?text=Chorizo'),
    ('Morcilla Dulce', 'Morcilla dulce argentina', 1500.00, 30, 6, 4, 'Embutidos Don Juan', 'kg', 1.0, '7790090004222', 'EMBU-MORC-DUL', false, 'morcilla,dulce,argentina', 'https://via.placeholder.com/300x300/2f4f4f/ffffff?text=Morcilla'),
    ('Salchicha Parrillera', 'Salchicha parrillera premium', 1600.00, 35, 7, 4, 'Embutidos Don Juan', 'kg', 1.0, '7790090004333', 'EMBU-SALC-PAR', false, 'salchicha,parrillera,premium', 'https://via.placeholder.com/300x300/cd5c5c/ffffff?text=Salchicha'),
    ('Jamón Cocido Paladini Feteado 150g', 'Jamón cocido Paladini calidad premium, feteado y envasado al vacío.', 1100.00, 70, 15, 4, 'Paladini', 'g', 150, '7790170005019', 'FIAM-PALA-JC-150', true, 'fiambre,jamon cocido,paladini,feteado', 'https://via.placeholder.com/300x300/F4A460/000000?text=Jamón+Paladini'),
    ('Salame Tandilero Cagnoli Picado Fino 200g', 'Salame picado fino estilo Tandil marca Cagnoli, pieza envasada.', 1700.00, 40, 8, 4, 'Cagnoli', 'g', 200, '7790170005020', 'FIAM-CAGN-SALPF-200', false, 'fiambre,salame,cagnoli,tandil,picado fino', 'https://via.placeholder.com/300x300/B22222/FFFFFF?text=Salame+Cagnoli'),
    ('Queso de Máquina Tybo Sancor Feteado 200g', 'Queso Tybo Sancor feteado, ideal para sándwiches.', 1350.00, 60, 12, 4, 'Sancor', 'g', 200, '7790170005031', 'FIAM-SANC-QTY-200', true, 'fiambre,queso,tybo,sancor,feteado', 'https://via.placeholder.com/300x300/FFD700/000000?text=Queso+Tybo+Sancor');

-- 🐟 PESCADOS Y MARISCOS (Categoría 5)
INSERT INTO stock.products (name, description, price, stock_quantity, min_stock_alert, category_id, brand, weight_unit,
                            weight_value, barcode, sku, is_featured, meta_keywords, image_url)
VALUES
    -- Pescados Frescos
    ('Merluza', 'Merluza fresca argentina', 2800.00, 25, 5, 5, 'Pesquera del Sur', 'kg', 1.0, '7790100001111', 'PESC-MERL', true, 'merluza,fresca,argentina', 'https://via.placeholder.com/300x300/4682b4/ffffff?text=Merluza'),
    ('Salmón', 'Salmón fresco importado', 4500.00, 15, 3, 5, 'Importado', 'kg', 1.0, '7790100001222', 'PESC-SALM', true, 'salmon,fresco,importado', 'https://via.placeholder.com/300x300/fa8072/ffffff?text=Salmón'),
    ('Corvina', 'Corvina fresca del Mar Argentino', 3200.00, 20, 4, 5, 'Pesquera del Sur', 'kg', 1.0, '7790100001333', 'PESC-CORV', false, 'corvina,fresca,mar argentino', 'https://via.placeholder.com/300x300/5f9ea0/ffffff?text=Corvina'),

    -- Pescados Congelados
    ('Filet de Merluza Congelado', 'Filet de merluza sin espinas', 2200.00, 40, 8, 5, 'Patagonia Foods', 'kg', 1.0, '7790100002111', 'PESC-FIL-MERL', false, 'filet,merluza,congelado', 'https://via.placeholder.com/300x300/b0e0e6/ffffff?text=F.Merluza'),
    ('Bastones de Merluza', 'Bastones de merluza rebozados', 1800.00, 30, 6, 5, 'Granja del Sol', 'kg', 1.0, '7790100002222', 'PESC-BAST-MERL', false, 'bastones,merluza,rebozados', 'https://via.placeholder.com/300x300/87ceeb/ffffff?text=Bastones'),

    -- Mariscos Congelados
    ('Camarones', 'Camarones medianos congelados', 3800.00, 20, 4, 5, 'Patagonia Mariscos', 'kg', 1.0, '7790100003111', 'MARI-CAMA', false, 'camarones,medianos,congelados', 'https://via.placeholder.com/300x300/ff69b4/ffffff?text=Camarones'),
    ('Langostinos', 'Langostinos grandes congelados', 5500.00, 15, 3, 5, 'Patagonia Mariscos', 'kg', 1.0, '7790100003222', 'MARI-LANG', true, 'langostinos,grandes,congelados', 'https://via.placeholder.com/300x300/ff1493/ffffff?text=Langostinos');

-- 🥤 BEBIDAS (Categoría 6)
INSERT INTO stock.products (name, description, price, stock_quantity, min_stock_alert, category_id, brand, weight_unit,
                            weight_value, barcode, sku, is_featured, meta_keywords, image_url)
VALUES
    -- Gaseosas
    ('Coca Cola 500ml', 'Coca Cola Original 500ml', 350.00, 200, 40, 6, 'Coca Cola', 'ml', 500, '7790110001111', 'BEB-COCA-500', true, 'coca cola,gaseosa,500ml', 'https://via.placeholder.com/300x300/dc143c/ffffff?text=Coca+500'),
    ('Coca Cola 1.5L', 'Coca Cola Original 1.5 litros', 650.00, 150, 30, 6, 'Coca Cola', 'l', 1.5, '7790110001222', 'BEB-COCA-1500', true, 'coca cola,gaseosa,1.5L', 'https://via.placeholder.com/300x300/dc143c/ffffff?text=Coca+1.5L'),
    ('Coca Cola 2.25L', 'Coca Cola Original 2.25 litros', 850.00, 100, 20, 6, 'Coca Cola', 'l', 2.25, '7790110001333', 'BEB-COCA-2250', false, 'coca cola,gaseosa,2.25L', 'https://via.placeholder.com/300x300/dc143c/ffffff?text=Coca+2.25L'),
    ('Pepsi 500ml', 'Pepsi Cola 500ml', 320.00, 180, 36, 6, 'Pepsi', 'ml', 500, '7790110001444', 'BEB-PEPS-500', false, 'pepsi,gaseosa,500ml', 'https://via.placeholder.com/300x300/0047ab/ffffff?text=Pepsi+500'),
    ('Sprite 500ml', 'Sprite Lima Limón 500ml', 340.00, 160, 32, 6, 'Sprite', 'ml', 500, '7790110001555', 'BEB-SPRI-500', false, 'sprite,lima limon,500ml', 'https://via.placeholder.com/300x300/00ff00/000000?text=Sprite'),
    ('Fanta 500ml', 'Fanta Naranja 500ml', 340.00, 160, 32, 6, 'Fanta', 'ml', 500, '7790110001666', 'BEB-FANT-500', false, 'fanta,naranja,500ml', 'https://via.placeholder.com/300x300/ffa500/ffffff?text=Fanta'),

    -- Aguas
    ('Villavicencio 500ml', 'Agua mineral Villavicencio 500ml', 280.00, 250, 50, 6, 'Villavicencio', 'ml', 500, '7790110002111', 'BEB-VILLA-500', true, 'agua,mineral,villavicencio', 'https://via.placeholder.com/300x300/87ceeb/ffffff?text=Villa+500'),
    ('Villavicencio 1.5L', 'Agua mineral Villavicencio 1.5L', 420.00, 200, 40, 6, 'Villavicencio', 'l', 1.5, '7790110002222', 'BEB-VILLA-1500', true, 'agua,mineral,1.5L', 'https://via.placeholder.com/300x300/87ceeb/ffffff?text=Villa+1.5L'),
    ('Eco de los Andes 500ml', 'Agua mineral Eco de los Andes', 320.00, 180, 36, 6, 'Eco de los Andes', 'ml', 500, '7790110002333', 'BEB-ECO-500', false, 'agua,mineral,eco andes', 'https://via.placeholder.com/300x300/add8e6/ffffff?text=Eco+500'),
    ('Glaciar 500ml', 'Agua mineral Glaciar 500ml', 300.00, 200, 40, 6, 'Glaciar', 'ml', 500, '7790110002444', 'BEB-GLAC-500', false, 'agua,mineral,glaciar', 'https://via.placeholder.com/300x300/b0e0e6/ffffff?text=Glaciar'),

    -- Jugos
    ('Cepita Naranja 1L', 'Jugo Cepita Naranja 1 litro', 520.00, 80, 16, 6, 'Cepita', 'l', 1.0, '7790110003111', 'BEB-CEPI-NAR', false, 'jugo,cepita,naranja', 'https://via.placeholder.com/300x300/ffa500/ffffff?text=Cepita+Nar'),
    ('Cepita Manzana 1L', 'Jugo Cepita Manzana 1 litro', 520.00, 70, 14, 6, 'Cepita', 'l', 1.0, '7790110003222', 'BEB-CEPI-MANZ', false, 'jugo,cepita,manzana', 'https://via.placeholder.com/300x300/ff6b6b/ffffff?text=Cepita+Manz'),
    ('Baggio Multifruta 1L', 'Jugo Baggio Multifruta', 480.00, 60, 12, 6, 'Baggio', 'l', 1.0, '7790110003333', 'BEB-BAGG-MULT', false, 'jugo,baggio,multifruta', 'https://via.placeholder.com/300x300/ff69b4/ffffff?text=Baggio'),

    -- Bebidas Energéticas
    ('Red Bull', 'Red Bull Energy Drink 250ml', 650.00, 100, 20, 6, 'Red Bull', 'ml', 250, '7790110004111', 'BEB-REDB-250', false, 'red bull,energetica,250ml', 'https://via.placeholder.com/300x300/4169e1/ffffff?text=Red+Bull'),
    ('Monster Energy', 'Monster Energy Original 473ml', 750.00, 80, 16, 6, 'Monster', 'ml', 473, '7790110004222', 'BEB-MONS-473', false, 'monster,energetica,473ml', 'https://via.placeholder.com/300x300/00ff00/000000?text=Monster'),

    -- Cervezas
    ('Quilmes 970ml', 'Cerveza Quilmes Clásica 970ml', 580.00, 120, 24, 6, 'Quilmes', 'ml', 970, '7790110005111', 'BEB-QUIL-970', true, 'cerveza,quilmes,970ml', 'https://via.placeholder.com/300x300/ffd700/000000?text=Quilmes'),
    ('Brahma 970ml', 'Cerveza Brahma 970ml', 550.00, 100, 20, 6, 'Brahma', 'ml', 970, '7790110005222', 'BEB-BRAH-970', false, 'cerveza,brahma,970ml', 'https://via.placeholder.com/300x300/dc143c/ffffff?text=Brahma'),
    ('Stella Artois 970ml', 'Cerveza Stella Artois 970ml', 650.00, 80, 16, 6, 'Stella Artois', 'ml', 970, '7790110005333', 'BEB-STELL-970', false, 'cerveza,stella artois,970ml', 'https://via.placeholder.com/300x300/daa520/ffffff?text=Stella'),

    -- Vinos
    ('Vino Alamos Malbec', 'Vino Alamos Malbec 750ml', 1200.00, 50, 10, 6, 'Alamos', 'ml', 750, '7790110006111', 'BEB-ALAM-MALB', false, 'vino,alamos,malbec', 'https://via.placeholder.com/300x300/800080/ffffff?text=Alamos'),
    ('Vino Santa Julia Cabernet', 'Vino Santa Julia Cabernet 750ml', 980.00, 45, 9, 6, 'Santa Julia', 'ml', 750, '7790110006222', 'BEB-SANT-CAB', false, 'vino,santa julia,cabernet', 'https://via.placeholder.com/300x300/8b0000/ffffff?text=S.Julia'),

    -- 🍹 Bebidas alcohólicas
    ('Fernet Branca 750ml', 'Clásico fernet italiano Branca, ideal para combinar con bebida cola.', 4800.00, 80, 16, 6, 'Branca', 'ml', 750, '7790170010014', 'BEBA-BRAN-FER-750', true, 'bebida,alcoholica,fernet,branca,aperitivo', 'https://via.placeholder.com/300x300/3A241D/FFFFFF?text=Fernet+Branca'),
    ('Aperitivo Campari 750ml', 'Aperitivo italiano Campari, color rojo intenso, base para cócteles.', 3900.00, 50, 10, 6, 'Campari', 'ml', 750, '7790170010025', 'BEBA-CAMP-APE-750', false, 'bebida,alcoholica,aperitivo,campari,coctel', 'https://via.placeholder.com/300x300/E50000/FFFFFF?text=Campari'),
    ('Aperitivo Gancia Americano 950ml', 'Aperitivo Gancia Americano, a base de vino blanco y hierbas.', 2500.00, 60, 12, 6, 'Gancia', 'ml', 950, '7790170010036', 'BEBA-GANC-AMER-950', true, 'bebida,alcoholica,aperitivo,gancia,americano', 'https://via.placeholder.com/300x300/FFFACD/000000?text=Gancia'),
    ('Fernet 1882 700ml', 'Fernet argentino 1882, sabor intenso y herbal.', 3500.00, 40, 8, 6, '1882', 'ml', 700, '7790170010047', 'BEBA-1882-FER-700', false, 'bebida,alcoholica,fernet,1882,argentino', 'https://via.placeholder.com/300x300/4A2A1F/FFFFFF?text=Fernet+1882');


-- 🍝 ALMACÉN Y DESPENSA (Categoría 7)
INSERT INTO stock.products (name, description, price, stock_quantity, min_stock_alert, category_id, brand, weight_unit,
                            weight_value, barcode, sku, is_featured, meta_keywords, image_url)
VALUES
    -- Arroces y Cereales
    ('Arroz Largo Fino Marolio', 'Arroz largo fino Doble Carolina', 450.00, 100, 20, 7, 'Marolio', 'kg', 1.0, '7790120001111', 'ALM-ARRO-MAR', true, 'arroz,largo fino,marolio', 'https://via.placeholder.com/300x300/f5deb3/ffffff?text=Arroz+M'),
    ('Arroz Gallo Oro', 'Arroz Gallo Oro Doble Carolina', 520.00, 80, 16, 7, 'Gallo', 'kg', 1.0, '7790120001222', 'ALM-ARRO-GAL', false, 'arroz,gallo oro,carolina', 'https://via.placeholder.com/300x300/ffd700/ffffff?text=Gallo'),
    ('Arroz Integral', 'Arroz integral Marolio', 580.00, 60, 12, 7, 'Marolio', 'kg', 1.0, '7790120001333', 'ALM-ARRO-INT', false, 'arroz,integral,marolio', 'https://via.placeholder.com/300x300/8b4513/ffffff?text=A.Integral'),

    -- Pastas
    ('Fideos Moñitos Matarazzo', 'Fideos moñitos 500g', 320.00, 120, 24, 7, 'Matarazzo', 'g', 500, '7790120002111', 'ALM-FID-MON-MAT', true, 'fideos,moñitos,matarazzo', 'https://via.placeholder.com/300x300/daa520/ffffff?text=Moñitos'),
    ('Fideos Tirabuzón Don Vicente', 'Fideos tirabuzón 500g', 350.00, 100, 20, 7, 'Don Vicente', 'g', 500, '7790120002222', 'ALM-FID-TIR-DON', false, 'fideos,tirabuzon,don vicente', 'https://via.placeholder.com/300x300/cd853f/ffffff?text=Tirabuzón'),
    ('Fideos Coditos Marolio', 'Fideos coditos 500g', 280.00, 150, 30, 7, 'Marolio', 'g', 500, '7790120002333', 'ALM-FID-COD-MAR', false, 'fideos,coditos,marolio', 'https://via.placeholder.com/300x300/f4a460/ffffff?text=Coditos'),
    ('Spaghetti Barilla', 'Spaghetti Barilla importado', 650.00, 60, 12, 7, 'Barilla', 'g', 500, '7790120002444', 'ALM-SPAG-BAR', false, 'spaghetti,barilla,importado', 'https://via.placeholder.com/300x300/228b22/ffffff?text=Barilla'),

    -- Legumbres
    ('Lentejas', 'Lentejas secas calidad premium', 380.00, 80, 16, 7, 'Marolio', 'kg', 1.0, '7790120003111', 'ALM-LENT', false, 'lentejas,secas,premium', 'https://via.placeholder.com/300x300/8b4513/ffffff?text=Lentejas'),
    ('Porotos Colorados', 'Porotos colorados secos', 420.00, 70, 14, 7, 'Marolio', 'kg', 1.0, '7790120003222', 'ALM-POR-COL', false, 'porotos,colorados,secos', 'https://via.placeholder.com/300x300/8b0000/ffffff?text=P.Colorados'),
    ('Garbanzos', 'Garbanzos secos seleccionados', 450.00, 60, 12, 7, 'Marolio', 'kg', 1.0, '7790120003333', 'ALM-GARB', false, 'garbanzos,secos,seleccionados', 'https://via.placeholder.com/300x300/deb887/ffffff?text=Garbanzos'),

    -- Harinas
    ('Harina 0000 Blancaflor', 'Harina 0000 para panificación', 420.00, 90, 18, 7, 'Blancaflor', 'kg', 1.0, '7790120004111', 'ALM-HAR-0000-BLA', true, 'harina,0000,blancaflor', 'https://via.placeholder.com/300x300/f5f5dc/ffffff?text=H.0000'),
    ('Harina Leudante Blancaflor', 'Harina leudante para repostería', 450.00, 80, 16, 7, 'Blancaflor', 'kg', 1.0, '7790120004222', 'ALM-HAR-LEU-BLA', false, 'harina,leudante,reposteria', 'https://via.placeholder.com/300x300/fffacd/ffffff?text=H.Leudante'),
    ('Harina Integral', 'Harina integral de trigo', 520.00, 50, 10, 7, 'Molinos Ala', 'kg', 1.0, '7790120004333', 'ALM-HAR-INT-ALA', false, 'harina,integral,trigo', 'https://via.placeholder.com/300x300/d2b48c/ffffff?text=H.Integral'),

    -- Azúcar y Endulzantes
    ('Azúcar Común Ledesma', 'Azúcar común cristal', 380.00, 120, 24, 7, 'Ledesma', 'kg', 1.0, '7790120005111', 'ALM-AZUC-LED', true, 'azucar,comun,ledesma', 'https://via.placeholder.com/300x300/f5f5f5/000000?text=Azúcar'),
    ('Azúcar Rubio Ledesma', 'Azúcar rubio natural', 420.00, 80, 16, 7, 'Ledesma', 'kg', 1.0, '7790120005222', 'ALM-AZUC-RUB-LED', false, 'azucar,rubio,natural', 'https://via.placeholder.com/300x300/daa520/ffffff?text=A.Rubio'),
    ('Edulcorante Hileret', 'Edulcorante líquido Hileret', 450.00, 60, 12, 7, 'Hileret', 'ml', 200, '7790120005333', 'ALM-EDUL-HIL', false, 'edulcorante,hileret,liquido', 'https://via.placeholder.com/300x300/87ceeb/ffffff?text=Hileret'),

    -- Conservas
    ('Tomate Triturado La Campagnola', 'Tomate triturado en lata 520g', 320.00, 150, 30, 7, 'La Campagnola', 'g', 520, '7790120006111', 'ALM-TOM-TRIT-CAM', true, 'tomate,triturado,campagnola', 'https://via.placeholder.com/300x300/dc143c/ffffff?text=T.Triturado'),
    ('Arvejas Arcor', 'Arvejas en lata 300g', 280.00, 100, 20, 7, 'Arcor', 'g', 300, '7790120006222', 'ALM-ARV-ARC', false, 'arvejas,arcor,lata', 'https://via.placeholder.com/300x300/90ee90/ffffff?text=Arvejas'),
    ('Choclo Arcor', 'Choclo en granos lata 300g', 290.00, 100, 20, 7, 'Arcor', 'g', 300, '7790120006333', 'ALM-CHOC-ARC', false, 'choclo,granos,arcor', 'https://via.placeholder.com/300x300/ffd700/ffffff?text=Choclo'),
    ('Atún Gomes da Costa', 'Atún en aceite 170g', 450.00, 80, 16, 7, 'Gomes da Costa', 'g', 170, '7790120006444', 'ALM-ATUN-GOM', false, 'atun,aceite,gomes', 'https://via.placeholder.com/300x300/4682b4/ffffff?text=Atún'),
    ('Sardinas La Campagnola', 'Sardinas en aceite 125g', 320.00, 70, 14, 7, 'La Campagnola', 'g', 125, '7790120006555', 'ALM-SARD-CAM', false, 'sardinas,aceite,campagnola', 'https://via.placeholder.com/300x300/5f9ea0/ffffff?text=Sardinas'),

    -- Yerba Mate
    ('Yerba Mate Playadito 500g', 'Yerba mate con palo, suave y duradera, ideal para mate tradicional.', 1250.00, 150, 30, 7, 'Playadito', 'g', 500, '7790170001011', 'YERB-PLAY-500', true, 'yerba,mate,playadito,infusion,argentina', 'https://via.placeholder.com/300x300/90EE90/000000?text=Playadito+500g'),
    ('Yerba Mate Taragüí Clásica 1kg', 'Yerba mate con palo Taragüí, sabor intenso y tradicional.', 2300.00, 100, 20, 7, 'Taragüí', 'kg', 1.0, '7790170001022', 'YERB-TARA-1KG', true, 'yerba,mate,taragui,clasica,infusion', 'https://via.placeholder.com/300x300/FF4500/FFFFFF?text=Taragüí+1kg'),
    ('Yerba Mate Rosamonte Especial 500g', 'Yerba mate Rosamonte selección especial, estacionamiento prolongado.', 1450.00, 80, 15, 7, 'Rosamonte', 'g', 500, '7790170001033', 'YERB-ROSA-ESP-500', false, 'yerba,mate,rosamonte,especial,infusion', 'https://via.placeholder.com/300x300/DC143C/FFFFFF?text=Rosamonte+500g'),
    ('Yerba Mate Cruz de Malta 500g', 'Yerba mate Cruz de Malta, sabor equilibrado y duradero.', 1200.00, 70, 15, 7, 'Cruz de Malta', 'g', 500, '7790170001044', 'YERB-CRUZM-500', false, 'yerba,mate,cruz de malta,infusion', 'https://via.placeholder.com/300x300/FFD700/000000?text=Cruz+de+Malta'),

    -- Café
    ('Café Molido La Virginia Clásico 250g', 'Café tostado y molido La Virginia, sabor clásico y aroma intenso.', 950.00, 90, 18, 7, 'La Virginia', 'g', 250, '7790170002018', 'CAFE-LAVIR-MOL-250', true, 'cafe,molido,la virginia,clasico', 'https://via.placeholder.com/300x300/654321/FFFFFF?text=Café+La+Virginia'),
    ('Café Instantáneo Nescafé Dolca Suave 170g', 'Café instantáneo Nescafé Dolca, variedad suave, frasco de vidrio.', 1800.00, 60, 12, 7, 'Nescafé', 'g', 170, '7790170002029', 'CAFE-NES-DOLSU-170', true, 'cafe,instantaneo,nescafe,dolca,suave', 'https://via.placeholder.com/300x300/D2B48C/000000?text=Nescafé+Dolca'),
    ('Café en Grano Cabrales Super Cabrales 500g', 'Café en grano tostado natural Super Cabrales, para moler.', 2500.00, 40, 8, 7, 'Cabrales', 'g', 500, '7790170002030', 'CAFE-CABR-GRA-500', false, 'cafe,grano,cabrales,tostado', 'https://via.placeholder.com/300x300/3E2723/FFFFFF?text=Cabrales+Grano'),

    -- Té
    ('Té Clásico La Virginia Saquitos x50', 'Té negro en saquitos La Virginia, presentación de 50 unidades.', 750.00, 120, 25, 7, 'La Virginia', 'unidad', 50, '7790170003015', 'TE-LAVIR-SAQ-50', true, 'te,negro,saquitos,la virginia', 'https://via.placeholder.com/300x300/B0720A/FFFFFF?text=Té+La+Virginia'),
    ('Té Verde Green Hills Saquitos x25', 'Té verde puro en saquitos Green Hills, antioxidante natural.', 850.00, 70, 14, 7, 'Green Hills', 'unidad', 25, '7790170003026', 'TE-GREENH-VER-25', false, 'te,verde,saquitos,green hills', 'https://via.placeholder.com/300x300/556B2F/FFFFFF?text=Té+Green+Hills'),

    -- 🍯 Dulce de leche
    ('Dulce de Leche La Serenísima Clásico 400g', 'Dulce de leche tradicional argentino La Serenísima, pote de cartón.', 980.00, 100, 20, 7, 'La Serenísima', 'g', 400, '7790170004012', 'DDL-LASER-CLA-400', true, 'dulce de leche,serenisima,clasico,argentino', 'https://via.placeholder.com/300x300/D2691E/FFFFFF?text=DDL+Serenísima'),
    ('Dulce de Leche Sancor Repostero 1kg', 'Dulce de leche Sancor especial para repostería, más consistente.', 1850.00, 60, 12, 7, 'Sancor', 'kg', 1.0, '7790170004023', 'DDL-SANC-REP-1KG', false, 'dulce de leche,sancor,repostero,pasteleria', 'https://via.placeholder.com/300x300/A0522D/FFFFFF?text=DDL+Sancor+Rep.'),
    ('Dulce de Leche Vacalin Clásico Vidrio 450g', 'Dulce de leche Vacalin, sabor artesanal, envase de vidrio.', 1300.00, 50, 10, 7, 'Vacalin', 'g', 450, '7790170004034', 'DDL-VACA-CLA-450', false, 'dulce de leche,vacalin,vidrio,artesanal', 'https://via.placeholder.com/300x300/CD853F/FFFFFF?text=DDL+Vacalin'),

    -- 🥨 Galletitas saladas
    ('Galletitas de Agua Express Clásicas Paquete 303g', 'Galletitas de agua Express, paquete triple, crocantes y livianas.', 720.00, 120, 24, 7, 'Express', 'g', 303, '7790170006016', 'GALLS-EXPR-AGU-303', true, 'galletitas,agua,express,saladas,clasicas', 'https://via.placeholder.com/300x300/F5DEB3/000000?text=Express+Agua'),
    ('Galletitas Traviata Clásicas Paquete 303g', 'Galletitas de agua Traviata, clásicas, paquete de 3 unidades internas.', 700.00, 110, 22, 7, 'Traviata', 'g', 303, '7790170006027', 'GALLS-TRAV-AGU-303', false, 'galletitas,agua,traviata,saladas', 'https://via.placeholder.com/300x300/FFEBCD/000000?text=Traviata'),
    ('Galletitas Cerealitas Salvado Paquete 200g', 'Galletitas con salvado Cerealitas, fuente de fibra.', 850.00, 80, 16, 7, 'Cerealitas', 'g', 200, '7790170006038', 'GALLS-CERE-SALV-200', false, 'galletitas,salvado,cerealitas,fibra', 'https://via.placeholder.com/300x300/DEB887/000000?text=Cerealitas');

-- 🫒 ACEITES Y CONDIMENTOS (Categoría 8)
INSERT INTO stock.products (name, description, price, stock_quantity, min_stock_alert, category_id, brand, weight_unit,
                            weight_value, barcode, sku, is_featured, meta_keywords, image_url)
VALUES
    -- Aceites
    ('Aceite Girasol Natura', 'Aceite de girasol refinado 1.5L', 680.00, 80, 16, 8, 'Natura', 'l', 1.5, '7790130001111', 'ACEI-GIR-NAT', true, 'aceite,girasol,natura', 'https://via.placeholder.com/300x300/ffd700/ffffff?text=Natura'),
    ('Aceite Maíz Mazola', 'Aceite de maíz Mazola 900ml', 750.00, 60, 12, 8, 'Mazola', 'ml', 900, '7790130001222', 'ACEI-MAIZ-MAZ', false, 'aceite,maiz,mazola', 'https://via.placeholder.com/300x300/ffb347/ffffff?text=Mazola'),
    ('Aceite Oliva Nucete', 'Aceite de oliva extra virgen', 1200.00, 40, 8, 8, 'Nucete', 'ml', 500, '7790130001333', 'ACEI-OLIV-NUC', false, 'aceite,oliva,nucete', 'https://via.placeholder.com/300x300/556b2f/ffffff?text=Oliva'),
    ('Aceite Mezcla Cocinero', 'Aceite mezcla girasol/soja', 620.00, 70, 14, 8, 'Cocinero', 'l', 1.5, '7790130001444', 'ACEI-MEZC-COC', false, 'aceite,mezcla,cocinero', 'https://via.placeholder.com/300x300/daa520/ffffff?text=Cocinero'),

    -- Vinagres
    ('Vinagre Menoyo', 'Vinagre de alcohol Menoyo', 280.00, 50, 10, 8, 'Menoyo', 'ml', 500, '7790130002111', 'VINAG-MEN', false, 'vinagre,alcohol,menoyo', 'https://via.placeholder.com/300x300/f5f5dc/ffffff?text=Vinagre'),
    ('Aceto Balsámico', 'Aceto balsámico importado', 850.00, 25, 5, 8, 'Gourmet', 'ml', 250, '7790130002222', 'ACETO-BALS', false, 'aceto,balsamico,importado', 'https://via.placeholder.com/300x300/8b4513/ffffff?text=Balsámico'),

    -- Condimentos y Especias
    ('Sal Fina Celusal', 'Sal fina de mesa', 180.00, 100, 20, 8, 'Celusal', 'kg', 1.0, '7790130003111', 'SAL-FIN-CEL', true, 'sal,fina,celusal', 'https://via.placeholder.com/300x300/f5f5f5/000000?text=Sal'),
    ('Sal Gruesa Celusal', 'Sal gruesa para parrilla', 200.00, 80, 16, 8, 'Celusal', 'kg', 1.0, '7790130003222', 'SAL-GRU-CEL', false, 'sal,gruesa,parrilla', 'https://via.placeholder.com/300x300/f0f8ff/000000?text=S.Gruesa'),
    ('Pimienta Negra Molida', 'Pimienta negra molida', 450.00, 60, 12, 8, 'Alicante', 'g', 25, '7790130003333', 'PIM-NEG-ALI', false, 'pimienta,negra,molida', 'https://via.placeholder.com/300x300/2f4f4f/ffffff?text=Pimienta'),
    ('Orégano Alicante', 'Orégano seco argentino', 320.00, 70, 14, 8, 'Alicante', 'g', 20, '7790130003444', 'OREG-ALI', false, 'oregano,seco,argentino', 'https://via.placeholder.com/300x300/9acd32/ffffff?text=Orégano'),
    ('Pimentón Dulce', 'Pimentón dulce español', 380.00, 50, 10, 8, 'Alicante', 'g', 25, '7790130003555', 'PIM-DULC-ALI', false, 'pimenton,dulce,español', 'https://via.placeholder.com/300x300/dc143c/ffffff?text=Pimentón'),
    ('Ajo en Polvo', 'Ajo deshidratado en polvo', 420.00, 45, 9, 8, 'Alicante', 'g', 30, '7790130003666', 'AJO-POLV-ALI', false, 'ajo,polvo,deshidratado', 'https://via.placeholder.com/300x300/fffacd/ffffff?text=A.Polvo'),

    -- Salsas
    ('Mayonesa Hellmanns', 'Mayonesa Hellmanns 500g', 650.00, 60, 12, 8, 'Hellmanns', 'g', 500, '7790130004111', 'MAYO-HELL', true, 'mayonesa,hellmanns,500g', 'https://via.placeholder.com/300x300/fffacd/ffffff?text=Hellmanns'),
    ('Ketchup Heinz', 'Ketchup Heinz 397g', 580.00, 50, 10, 8, 'Heinz', 'g', 397, '7790130004222', 'KETCH-HEINZ', false, 'ketchup,heinz,tomate', 'https://via.placeholder.com/300x300/dc143c/ffffff?text=Heinz'),
    ('Mostaza Savora', 'Mostaza Savora 250g', 420.00, 45, 9, 8, 'Savora', 'g', 250, '7790130004333', 'MOST-SAV', false, 'mostaza,savora,250g', 'https://via.placeholder.com/300x300/ffd700/ffffff?text=Savora'),
    ('Salsa Golf Hellmanns', 'Salsa golf Hellmanns', 680.00, 40, 8, 8, 'Hellmanns', 'g', 500, '7790130004444', 'SALSA-GOLF-HELL', false, 'salsa,golf,hellmanns', 'https://via.placeholder.com/300x300/ffb6c1/ffffff?text=S.Golf');

-- 🧽 LIMPIEZA DEL HOGAR (Categoría 9)
INSERT INTO stock.products (name, description, price, stock_quantity, min_stock_alert, category_id, brand, weight_unit,
                            weight_value, barcode, sku, is_featured, meta_keywords, image_url)
VALUES
    -- Limpieza General
    ('Lavandina Ayudín', 'Lavandina concentrada 1L', 320.00, 100, 20, 9, 'Ayudín', 'l', 1.0, '7790140001111', 'LIMP-LAV-AYU', true, 'lavandina,ayudin,concentrada', 'https://via.placeholder.com/300x300/87ceeb/ffffff?text=Ayudín'),
    ('Alcohol Etílico 96°', 'Alcohol etílico rectificado', 450.00, 80, 16, 9, 'Porta', 'l', 1.0, '7790140001222', 'LIMP-ALC-PORT', true, 'alcohol,etilico,porta', 'https://via.placeholder.com/300x300/e6e6fa/ffffff?text=Alcohol'),
    ('Limpiador Líquido CIF', 'Limpiador líquido multiuso', 480.00, 60, 12, 9, 'CIF', 'ml', 500, '7790140001333', 'LIMP-CIF-LIQ', false, 'limpiador,cif,multiuso', 'https://via.placeholder.com/300x300/4169e1/ffffff?text=CIF'),
    ('Desinfectante Lysoform', 'Desinfectante Lysoform pino', 520.00, 50, 10, 9, 'Lysoform', 'ml', 500, '7790140001444', 'LIMP-LYSO-PIN', false, 'desinfectante,lysoform,pino', 'https://via.placeholder.com/300x300/228b22/ffffff?text=Lysoform'),

    -- Detergentes
    ('Detergente Skip', 'Detergente líquido Skip 3L', 1200.00, 40, 8, 9, 'Skip', 'l', 3.0, '7790140002111', 'LIMP-DET-SKIP', true, 'detergente,skip,3L', 'https://via.placeholder.com/300x300/00bfff/ffffff?text=Skip+3L'),
    ('Detergente Ala', 'Detergente en polvo Ala 800g', 680.00, 60, 12, 9, 'Ala', 'g', 800, '7790140002222', 'LIMP-DET-ALA', false, 'detergente,ala,polvo', 'https://via.placeholder.com/300x300/ff69b4/ffffff?text=Ala'),
    ('Suavizante Vivere', 'Suavizante Vivere floral 2L', 850.00, 45, 9, 9, 'Vivere', 'l', 2.0, '7790140002333', 'LIMP-SUAV-VIV', false, 'suavizante,vivere,floral', 'https://via.placeholder.com/300x300/dda0dd/ffffff?text=Vivere'),

    -- Limpieza de Pisos
    ('Lysoform Pisos', 'Limpiador de pisos Lysoform', 620.00, 50, 10, 9, 'Lysoform', 'l', 1.8, '7790140003111', 'LIMP-LYSO-PIS', false, 'limpiador,pisos,lysoform', 'https://via.placeholder.com/300x300/32cd32/ffffff?text=L.Pisos'),
    ('Procenex Pisos', 'Limpiador desinfectante pisos', 580.00, 45, 9, 9, 'Procenex', 'l', 1.8, '7790140003222', 'LIMP-PROC-PIS', false, 'procenex,pisos,desinfectante', 'https://via.placeholder.com/300x300/4682b4/ffffff?text=Procenex'),

    -- Limpieza de Baño
    ('Pato Purific WC', 'Limpiador WC Pato Purific', 450.00, 40, 8, 9, 'Pato', 'ml', 500, '7790140004111', 'LIMP-PATO-WC', false, 'pato,purific,wc', 'https://via.placeholder.com/300x300/00ff7f/ffffff?text=Pato+WC'),
    ('Antigrasa Mr. Músculo', 'Desengrasante Mr. Músculo', 520.00, 35, 7, 9, 'Mr. Músculo', 'ml', 500, '7790140004222', 'LIMP-MR-MUSC', false, 'antigrasa,mr musculo', 'https://via.placeholder.com/300x300/ff6347/ffffff?text=Mr.Músculo'),

    -- Accesorios
    ('Esponjas Virulana', 'Esponjas de acero x 12', 280.00, 80, 16, 9, 'Virulana', 'unidad', 12, '7790140005111', 'LIMP-ESP-VIR', false, 'esponjas,virulana,acero', 'https://via.placeholder.com/300x300/c0c0c0/ffffff?text=Virulana'),
    ('Trapos de Piso', 'Trapos de piso x 3 unidades', 320.00, 60, 12, 9, 'Genérico', 'unidad', 3, '7790140005222', 'LIMP-TRAP-PIS', false, 'trapos,piso,3unidades', 'https://via.placeholder.com/300x300/8fbc8f/ffffff?text=Trapos'),
    ('Guantes de Látex', 'Guantes látex descartables x50', 850.00, 30, 6, 9, 'Marolio', 'unidad', 50, '7790140005333', 'LIMP-GUAN-LAT', false, 'guantes,latex,descartables', 'https://via.placeholder.com/300x300/ffffe0/ffffff?text=Guantes');

-- 🧴 HIGIENE PERSONAL (Categoría 10)
INSERT INTO stock.products (name, description, price, stock_quantity, min_stock_alert, category_id, brand, weight_unit,
                            weight_value, barcode, sku, is_featured, meta_keywords, image_url)
VALUES
    -- Champús
    ('Champú Pantene', 'Champú Pantene brillo extremo', 850.00, 50, 10, 10, 'Pantene', 'ml', 400, '7790150001111', 'HIG-CHAM-PANT', true, 'champu,pantene,brillo', 'https://via.placeholder.com/300x300/ffd700/ffffff?text=Pantene'),
    ('Champú Head & Shoulders', 'Champú anticaspa H&S', 920.00, 45, 9, 10, 'Head & Shoulders', 'ml', 375, '7790150001222', 'HIG-CHAM-HS', false, 'champu,head shoulders,anticaspa', 'https://via.placeholder.com/300x300/4169e1/ffffff?text=H%26S'),
    ('Champú Sedal', 'Champú Sedal hidratación', 780.00, 55, 11, 10, 'Sedal', 'ml', 340, '7790150001333', 'HIG-CHAM-SED', false, 'champu,sedal,hidratacion', 'https://via.placeholder.com/300x300/ff69b4/ffffff?text=Sedal'),

    -- Acondicionadores
    ('Acondicionador Pantene', 'Acondicionador Pantene', 820.00, 40, 8, 10, 'Pantene', 'ml', 400, '7790150002111', 'HIG-ACON-PANT', false, 'acondicionador,pantene', 'https://via.placeholder.com/300x300/daa520/ffffff?text=A.Pantene'),
    ('Acondicionador Sedal', 'Acondicionador Sedal', 750.00, 45, 9, 10, 'Sedal', 'ml', 340, '7790150002222', 'HIG-ACON-SED', false, 'acondicionador,sedal', 'https://via.placeholder.com/300x300/dda0dd/ffffff?text=A.Sedal'),

    -- Jabones
    ('Jabón Dove', 'Jabón Dove original x 3', 680.00, 80, 16, 10, 'Dove', 'g', 270, '7790150003111', 'HIG-JAB-DOVE', true, 'jabon,dove,original', 'https://via.placeholder.com/300x300/f0f8ff/ffffff?text=Dove'),
    ('Jabón Rexona', 'Jabón antibacterial Rexona', 520.00, 70, 14, 10, 'Rexona', 'g', 90, '7790150003222', 'HIG-JAB-REX', false, 'jabon,rexona,antibacterial', 'https://via.placeholder.com/300x300/00bfff/ffffff?text=Rexona'),
    ('Jabón Líquido Dove', 'Jabón líquido Dove para manos', 750.00, 50, 10, 10, 'Dove', 'ml', 250, '7790150003333', 'HIG-JAB-LIQ-DOVE', false, 'jabon,liquido,dove,manos', 'https://via.placeholder.com/300x300/e6e6fa/ffffff?text=J.Líquido'),

    -- Desodorantes
    ('Desodorante Rexona Men', 'Desodorante Rexona hombre', 650.00, 60, 12, 10, 'Rexona', 'ml', 90, '7790150004111', 'HIG-DEO-REX-MEN', false, 'desodorante,rexona,hombre', 'https://via.placeholder.com/300x300/2f4f4f/ffffff?text=R.Men'),
    ('Desodorante Dove Mujer', 'Desodorante Dove mujer', 680.00, 55, 11, 10, 'Dove', 'ml', 90, '7790150004222', 'HIG-DEO-DOVE-MUJ', false, 'desodorante,dove,mujer', 'https://via.placeholder.com/300x300/ffb6c1/ffffff?text=D.Mujer'),
    ('Antitranspirante Gillete', 'Antitranspirante Gillete', 720.00, 45, 9, 10, 'Gillette', 'ml', 82, '7790150004333', 'HIG-ANTI-GILL', false, 'antitranspirante,gillette', 'https://via.placeholder.com/300x300/0047ab/ffffff?text=Gillette'),

    -- Pasta Dental
    ('Pasta Dental Colgate', 'Pasta dental Colgate triple acción', 450.00, 80, 16, 10, 'Colgate', 'ml', 90, '7790150005111', 'HIG-PAST-COLG', true, 'pasta,dental,colgate', 'https://via.placeholder.com/300x300/dc143c/ffffff?text=Colgate'),
    ('Pasta Dental Sensodyne', 'Pasta dental Sensodyne', 850.00, 40, 8, 10, 'Sensodyne', 'ml', 90, '7790150005222', 'HIG-PAST-SENS', false, 'pasta,dental,sensodyne', 'https://via.placeholder.com/300x300/4169e1/ffffff?text=Sensodyne'),

    -- Cepillos de Dientes
    ('Cepillo Oral-B', 'Cepillo dental Oral-B medio', 320.00, 70, 14, 10, 'Oral-B', 'unidad', 1, '7790150006111', 'HIG-CEP-ORAL', false, 'cepillo,dental,oral-b', 'https://via.placeholder.com/300x300/00bfff/ffffff?text=Oral-B'),
    ('Cepillo Colgate', 'Cepillo dental Colgate suave', 280.00, 80, 16, 10, 'Colgate', 'unidad', 1, '7790150006222', 'HIG-CEP-COLG', false, 'cepillo,dental,colgate', 'https://via.placeholder.com/300x300/dc143c/ffffff?text=C.Colgate'),

    -- Papel Higiénico
    ('Papel Higiénico Elite', 'Papel higiénico Elite doble hoja x4', 580.00, 100, 20, 10, 'Elite', 'unidad', 4, '7790150007111', 'HIG-PAP-ELIT', true, 'papel,higienico,elite', 'https://via.placeholder.com/300x300/f0f8ff/ffffff?text=Elite'),
    ('Papel Higiénico Sussex', 'Papel higiénico Sussex x6', 750.00, 80, 16, 10, 'Sussex', 'unidad', 6, '7790150007222', 'HIG-PAP-SUSS', false, 'papel,higienico,sussex', 'https://via.placeholder.com/300x300/e6e6fa/ffffff?text=Sussex'),

    -- Toallas Femeninas
    ('Toallas Always', 'Toallas higiénicas Always x8', 680.00, 50, 10, 10, 'Always', 'unidad', 8, '7790150008111', 'HIG-TOAL-ALW', false, 'toallas,always,higienicas', 'https://via.placeholder.com/300x300/ff69b4/ffffff?text=Always'),
    ('Toallas Nosotras', 'Toallas higiénicas Nosotras x10', 720.00, 45, 9, 10, 'Nosotras', 'unidad', 10, '7790150008222', 'HIG-TOAL-NOS', false, 'toallas,nosotras,higienicas', 'https://via.placeholder.com/300x300/dda0dd/ffffff?text=Nosotras');

-- 🍪 SNACKS Y GOLOSINAS (Categoría 16)
INSERT INTO stock.products (name, description, price, stock_quantity, min_stock_alert, category_id, brand, weight_unit,
                            weight_value, barcode, sku, is_featured, meta_keywords, image_url)
VALUES
    -- Chocolates
    ('Chocolate Milka', 'Chocolate con leche Milka 100g', 650.00, 80, 16, 16, 'Milka', 'g', 100, '7790160001111', 'SNACK-CHOC-MILK', true, 'chocolate,milka,leche', 'https://via.placeholder.com/300x300/8a2be2/ffffff?text=Milka'),
    ('Chocolate Águila', 'Chocolate Águila semiamargo', 580.00, 70, 14, 16, 'Águila', 'g', 100, '7790160001222', 'SNACK-CHOC-AGU', false, 'chocolate,aguila,semiamargo', 'https://via.placeholder.com/300x300/8b4513/ffffff?text=Águila'),
    ('Chocolate Shot', 'Chocolate Shot con maní', 420.00, 90, 18, 16, 'Shot', 'g', 27, '7790160001333', 'SNACK-CHOC-SHOT', true, 'chocolate,shot,mani', 'https://via.placeholder.com/300x300/ff8c00/ffffff?text=Shot'),
    ('Bon o Bon', 'Bon o Bon alfajor de chocolate', 180.00, 150, 30, 16, 'Arcor', 'g', 30, '7790160001444', 'SNACK-BON-BON', true, 'bon o bon,alfajor,arcor', 'https://via.placeholder.com/300x300/ffd700/ffffff?text=BonoBon'),

    -- Alfajores
    ('Alfajor Havanna', 'Alfajor Havanna mixto', 350.00, 100, 20, 16, 'Havanna', 'g', 60, '7790160002111', 'SNACK-ALF-HAV', true, 'alfajor,havanna,mixto', 'https://via.placeholder.com/300x300/4169e1/ffffff?text=Havanna'),
    ('Alfajor Capitán del Espacio', 'Alfajor triple Capitán', 220.00, 120, 24, 16, 'Arcor', 'g', 55, '7790160002222', 'SNACK-ALF-CAP', false, 'alfajor,capitan,triple', 'https://via.placeholder.com/300x300/ff4500/ffffff?text=Capitán'),
    ('Alfajor Jorgito', 'Alfajor Jorgito negro', 190.00, 130, 26, 16, 'Jorgito', 'g', 50, '7790160002333', 'SNACK-ALF-JOR', false, 'alfajor,jorgito,negro', 'https://via.placeholder.com/300x300/2f4f4f/ffffff?text=Jorgito'),
    ('Alfajor Terrabusi', 'Alfajor Terrabusi blanco', 210.00, 110, 22, 16, 'Terrabusi', 'g', 52, '7790160002444', 'SNACK-ALF-TER', false, 'alfajor,terrabusi,blanco', 'https://via.placeholder.com/300x300/f5f5f5/000000?text=Terrabusi'),

    -- Galletitas Dulces
    ('Galletitas Oreo', 'Galletitas Oreo original 432g', 520.00, 60, 12, 16, 'Oreo', 'g', 432, '7790160003111', 'SNACK-GALL-OREO', true, 'galletitas,oreo,432g', 'https://via.placeholder.com/300x300/2f4f4f/ffffff?text=Oreo+432'),
    ('Galletitas Rumba', 'Galletitas Rumba miel', 380.00, 80, 16, 16, 'Bagley', 'g', 250, '7790160003222', 'SNACK-GALL-RUM', false, 'galletitas,rumba,miel', 'https://via.placeholder.com/300x300/daa520/ffffff?text=Rumba'),
    ('Galletitas Chocolinas', 'Galletitas Chocolinas', 420.00, 70, 14, 16, 'Bagley', 'g', 170, '7790160003333', 'SNACK-GALL-CHOC', false, 'galletitas,chocolinas', 'https://via.placeholder.com/300x300/8b4513/ffffff?text=Chocolinas'),

    -- Papas y Snacks Salados
    ('Papas Lays', 'Papas fritas Lays clásicas', 450.00, 100, 20, 16, 'Lays', 'g', 150, '7790160004111', 'SNACK-PAP-LAYS', true, 'papas,lays,clasicas', 'https://via.placeholder.com/300x300/ffd700/ffffff?text=Lays'),
    ('Papas Pringles', 'Papas Pringles original', 850.00, 50, 10, 16, 'Pringles', 'g', 124, '7790160004222', 'SNACK-PAP-PRIN', false, 'papas,pringles,original', 'https://via.placeholder.com/300x300/dc143c/ffffff?text=Pringles'),
    ('Palitos Pehuamar', 'Palitos salados Pehuamar', 320.00, 90, 18, 16, 'Pehuamar', 'g', 100, '7790160004333', 'SNACK-PAL-PEH', false, 'palitos,pehuamar,salados', 'https://via.placeholder.com/300x300/f4a460/ffffff?text=Pehuamar'),
    ('Cheetos', 'Cheetos queso', 380.00, 80, 16, 16, 'Cheetos', 'g', 75, '7790160004444', 'SNACK-CHEET', false, 'cheetos,queso,75g', 'https://via.placeholder.com/300x300/ffa500/ffffff?text=Cheetos'),

    -- Caramelos y Golosinas
    ('Caramelos Sugus', 'Caramelos Sugus surtidos', 280.00, 120, 24, 16, 'Sugus', 'g', 150, '7790160005111', 'SNACK-CAR-SUG', false, 'caramelos,sugus,surtidos', 'https://via.placeholder.com/300x300/ff69b4/ffffff?text=Sugus'),
    ('Chicles Beldent', 'Chicles Beldent menta', 150.00, 200, 40, 16, 'Beldent', 'g', 20, '7790160005222', 'SNACK-CHIC-BEL', false, 'chicles,beldent,menta', 'https://via.placeholder.com/300x300/00ff7f/ffffff?text=Beldent'),
    ('Pastillas Halls', 'Pastillas Halls menta', 220.00, 150, 30, 16, 'Halls', 'g', 28, '7790160005333', 'SNACK-PAST-HAL', false, 'pastillas,halls,menta', 'https://via.placeholder.com/300x300/00ffff/ffffff?text=Halls'),
    ('Gomitas Mogul', 'Gomitas Mogul surtidas', 320.00, 100, 20, 16, 'Mogul', 'g', 100, '7790160005444', 'SNACK-GOM-MOG', false, 'gomitas,mogul,surtidas', 'https://via.placeholder.com/300x300/ff1493/ffffff?text=Mogul');

-- 🧊 PRODUCTOS CONGELADOS (Categoría 14)
INSERT INTO stock.products (name, description, price, stock_quantity, min_stock_alert, category_id, brand, weight_unit,
                            weight_value, barcode, sku, is_featured, meta_keywords, image_url)
VALUES
    -- Helados
    ('Helado Frigor Dulce de Leche', 'Helado Frigor 1kg dulce de leche', 1200.00, 40, 8, 14, 'Frigor', 'kg', 1.0, '7790140001111', 'CONG-HEL-FRIG-DDL', true, 'helado,frigor,dulce de leche', 'https://via.placeholder.com/300x300/ffdab9/000000?text=Frigor+D.L.'),
    ('Helado Crem Helado Vainilla', 'Helado Crem Helado 1L vainilla', 850.00, 60, 12, 14, 'Crem Helado', 'l', 1.0, '7790140001222', 'CONG-HEL-CREM-VAN', false, 'helado,crem helado,vainilla', 'https://via.placeholder.com/300x300/f0e68c/000000?text=Crem+Vainilla'),
    ('Helado Arcor Chocolate', 'Helado Arcor 1L chocolate', 950.00, 50, 10, 14, 'Arcor', 'l', 1.0, '7790140001333', 'CONG-HEL-ARC-CHO', false, 'helado,arcor,chocolate', 'https://via.placeholder.com/300x300/8b4513/ffffff?text=Arcor+Chocolate'),

    -- Comidas Preparadas
    ('Pizza Congelada Muzzarella Lucchetti 500g', 'Pizza de muzzarella congelada Lucchetti, lista para hornear.', 1500.00, 50, 10, 14, 'Lucchetti', 'g', 500, '7790170007013', 'CONG-LUCC-PIZZM-500', true, 'congelados,pizza,muzzarella,lucchetti', 'https://via.placeholder.com/300x300/FF6347/FFFFFF?text=Pizza+Lucchetti'),
    ('Empanadas Congeladas Carne La Salteña x12', 'Empanadas de carne congeladas La Salteña, listas para cocinar, 12 unidades.', 2200.00, 40, 8, 14, 'La Salteña', 'unidad', 12, '7790170007024', 'CONG-SALT-EMPCAR-12', true, 'congelados,empanadas,carne,la salteña', 'https://via.placeholder.com/300x300/D2B48C/000000?text=Empanadas+Salteña'),
    ('Milanesas de Soja Lucchetti Clásicas 290g', 'Milanesas de soja congeladas Lucchetti, paquete de 4 unidades.', 1100.00, 60, 12, 14, 'Lucchetti', 'g', 290, '7790170007035', 'CONG-LUCC-MILSOJ-290', false, 'congelados,milanesa,soja,lucchetti', 'https://via.placeholder.com/300x300/9ACD32/000000?text=Milanesa+Soja+Lucchetti'),
    ('Papas Fritas Congeladas McCain Tradicionales 720g', 'Papas fritas corte tradicional McCain, listas para freír u hornear.', 1300.00, 70, 14, 14, 'McCain', 'g', 720, '7790170007046', 'CONG-MCCA-PAPFR-720', true, 'congelados,papas fritas,mccain,tradicional', 'https://via.placeholder.com/300x300/FFD700/000000?text=Papas+McCain'),

    -- Verduras Congeladas
    ('Espinaca Congelada Green Life 500g', 'Espinaca en hojas congelada Green Life, práctica y nutritiva.', 950.00, 50, 10, 14, 'Green Life', 'g', 500, '7790170008010', 'CONG-GRLF-ESP-500', false, 'congelados,espinaca,verdura,green life', 'https://via.placeholder.com/300x300/228B22/FFFFFF?text=Espinaca+G.Life'),
    ('Brócoli Congelado Quickfood 400g', 'Brócoli en flores congelado Quickfood, listo para usar.', 880.00, 45, 9, 14, 'Quickfood', 'g', 400, '7790170008021', 'CONG-QUIK-BROC-400', false, 'congelados,brocoli,verdura,quickfood', 'https://via.placeholder.com/300x300/32CD32/FFFFFF?text=Brócoli+Quickfood');

- 🌱 PRODUCTOS DE DIETÉTICA / SALUDABLES (Categoría 15: Dietética y Naturales)
INSERT INTO stock.products (name, description, price, stock_quantity, min_stock_alert, category_id, brand, weight_unit,
                            weight_value, barcode, sku, is_featured, meta_keywords, image_url)
VALUES
    ('Semillas de Chía Yin Yang 200g', 'Semillas de chía naturales, fuente de omega 3 y fibra.', 750.00, 60, 12, 15, 'Yin Yang', 'g', 200, '7790170009017', 'DIET-YINY-CHIA-200', false, 'dietetica,semillas,chia,yin yang,saludable', 'https://via.placeholder.com/300x300/A9A9A9/000000?text=Chía+Yin+Yang'),
    ('Almendras Peladas New Garden 100g', 'Almendras peladas naturales New Garden, snack saludable.', 1200.00, 40, 8, 15, 'New Garden', 'g', 100, '7790170009028', 'DIET-NEWG-ALM-100', true, 'dietetica,almendras,frutos secos,new garden', 'https://via.placeholder.com/300x300/FFE4B5/000000?text=Almendras+NewGarden'),
    ('Barritas de Cereal Arcor Cereal Mix Frutilla x6', 'Barritas de cereal Arcor Cereal Mix sabor frutilla, caja con 6 unidades.', 980.00, 70, 14, 15, 'Arcor Cereal Mix', 'unidad', 6, '7790170009039', 'DIET-ARCM-BARRF-6', true, 'dietetica,barritas,cereal,arcor,frutilla', 'https://via.placeholder.com/300x300/FFB6C1/000000?text=Barritas+Arcor'),
    ('Leche de Almendras Ades Original 1L', 'Bebida a base de almendras Ades, sin lactosa, fortificada.', 1150.00, 50, 10, 15, 'Ades', 'l', 1.0, '7790170009040', 'DIET-ADES-LECALM-1L', false, 'dietetica,leche almendras,ades,vegetal,sin lactosa', 'https://via.placeholder.com/300x300/FFF8DC/000000?text=Ades+Almendras'),
    ('Miel Pura de Abejas Aleluya 500g', 'Miel pura de abejas multifloral marca Aleluya, envase dosificador.', 1400.00, 45, 9, 15, 'Aleluya', 'g', 500, '7790170009051', 'DIET-ALEL-MIEL-500', false, 'dietetica,miel,pura,aleluya,natural', 'https://via.placeholder.com/300x300/FFBF00/000000?text=Miel+Aleluya');


