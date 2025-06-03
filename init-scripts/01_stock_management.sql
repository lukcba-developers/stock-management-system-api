-- ============================================================================
-- 📦 STOCK MANAGEMENT SCHEMA - SISTEMA DE GESTIÓN DE INVENTARIO
-- ============================================================================
-- Archivo: init-scripts/01_stock_management.sql
-- Propósito: Tablas específicas para el sistema de gestión de stock
-- Dependencias: 00_core_schema.sql
-- Orden de ejecución: SEGUNDO (01_)
-- ============================================================================

-- 🏷️ CATEGORÍAS DE PRODUCTOS
CREATE TABLE IF NOT EXISTS stock.categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    icon_emoji VARCHAR(10),
    parent_id INTEGER REFERENCES stock.categories(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    seo_slug VARCHAR(120) UNIQUE,
    meta_title VARCHAR(120),
    meta_description VARCHAR(160),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en categories
CREATE TRIGGER update_categories_updated_at
    BEFORE UPDATE ON stock.categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 📦 PRODUCTOS PRINCIPALES
CREATE TABLE IF NOT EXISTS stock.products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    short_description VARCHAR(500),
    price DECIMAL(12,2) NOT NULL CHECK (price >= 0),
    original_price DECIMAL(12,2),
    cost_price DECIMAL(12,2),
    stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    min_stock_alert INTEGER DEFAULT 5 CHECK (min_stock_alert >= 0),
    max_stock_limit INTEGER,
    category_id INTEGER REFERENCES stock.categories(id) ON DELETE SET NULL,
    
    -- Información del producto
    image_url VARCHAR(500),
    gallery_images JSONB DEFAULT '[]',
    barcode VARCHAR(100) UNIQUE,
    sku VARCHAR(100) UNIQUE,
    brand VARCHAR(100),
    
    -- Medidas y peso
    weight_unit VARCHAR(20) DEFAULT 'unidad' CHECK (weight_unit IN ('kg', 'g', 'l', 'ml', 'unidad', 'pza')),
    weight_value DECIMAL(8,3),
    dimensions JSONB, -- {width, height, depth, unit}
    
    -- Estados y configuración
    is_featured BOOLEAN DEFAULT false,
    is_available BOOLEAN DEFAULT true,
    is_digital BOOLEAN DEFAULT false,
    requires_shipping BOOLEAN DEFAULT true,
    
    -- Marketing y SEO
    popularity_score INTEGER DEFAULT 0,
    discount_percentage INTEGER DEFAULT 0 CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
    meta_keywords TEXT,
    meta_title VARCHAR(120),
    meta_description VARCHAR(160),
    seo_slug VARCHAR(150) UNIQUE,
    
    -- Búsqueda
    search_vector TSVECTOR,
    search_keywords JSONB DEFAULT '[]',
    
    -- Auditoría
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Constraints adicionales
    CONSTRAINT valid_prices CHECK (
        (original_price IS NULL OR original_price >= price) AND
        (cost_price IS NULL OR cost_price <= price)
    )
);

