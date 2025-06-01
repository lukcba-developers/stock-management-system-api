-- backend/sql/additional_sql_tables.sql

-- Tabla de usuarios administradores
CREATE TABLE IF NOT EXISTS admin_users (
    id SERIAL PRIMARY KEY,
    google_id VARCHAR(255) UNIQUE,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    picture VARCHAR(500),
    role VARCHAR(50) DEFAULT 'viewer' CHECK (role IN ('viewer', 'editor', 'admin')),
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_admin_users_email ON admin_users(email);
CREATE INDEX IF NOT EXISTS idx_admin_users_google_id ON admin_users(google_id) WHERE google_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_admin_users_role ON admin_users(role);

-- Tabla de movimientos de stock
CREATE TABLE IF NOT EXISTS stock_movements (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    movement_type VARCHAR(20) NOT NULL CHECK (movement_type IN ('in', 'out', 'adjustment', 'initial_stock', 'sale', 'return', 'loss', 'restock')),
    quantity_change INTEGER NOT NULL,
    quantity_before INTEGER NOT NULL,
    quantity_after INTEGER NOT NULL,
    reason VARCHAR(255),
    reference_type VARCHAR(50),
    reference_id VARCHAR(255),
    cost_per_unit DECIMAL(10,2),
    total_cost DECIMAL(12,2),
    supplier_id INTEGER REFERENCES suppliers(id) ON DELETE SET NULL,
    user_id INTEGER REFERENCES admin_users(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_stock_movements_product_id_created_at ON stock_movements(product_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_movements_type_created_at ON stock_movements(movement_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_movements_reference ON stock_movements(reference_type, reference_id) WHERE reference_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_stock_movements_created_at ON stock_movements(created_at DESC);

-- Tabla de logs de actividad
CREATE TABLE IF NOT EXISTS activity_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES admin_users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50),
    entity_id VARCHAR(255),
    entity_name VARCHAR(255),
    changes JSONB,
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_activity_logs_user_id_created_at ON activity_logs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_entity_type_entity_id ON activity_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_action_created_at ON activity_logs(action, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON activity_logs(created_at DESC);

-- Tabla de proveedores
CREATE TABLE IF NOT EXISTS suppliers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    contact_person VARCHAR(255),
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(50),
    address TEXT,
    city VARCHAR(100),
    country VARCHAR(100) DEFAULT 'Argentina',
    tax_id VARCHAR(50) UNIQUE,
    payment_terms VARCHAR(100),
    delivery_days VARCHAR(255),
    minimum_order_amount DECIMAL(12,2),
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    website VARCHAR(500),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_suppliers_name ON suppliers(name);
CREATE INDEX IF NOT EXISTS idx_suppliers_active ON suppliers(is_active) WHERE is_active = true;

-- Tabla de relación productos-proveedores
CREATE TABLE IF NOT EXISTS product_suppliers (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    supplier_id INTEGER REFERENCES suppliers(id) ON DELETE CASCADE,
    supplier_product_code VARCHAR(100),
    cost_price DECIMAL(10,2) NOT NULL,
    lead_time_days INTEGER,
    minimum_order_quantity INTEGER,
    is_primary_supplier BOOLEAN DEFAULT FALSE,
    last_purchase_date DATE,
    last_purchase_price DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(product_id, supplier_id)
);
CREATE INDEX IF NOT EXISTS idx_product_suppliers_product_id ON product_suppliers(product_id);
CREATE INDEX IF NOT EXISTS idx_product_suppliers_supplier_id ON product_suppliers(supplier_id);
CREATE INDEX IF NOT EXISTS idx_product_suppliers_primary_supplier ON product_suppliers(product_id, is_primary_supplier) WHERE is_primary_supplier = true;

-- Tabla de órdenes de compra
CREATE SEQUENCE IF NOT EXISTS purchase_order_seq START 1001;
CREATE TABLE IF NOT EXISTS purchase_orders (
    id SERIAL PRIMARY KEY,
    order_number VARCHAR(50) UNIQUE NOT NULL DEFAULT ('PO-' || NEXTVAL('purchase_order_seq')::TEXT),
    supplier_id INTEGER REFERENCES suppliers(id) ON DELETE RESTRICT,
    status VARCHAR(50) DEFAULT 'draft' CHECK (status IN ('draft', 'pending_approval', 'approved', 'sent', 'partially_received', 'received', 'cancelled', 'closed')),
    order_date DATE DEFAULT CURRENT_DATE,
    expected_delivery_date DATE,
    actual_delivery_date DATE,
    subtotal_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(12,2) DEFAULT 0,
    shipping_cost DECIMAL(12,2) DEFAULT 0,
    discount_amount DECIMAL(12,2) DEFAULT 0,
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    payment_status VARCHAR(50) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'partially_paid', 'paid', 'refunded')),
    payment_method VARCHAR(50),
    invoice_reference VARCHAR(100),
    notes TEXT,
    created_by INTEGER REFERENCES admin_users(id),
    approved_by INTEGER REFERENCES admin_users(id),
    received_by INTEGER REFERENCES admin_users(id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier_id_order_date ON purchase_orders(supplier_id, order_date DESC);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_status_order_date ON purchase_orders(status, order_date DESC);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_order_date ON purchase_orders(order_date DESC);

-- Tabla de items de órdenes de compra
CREATE TABLE IF NOT EXISTS purchase_order_items (
    id SERIAL PRIMARY KEY,
    purchase_order_id INTEGER REFERENCES purchase_orders(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(id) ON DELETE RESTRICT,
    product_name_snapshot VARCHAR(255) NOT NULL,
    quantity_ordered INTEGER NOT NULL,
    quantity_received INTEGER DEFAULT 0,
    unit_cost DECIMAL(10,2) NOT NULL,
    item_subtotal DECIMAL(12,2) NOT NULL,
    tax_rate DECIMAL(5,2) DEFAULT 21.00,
    discount_percentage DECIMAL(5,2) DEFAULT 0,
    item_total_cost DECIMAL(12,2) NOT NULL,
    notes TEXT
);
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_purchase_order_id ON purchase_order_items(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_product_id ON purchase_order_items(product_id);

-- Tabla de inventario por lote
CREATE TABLE IF NOT EXISTS inventory_batches (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    batch_number VARCHAR(100) NOT NULL,
    quantity_initial INTEGER NOT NULL,
    quantity_remaining INTEGER NOT NULL,
    cost_per_unit DECIMAL(10,2),
    expiration_date DATE,
    production_date DATE,
    supplier_id INTEGER REFERENCES suppliers(id) ON DELETE SET NULL,
    purchase_order_item_id INTEGER REFERENCES purchase_order_items(id) ON DELETE SET NULL,
    location_in_store VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE (product_id, batch_number)
);
CREATE INDEX IF NOT EXISTS idx_inventory_batches_product_id_expiration_date ON inventory_batches(product_id, expiration_date);
CREATE INDEX IF NOT EXISTS idx_inventory_batches_expiration_date ON inventory_batches(expiration_date) WHERE is_active = true AND quantity_remaining > 0;
CREATE INDEX IF NOT EXISTS idx_inventory_batches_batch_number ON inventory_batches(batch_number);

-- Tabla de configuración del sistema
CREATE TABLE IF NOT EXISTS system_config (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value TEXT,
    config_type VARCHAR(50) DEFAULT 'string' CHECK (config_type IN ('string', 'number', 'boolean', 'json', 'array')),
    description TEXT,
    is_public BOOLEAN DEFAULT FALSE,
    is_editable_by_ui BOOLEAN DEFAULT TRUE,
    validation_rules JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    updated_by INTEGER REFERENCES admin_users(id) ON DELETE SET NULL
);
INSERT INTO system_config (config_key, config_value, config_type, description, is_editable_by_ui) VALUES
    ('low_stock_threshold_default_percentage', '20', 'number', 'Porcentaje por defecto del stock total para considerar stock bajo, si min_stock_alert no está definido en el producto.', true),
    ('auto_reorder_enabled', 'false', 'boolean', 'Habilitar reorden automático de productos (funcionalidad futura).', false),
    ('default_tax_rate_percentage', '21', 'number', 'Tasa de IVA por defecto para cálculos (%).', true),
    ('currency_symbol', '$', 'string', 'Símbolo de moneda del sistema.', true),
    ('currency_code', 'ARS', 'string', 'Código de moneda del sistema (ISO 4217).', true),
    ('business_name', 'Supermercado StockPro', 'string', 'Nombre del negocio para reportes, etc.', true),
    ('business_address', 'Av. Siempre Viva 123, Springfield', 'string', 'Dirección del negocio.', true),
    ('business_phone', '+54 9 11 1234-5678', 'string', 'Teléfono de contacto del negocio.', true),
    ('business_email', 'contacto@stockpro.com', 'string', 'Email de contacto del negocio.', true),
    ('report_export_limit', '5000', 'number', 'Límite de filas para exportaciones directas de reportes.', false)
ON CONFLICT (config_key) DO NOTHING;

-- Vista para análisis de rotación de inventario
CREATE OR REPLACE VIEW inventory_turnover_analysis AS
WITH sales_last_30d AS (
    SELECT
        oi.product_id,
        SUM(oi.quantity) as units_sold_30d,
        SUM(oi.subtotal) as revenue_30d,
        COUNT(DISTINCT o.id) as order_count_30d
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.id
    WHERE o.created_at >= CURRENT_DATE - INTERVAL '30 days'
    AND o.order_status IN ('delivered', 'completed', 'paid')
    GROUP BY oi.product_id
),
avg_stock_30d AS (
    SELECT
        p.id as product_id,
        (p.stock_quantity + COALESCE( (SELECT quantity_before FROM stock_movements sm WHERE sm.product_id = p.id AND sm.created_at < (CURRENT_DATE - INTERVAL '30 days') ORDER BY sm.created_at DESC LIMIT 1), p.stock_quantity) ) / 2.0 as avg_stock_level_30d
    FROM products p
)
SELECT
    p.id as product_id,
    p.name as product_name,
    p.barcode,
    c.name as category_name,
    p.stock_quantity as current_stock,
    p.min_stock_alert,
    p.price as current_price,
    COALESCE(s.units_sold_30d, 0) as units_sold_last_30d,
    COALESCE(s.revenue_30d, 0) as revenue_last_30d,
    (p.stock_quantity * p.price) as current_stock_value,
    CASE
        WHEN COALESCE(s.units_sold_30d, 0) > 0 THEN ROUND((p.stock_quantity / (COALESCE(s.units_sold_30d, 0) / 30.0))::numeric, 1)
        ELSE NULL
    END as days_of_stock,
    CASE
        WHEN COALESCE(avg_s.avg_stock_level_30d, 0) > 0 THEN ROUND(((COALESCE(s.units_sold_30d, 0) * 12.0) / avg_s.avg_stock_level_30d)::numeric, 2)
        ELSE NULL
    END as annual_turnover_rate,
    p.updated_at as last_stock_update
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN sales_last_30d s ON p.id = s.product_id
LEFT JOIN avg_stock_30d avg_s ON p.id = avg_s.product_id
WHERE p.is_available = true;

-- Triggers para updated_at
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_timestamp_products
BEFORE UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp_categories
BEFORE UPDATE ON categories
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp_admin_users
BEFORE UPDATE ON admin_users
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp(); 