-- Trigger para updated_at en products
CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON stock.products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Función para actualizar search_vector automáticamente
CREATE OR REPLACE FUNCTION update_products_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector = to_tsvector('spanish_unaccent', 
        COALESCE(NEW.name, '') || ' ' || 
        COALESCE(NEW.description, '') || ' ' || 
        COALESCE(NEW.brand, '') || ' ' || 
        COALESCE(NEW.meta_keywords, '') || ' ' ||
        COALESCE(array_to_string(ARRAY(SELECT jsonb_array_elements_text(NEW.search_keywords)), ' '), '')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_products_search_vector
    BEFORE INSERT OR UPDATE ON stock.products
    FOR EACH ROW EXECUTE FUNCTION update_products_search_vector();

-- 👥 USUARIOS ADMINISTRATIVOS
CREATE TABLE IF NOT EXISTS stock.admin_users (
    id SERIAL PRIMARY KEY,
    google_id VARCHAR(255) UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    picture VARCHAR(500),
    role user_role_enum DEFAULT 'viewer',
    is_active BOOLEAN DEFAULT true,
    password_hash VARCHAR(255), -- Para login tradicional si es necesario
    
    -- Configuraciones del usuario
    preferences JSONB DEFAULT '{}',
    notifications_enabled BOOLEAN DEFAULT true,
    dashboard_config JSONB DEFAULT '{}',
    
    -- Auditoría
    last_login TIMESTAMP,
    login_count INTEGER DEFAULT 0,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en admin_users
CREATE TRIGGER update_admin_users_updated_at
    BEFORE UPDATE ON stock.admin_users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 📊 MOVIMIENTOS DE STOCK
CREATE TABLE IF NOT EXISTS stock.stock_movements (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES stock.products(id) ON DELETE CASCADE,
    movement_type movement_type_enum NOT NULL,
    quantity_change INTEGER NOT NULL CHECK (quantity_change != 0),
    quantity_before INTEGER NOT NULL CHECK (quantity_before >= 0),
    quantity_after INTEGER NOT NULL CHECK (quantity_after >= 0),
    
    -- Información del movimiento
    reason TEXT,
    reference_type VARCHAR(50), -- 'order', 'adjustment', 'transfer', 'initial_stock', 'restock'
    reference_id INTEGER,
    batch_number VARCHAR(100),
    
    -- Costos (para movimientos de entrada)
    cost_per_unit DECIMAL(12,2),
    total_cost DECIMAL(12,2),
    
    -- Información del proveedor (para entradas)
    supplier_info JSONB,
    
    -- Auditoría
    user_id INTEGER REFERENCES stock.admin_users(id) ON DELETE SET NULL,
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

-- 🏪 PROVEEDORES
CREATE TABLE IF NOT EXISTS stock.suppliers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    contact_person VARCHAR(255),
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(50),
    
    -- Dirección
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100) DEFAULT 'Argentina',
    postal_code VARCHAR(20),
    
    -- Información comercial
    tax_id VARCHAR(50), -- CUIT/CUIL
    payment_terms VARCHAR(100), -- '30 días', 'Contado', etc
    delivery_days VARCHAR(100), -- 'Lunes y Jueves', etc
    minimum_order_amount DECIMAL(12,2),
    currency VARCHAR(3) DEFAULT 'ARS',
    
    -- Estado y calificación
    is_active BOOLEAN DEFAULT true,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    notes TEXT,
    
    -- Contacto y horarios
    website VARCHAR(255),
    business_hours JSONB,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en suppliers
CREATE TRIGGER update_suppliers_updated_at
    BEFORE UPDATE ON stock.suppliers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 🔗 RELACIÓN PRODUCTOS-PROVEEDORES
CREATE TABLE IF NOT EXISTS stock.product_suppliers (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES stock.products(id) ON DELETE CASCADE,
    supplier_id INTEGER NOT NULL REFERENCES stock.suppliers(id) ON DELETE CASCADE,
    
    -- Información comercial
    supplier_sku VARCHAR(100), -- Código del producto según el proveedor
    cost_price DECIMAL(12,2),
    currency VARCHAR(3) DEFAULT 'ARS',
    
    -- Logística
    lead_time_days INTEGER,
    minimum_order_quantity INTEGER DEFAULT 1,
    package_size INTEGER DEFAULT 1,
    
    -- Configuración
    is_primary BOOLEAN DEFAULT false,
    is_preferred BOOLEAN DEFAULT false,
    
    -- Historia
    last_purchase_date DATE,
    last_purchase_price DECIMAL(12,2),
    total_purchases INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(product_id, supplier_id)
);

-- Trigger para updated_at en product_suppliers
CREATE TRIGGER update_product_suppliers_updated_at
    BEFORE UPDATE ON stock.product_suppliers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 📋 ÓRDENES DE COMPRA
CREATE TABLE IF NOT EXISTS stock.purchase_orders (
    id SERIAL PRIMARY KEY,
    order_number VARCHAR(50) UNIQUE NOT NULL DEFAULT generate_order_number('PO'),
    supplier_id INTEGER NOT NULL REFERENCES stock.suppliers(id) ON DELETE RESTRICT,
    
    -- Estados
    status VARCHAR(50) DEFAULT 'draft' CHECK (status IN ('draft', 'sent', 'confirmed', 'partially_received', 'received', 'cancelled')),
    priority VARCHAR(20) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    
    -- Fechas
    order_date DATE DEFAULT CURRENT_DATE,
    expected_delivery_date DATE,
    actual_delivery_date DATE,
    
    -- Montos
    subtotal DECIMAL(12,2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(12,2) DEFAULT 0,
    shipping_cost DECIMAL(12,2) DEFAULT 0,
    discount_amount DECIMAL(12,2) DEFAULT 0,
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    
    -- Pago
    payment_status VARCHAR(50) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'partial', 'paid', 'overdue')),
    payment_method VARCHAR(50),
    payment_terms VARCHAR(100),
    
    -- Referencias
    invoice_number VARCHAR(100),
    supplier_reference VARCHAR(100),
    
    -- Información adicional
    notes TEXT,
    terms_and_conditions TEXT,
    delivery_address TEXT,
    
    -- Auditoría
    created_by INTEGER REFERENCES stock.admin_users(id) ON DELETE SET NULL,
    approved_by INTEGER REFERENCES stock.admin_users(id) ON DELETE SET NULL,
    received_by INTEGER REFERENCES stock.admin_users(id) ON DELETE SET NULL,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en purchase_orders
CREATE TRIGGER update_purchase_orders_updated_at
    BEFORE UPDATE ON stock.purchase_orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 📝 ITEMS DE ÓRDENES DE COMPRA
CREATE TABLE IF NOT EXISTS stock.purchase_order_items (
    id SERIAL PRIMARY KEY,
    purchase_order_id INTEGER NOT NULL REFERENCES stock.purchase_orders(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES stock.products(id) ON DELETE SET NULL,
    
    -- Snapshot del producto
    product_name_snapshot VARCHAR(255) NOT NULL,
    product_sku_snapshot VARCHAR(100),
    supplier_sku VARCHAR(100),
    
    -- Cantidades
    quantity_ordered INTEGER NOT NULL CHECK (quantity_ordered > 0),
    quantity_received INTEGER DEFAULT 0 CHECK (quantity_received >= 0),
    quantity_accepted INTEGER DEFAULT 0 CHECK (quantity_accepted >= 0),
    quantity_rejected INTEGER DEFAULT 0 CHECK (quantity_rejected >= 0),
    
    -- Precios
    unit_cost DECIMAL(12,2) NOT NULL CHECK (unit_cost >= 0),
    total_cost DECIMAL(12,2) GENERATED ALWAYS AS (quantity_ordered * unit_cost) STORED,
    
    -- Impuestos y descuentos
    tax_rate DECIMAL(5,2) DEFAULT 0,
    discount_percentage DECIMAL(5,2) DEFAULT 0,
    
    -- Estado del item
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'received', 'partial', 'cancelled')),
    
    -- Información adicional
    notes TEXT,
    defects_notes TEXT,
    
    CONSTRAINT valid_quantities CHECK (
        quantity_received = quantity_accepted + quantity_rejected AND
        quantity_received <= quantity_ordered
    )
);

-- 📦 INVENTARIO POR LOTES (para productos con fecha de vencimiento)
CREATE TABLE IF NOT EXISTS stock.inventory_batches (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES stock.products(id) ON DELETE CASCADE,
    batch_number VARCHAR(100) NOT NULL,
    
    -- Cantidades
    quantity_initial INTEGER NOT NULL CHECK (quantity_initial > 0),
    quantity_remaining INTEGER NOT NULL CHECK (quantity_remaining >= 0),
    quantity_reserved INTEGER DEFAULT 0 CHECK (quantity_reserved >= 0),
    
    -- Fechas importantes
    production_date DATE,
    expiration_date DATE,
    received_date DATE DEFAULT CURRENT_DATE,
    
    -- Costos
    cost_per_unit DECIMAL(12,2),
    currency VARCHAR(3) DEFAULT 'ARS',
    
    -- Referencias
    supplier_id INTEGER REFERENCES stock.suppliers(id) ON DELETE SET NULL,
    purchase_order_item_id INTEGER REFERENCES stock.purchase_order_items(id) ON DELETE SET NULL,
    
    -- Ubicación y estado
    location VARCHAR(100), -- Ubicación en el almacén
    warehouse_section VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    
    -- Calidad y condición
    quality_grade VARCHAR(20) DEFAULT 'A' CHECK (quality_grade IN ('A', 'B', 'C', 'Rejected')),
    condition_notes TEXT,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(batch_number, product_id),
    
    CONSTRAINT valid_batch_quantities CHECK (
        quantity_remaining <= quantity_initial AND
        quantity_reserved <= quantity_remaining
    ),
    CONSTRAINT valid_dates CHECK (
        expiration_date IS NULL OR expiration_date >= production_date
    )
);

-- Trigger para updated_at en inventory_batches
CREATE TRIGGER update_inventory_batches_updated_at
    BEFORE UPDATE ON stock.inventory_batches
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 🚨 ALERTAS DE STOCK
CREATE TABLE IF NOT EXISTS stock.stock_alerts (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES stock.products(id) ON DELETE CASCADE,
    alert_type VARCHAR(50) NOT NULL CHECK (alert_type IN ('low_stock', 'out_of_stock', 'expiring_soon', 'expired', 'overstock')),
    alert_level VARCHAR(20) NOT NULL CHECK (alert_level IN ('info', 'warning', 'critical')),
    
    -- Datos del stock
    current_quantity INTEGER NOT NULL,
    threshold_quantity INTEGER,
    expiration_date DATE, -- Para alertas de vencimiento
    
    -- Estado de la alerta
    is_acknowledged BOOLEAN DEFAULT false,
    acknowledged_by INTEGER REFERENCES stock.admin_users(id) ON DELETE SET NULL,
    acknowledged_at TIMESTAMP,
    
    -- Notificaciones
    notification_sent_at TIMESTAMP,
    notification_channels JSONB DEFAULT '[]', -- ['email', 'sms', 'webhook']
    
    -- Resolución
    is_resolved BOOLEAN DEFAULT false,
    resolved_at TIMESTAMP,
    resolved_by INTEGER REFERENCES stock.admin_users(id) ON DELETE SET NULL,
    resolution_notes TEXT,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en stock_alerts
CREATE TRIGGER update_stock_alerts_updated_at
    BEFORE UPDATE ON stock.stock_alerts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ⚙️ CONFIGURACIÓN DE AJUSTES DE INVENTARIO
CREATE TABLE IF NOT EXISTS stock.inventory_adjustments (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES stock.products(id) ON DELETE SET NULL,
    adjustment_type VARCHAR(50) NOT NULL CHECK (adjustment_type IN ('restock', 'damage', 'theft', 'correction', 'expired', 'returned', 'found')),
    
    -- Cantidades
    quantity_change INTEGER NOT NULL,
    quantity_before INTEGER NOT NULL,
    quantity_after INTEGER NOT NULL,
    
    -- Información financiera
    cost_impact DECIMAL(12,2),
    currency VARCHAR(3) DEFAULT 'ARS',
    
    -- Detalles del ajuste
    reason TEXT NOT NULL,
    supporting_documentation JSONB DEFAULT '[]', -- URLs de documentos de soporte
    batch_number VARCHAR(100),
    
    -- Auditoría
    created_by INTEGER REFERENCES stock.admin_users(id) ON DELETE SET NULL,
    approved_by INTEGER REFERENCES stock.admin_users(id) ON DELETE SET NULL,
    approval_required BOOLEAN DEFAULT false,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- =============================================================================
-- 📊 ÍNDICES OPTIMIZADOS PARA RENDIMIENTO
-- =============================================================================

-- Índices para categories
CREATE INDEX IF NOT EXISTS idx_categories_active_sort ON stock.categories(is_active, sort_order) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_categories_parent ON stock.categories(parent_id) WHERE parent_id IS NOT NULL;

-- Índices para products
CREATE INDEX IF NOT EXISTS idx_products_category_available ON stock.products(category_id, is_available) WHERE is_available = true;
CREATE INDEX IF NOT EXISTS idx_products_stock_status ON stock.products(stock_quantity, min_stock_alert) WHERE is_available = true;
CREATE INDEX IF NOT EXISTS idx_products_search_vector ON stock.products USING GIN(search_vector);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON stock.products(barcode) WHERE barcode IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_products_sku ON stock.products(sku) WHERE sku IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_products_featured ON stock.products(is_featured, popularity_score DESC) WHERE is_featured = true AND is_available = true;
CREATE INDEX IF NOT EXISTS idx_products_price_range ON stock.products(price) WHERE is_available = true;
CREATE INDEX IF NOT EXISTS idx_products_brand ON stock.products(brand) WHERE brand IS NOT NULL;

-- Índices para stock_movements
CREATE INDEX IF NOT EXISTS idx_stock_movements_product_date ON stock.stock_movements(product_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_movements_type_date ON stock.stock_movements(movement_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_movements_reference ON stock.stock_movements(reference_type, reference_id) WHERE reference_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_stock_movements_user ON stock.stock_movements(user_id, created_at DESC) WHERE user_id IS NOT NULL;

-- Índices para suppliers
CREATE INDEX IF NOT EXISTS idx_suppliers_active ON stock.suppliers(is_active, name) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_suppliers_rating ON stock.suppliers(rating DESC) WHERE is_active = true;

-- Índices para purchase_orders
CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier_status ON stock.purchase_orders(supplier_id, status, order_date DESC);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_status_date ON stock.purchase_orders(status, order_date DESC);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_number ON stock.purchase_orders(order_number);

-- Índices para inventory_batches
CREATE INDEX IF NOT EXISTS idx_inventory_batches_product_expiry ON stock.inventory_batches(product_id, expiration_date) WHERE is_active = true AND quantity_remaining > 0;
CREATE INDEX IF NOT EXISTS idx_inventory_batches_expiring ON stock.inventory_batches(expiration_date) WHERE is_active = true AND quantity_remaining > 0 AND expiration_date IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_inventory_batches_batch_number ON stock.inventory_batches(batch_number);

-- Índices para stock_alerts
CREATE INDEX IF NOT EXISTS idx_stock_alerts_product_unresolved ON stock.stock_alerts(product_id, created_at DESC) WHERE NOT is_resolved;
CREATE INDEX IF NOT EXISTS idx_stock_alerts_type_level ON stock.stock_alerts(alert_type, alert_level, created_at DESC) WHERE NOT is_resolved;

-- =============================================================================
-- 🔧 FUNCIONES ESPECÍFICAS DEL SISTEMA DE STOCK
-- =============================================================================

-- Función para actualizar stock de producto con validaciones
CREATE OR REPLACE FUNCTION stock.update_product_stock(
    product_id_param INTEGER,
    new_quantity INTEGER,
    movement_reason TEXT DEFAULT 'Manual adjustment',
    user_id_param INTEGER DEFAULT NULL,
    reference_type_param VARCHAR(50) DEFAULT 'manual_adjustment',
    reference_id_param INTEGER DEFAULT NULL
) RETURNS BOOLEAN AS $func$
DECLARE
    old_quantity INTEGER;
    movement_type_val movement_type_enum;
    quantity_diff INTEGER;
    product_exists BOOLEAN;
BEGIN
    -- Verificar que el producto existe y obtener cantidad actual
    SELECT stock_quantity INTO old_quantity 
    FROM stock.products 
    WHERE id = product_id_param AND is_available = true;
    
    IF old_quantity IS NULL THEN
        RAISE EXCEPTION 'Producto con ID % no encontrado o no disponible', product_id_param;
    END IF;
    
    -- Validar nueva cantidad
    IF new_quantity < 0 THEN
        RAISE EXCEPTION 'La nueva cantidad no puede ser negativa';
    END IF;
    
    -- Calcular diferencia y tipo de movimiento
    quantity_diff := new_quantity - old_quantity;
    
    IF quantity_diff > 0 THEN
        movement_type_val := 'in';
    ELSIF quantity_diff < 0 THEN
        movement_type_val := 'out';
    ELSE
        movement_type_val := 'adjustment';
    END IF;
    
    -- Actualizar producto
    UPDATE stock.products 
    SET stock_quantity = new_quantity, 
        updated_at = NOW()
    WHERE id = product_id_param;
    
    -- Registrar movimiento si hay cambio
    IF quantity_diff != 0 THEN
        INSERT INTO stock.stock_movements (
            product_id, movement_type, quantity_change,
            quantity_before, quantity_after, reason, 
            user_id, reference_type, reference_id
        ) VALUES (
            product_id_param, movement_type_val, ABS(quantity_diff),
            old_quantity, new_quantity, movement_reason, 
            user_id_param, reference_type_param, reference_id_param
        );
    END IF;
    
    -- Verificar alertas de stock
    PERFORM stock.check_stock_alerts(product_id_param);
    
    RETURN TRUE;
END;
$func$ LANGUAGE plpgsql;

-- Función para verificar y crear alertas de stock
CREATE OR REPLACE FUNCTION stock.check_stock_alerts(product_id_param INTEGER)
RETURNS VOID AS $func2$
DECLARE
    product_record RECORD;
    alert_type_val VARCHAR(50);
    alert_level_val VARCHAR(20);
    existing_alert_id INTEGER;
BEGIN
    -- Obtener información del producto
    SELECT id, name, stock_quantity, min_stock_alert, is_available
    INTO product_record
    FROM stock.products
    WHERE id = product_id_param;
    
    IF NOT FOUND OR NOT product_record.is_available THEN
        RETURN;
    END IF;
    
    -- Determinar tipo y nivel de alerta
    IF product_record.stock_quantity = 0 THEN
        alert_type_val := 'out_of_stock';
        alert_level_val := 'critical';
    ELSIF product_record.stock_quantity <= product_record.min_stock_alert THEN
        alert_type_val := 'low_stock';
        IF product_record.stock_quantity <= (product_record.min_stock_alert * 0.5) THEN
            alert_level_val := 'critical';
        ELSE
            alert_level_val := 'warning';
        END IF;
    ELSE
        -- Stock normal, resolver alertas existentes
        UPDATE stock.stock_alerts 
        SET is_resolved = true, 
            resolved_at = NOW(),
            resolution_notes = 'Stock restocked above minimum threshold'
        WHERE product_id = product_id_param 
            AND alert_type IN ('low_stock', 'out_of_stock')
            AND NOT is_resolved;
        RETURN;
    END IF;
    
    -- Verificar si ya existe una alerta similar activa
    SELECT id INTO existing_alert_id
    FROM stock.stock_alerts
    WHERE product_id = product_id_param
        AND alert_type = alert_type_val
        AND NOT is_resolved
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF existing_alert_id IS NULL THEN
        -- Crear nueva alerta
        INSERT INTO stock.stock_alerts (
            product_id, alert_type, alert_level,
            current_quantity, threshold_quantity
        ) VALUES (
            product_id_param, alert_type_val, alert_level_val,
            product_record.stock_quantity, product_record.min_stock_alert
        );
        
        -- También crear alerta en el sistema global
        INSERT INTO shared.system_alerts (
            alert_type, title, message, severity,
            entity_type, entity_id, metadata
        ) VALUES (
            'stock_alert',
            format('Stock %s: %s', 
                CASE WHEN alert_type_val = 'out_of_stock' THEN 'agotado' ELSE 'bajo' END,
                product_record.name
            ),
            format('El producto "%s" tiene %s unidades (mínimo: %s)',
                product_record.name,
                product_record.stock_quantity,
                product_record.min_stock_alert
            ),
            CASE 
                WHEN alert_level_val = 'critical' THEN 'critical'
                ELSE 'warning'
            END,
            'product',
            product_id_param,
            jsonb_build_object(
                'stock_quantity', product_record.stock_quantity,
                'min_stock_alert', product_record.min_stock_alert,
                'alert_type', alert_type_val
            )
        );
    ELSE
        -- Actualizar alerta existente
        UPDATE stock.stock_alerts 
        SET current_quantity = product_record.stock_quantity,
            alert_level = alert_level_val,
            updated_at = NOW()
        WHERE id = existing_alert_id;
    END IF;
END;
$func2$ LANGUAGE plpgsql;

-- Función para obtener productos con bajo stock
CREATE OR REPLACE FUNCTION stock.get_low_stock_products(limit_param INTEGER DEFAULT 50)
RETURNS TABLE(
    product_id INTEGER,
    product_name VARCHAR(255),
    current_stock INTEGER,
    min_stock INTEGER,
    category_name VARCHAR(100),
    urgency_level VARCHAR(20)
) AS $func3$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.name,
        p.stock_quantity,
        p.min_stock_alert,
        c.name,
        CASE 
            WHEN p.stock_quantity = 0 THEN 'critical'
            WHEN p.stock_quantity <= (p.min_stock_alert * 0.5) THEN 'high'
            ELSE 'medium'
        END
    FROM stock.products p
    LEFT JOIN stock.categories c ON p.category_id = c.id
    WHERE p.is_available = true
        AND p.stock_quantity <= p.min_stock_alert
    ORDER BY 
        CASE 
            WHEN p.stock_quantity = 0 THEN 1
            WHEN p.stock_quantity <= (p.min_stock_alert * 0.5) THEN 2
            ELSE 3
        END,
        p.stock_quantity ASC,
        p.name
    LIMIT limit_param;
END;
$func3$ LANGUAGE plpgsql;

-- =============================================================================
-- 📊 VISTAS MATERIALIZADAS PARA RENDIMIENTO
-- =============================================================================

-- Vista materializada para productos con información completa
CREATE MATERIALIZED VIEW IF NOT EXISTS stock.products_with_details AS
SELECT 
    p.*,
    c.name as category_name,
    c.icon_emoji as category_icon,
    
    -- Estado del stock
    CASE 
        WHEN p.stock_quantity = 0 THEN 'out_of_stock'
        WHEN p.stock_quantity <= p.min_stock_alert THEN 'low_stock'
        WHEN p.max_stock_limit IS NOT NULL AND p.stock_quantity >= p.max_stock_limit THEN 'overstock'
        ELSE 'normal'
    END as stock_status,
    
    -- Valor del inventario
    (p.stock_quantity * p.price) as inventory_value,
    (p.stock_quantity * COALESCE(p.cost_price, p.price * 0.7)) as inventory_cost_value,
    
    -- Proveedor principal
    ps.supplier_id as primary_supplier_id,
    s.name as primary_supplier_name,
    
    -- Estadísticas de movimientos (últimos 30 días)
    COALESCE(movement_stats.total_in, 0) as movements_in_30d,
    COALESCE(movement_stats.total_out, 0) as movements_out_30d,
    COALESCE(movement_stats.net_movement, 0) as net_movement_30d

FROM stock.products p
LEFT JOIN stock.categories c ON p.category_id = c.id
LEFT JOIN stock.product_suppliers ps ON p.id = ps.product_id AND ps.is_primary = true
LEFT JOIN stock.suppliers s ON ps.supplier_id = s.id
LEFT JOIN (
    SELECT 
        product_id,
        SUM(CASE WHEN movement_type = 'in' THEN quantity_change ELSE 0 END) as total_in,
        SUM(CASE WHEN movement_type = 'out' THEN quantity_change ELSE 0 END) as total_out,
        SUM(CASE 
            WHEN movement_type = 'in' THEN quantity_change 
            WHEN movement_type = 'out' THEN -quantity_change 
            ELSE 0 
        END) as net_movement
    FROM stock.stock_movements
    WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY product_id
) movement_stats ON p.id = movement_stats.product_id;

-- Índice único para la vista materializada
CREATE UNIQUE INDEX IF NOT EXISTS idx_products_with_details_id ON stock.products_with_details (id);

-- Vista para estadísticas del dashboard
CREATE OR REPLACE VIEW stock.dashboard_stats AS
SELECT 
    COUNT(*) FILTER (WHERE is_available = true) as total_products,
    COUNT(*) FILTER (WHERE is_available = true AND stock_quantity <= min_stock_alert AND stock_quantity > 0) as low_stock_products,
    COUNT(*) FILTER (WHERE is_available = true AND stock_quantity = 0) as out_of_stock_products,
    COUNT(*) FILTER (WHERE is_available = true AND max_stock_limit IS NOT NULL AND stock_quantity >= max_stock_limit) as overstock_products,
    SUM(CASE WHEN is_available = true THEN stock_quantity * price ELSE 0 END) as total_inventory_value,
    SUM(CASE WHEN is_available = true THEN stock_quantity * COALESCE(cost_price, price * 0.7) ELSE 0 END) as total_inventory_cost,
    COUNT(DISTINCT category_id) FILTER (WHERE is_available = true) as active_categories,
    AVG(stock_quantity) FILTER (WHERE is_available = true AND stock_quantity > 0) as avg_stock_level
FROM stock.products;

-- Función para refrescar vistas materializadas
CREATE OR REPLACE FUNCTION stock.refresh_materialized_views()
RETURNS VOID AS $func4$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY stock.products_with_details;
    
    -- Log de la actualización
    INSERT INTO shared.activity_logs (
        action, entity_type, entity_name, source
    ) VALUES (
        'refresh_materialized_views', 'system', 'stock.products_with_details', 'system'
    );
END;
$func4$ LANGUAGE plpgsql;

-- ✅ VERIFICACIÓN DE INSTALACIÓN
DO $$
BEGIN
    RAISE NOTICE '✅ Stock Management Schema instalado correctamente';
    RAISE NOTICE '📦 Tablas principales: products, categories, suppliers, movements';
    RAISE NOTICE '🔍 Vistas materializadas y funciones optimizadas creadas';
    RAISE NOTICE '📊 Índices de rendimiento aplicados';
    RAISE NOTICE '🚨 Sistema de alertas configurado';
END $$;