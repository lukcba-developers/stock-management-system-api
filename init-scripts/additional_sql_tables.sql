-- ============================================================================
-- TABLAS ADICIONALES PARA EL SISTEMA DE GESTIÓN DE STOCK
-- ============================================================================

-- Tabla de usuarios administradores
CREATE TABLE IF NOT EXISTS admin_users (
    id SERIAL PRIMARY KEY,
    google_id VARCHAR(255) UNIQUE,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    picture VARCHAR(500),
    role VARCHAR(50) DEFAULT 'viewer', -- viewer, editor, admin
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en admin_users
CREATE TRIGGER update_admin_users_updated_at
    BEFORE UPDATE ON admin_users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Índices para admin_users
CREATE INDEX idx_admin_users_email ON admin_users(email);
CREATE INDEX idx_admin_users_google_id ON admin_users(google_id) WHERE google_id IS NOT NULL;

-- Tabla de movimientos de stock
CREATE TABLE IF NOT EXISTS stock_movements (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    movement_type VARCHAR(20) NOT NULL, -- 'in', 'out', 'adjustment'
    quantity_change INTEGER NOT NULL,
    quantity_before INTEGER NOT NULL,
    quantity_after INTEGER NOT NULL,
    reason VARCHAR(255),
    reference_type VARCHAR(50), -- 'order', 'manual', 'return', 'loss', 'restock'
    reference_id INTEGER, -- ID del pedido si aplica, o de la orden de compra, etc.
    cost_per_unit DECIMAL(10,2), -- Para movimientos de entrada
    total_cost DECIMAL(12,2), -- Para movimientos de entrada
    supplier_info VARCHAR(255), -- Nombre del proveedor para movimientos de entrada, en lugar de FK directo
    user_id INTEGER REFERENCES admin_users(id) ON DELETE SET NULL, -- Quién realizó el movimiento
    notes TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Índices para stock_movements
CREATE INDEX idx_stock_movements_product ON stock_movements(product_id, created_at DESC);
CREATE INDEX idx_stock_movements_type ON stock_movements(movement_type, created_at DESC);
CREATE INDEX idx_stock_movements_reference ON stock_movements(reference_type, reference_id) WHERE reference_id IS NOT NULL;
CREATE INDEX idx_stock_movements_date ON stock_movements(created_at DESC);

-- Tabla de logs de actividad
CREATE TABLE IF NOT EXISTS activity_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES admin_users(id) ON DELETE SET NULL, -- Quién realizó la acción
    action VARCHAR(50) NOT NULL, -- 'create', 'update', 'delete', 'login', 'export', 'import'
    entity_type VARCHAR(50), -- 'product', 'category', 'order', 'report', 'user', 'supplier', 'purchase_order'
    entity_id INTEGER,
    entity_name VARCHAR(255), -- Para referencia rápida
    changes JSONB, -- Detalles de los cambios realizados
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(100), -- ID de sesión del admin user si aplica
    created_at TIMESTAMP DEFAULT NOW()
);

-- Índices para activity_logs
CREATE INDEX idx_activity_logs_user ON activity_logs(user_id, created_at DESC);
CREATE INDEX idx_activity_logs_entity ON activity_logs(entity_type, entity_id, created_at DESC);
CREATE INDEX idx_activity_logs_action ON activity_logs(action, created_at DESC);
CREATE INDEX idx_activity_logs_date ON activity_logs(created_at DESC);

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
    tax_id VARCHAR(50), -- CUIT/CUIL
    payment_terms VARCHAR(100), -- '30 días', 'Contado', etc
    delivery_days VARCHAR(100), -- 'Lunes y Jueves', etc
    minimum_order_amount DECIMAL(10,2),
    is_active BOOLEAN DEFAULT true,
    notes TEXT,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en suppliers
CREATE TRIGGER update_suppliers_updated_at
    BEFORE UPDATE ON suppliers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Índices para suppliers
CREATE INDEX idx_suppliers_name ON suppliers(name);
CREATE INDEX idx_suppliers_active ON suppliers(is_active) WHERE is_active = true;

-- Tabla de relación productos-proveedores
CREATE TABLE IF NOT EXISTS product_suppliers (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    supplier_id INTEGER REFERENCES suppliers(id) ON DELETE CASCADE,
    supplier_code VARCHAR(100), -- Código del producto según el proveedor
    cost_price DECIMAL(10,2),
    lead_time_days INTEGER, -- Tiempo de entrega en días
    minimum_order_quantity INTEGER,
    is_primary BOOLEAN DEFAULT false,
    last_purchase_date DATE,
    last_purchase_price DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(product_id, supplier_id)
);

-- Trigger para updated_at en product_suppliers
CREATE TRIGGER update_product_suppliers_updated_at
    BEFORE UPDATE ON product_suppliers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Índices para product_suppliers
CREATE INDEX idx_product_suppliers_product ON product_suppliers(product_id);
CREATE INDEX idx_product_suppliers_supplier ON product_suppliers(supplier_id);
CREATE INDEX idx_product_suppliers_primary ON product_suppliers(product_id, is_primary) WHERE is_primary = true;


-- Secuencia para órdenes de compra
CREATE SEQUENCE IF NOT EXISTS purchase_order_seq START 1;

-- Tabla de órdenes de compra
CREATE TABLE IF NOT EXISTS purchase_orders (
    id SERIAL PRIMARY KEY,
    order_number VARCHAR(50) UNIQUE, -- Se generará con trigger
    supplier_id INTEGER REFERENCES suppliers(id) ON DELETE SET NULL,
    status VARCHAR(50) DEFAULT 'draft', -- draft, sent, confirmed, partially_received, received, cancelled
    order_date DATE DEFAULT CURRENT_DATE,
    expected_delivery_date DATE,
    actual_delivery_date DATE,
    subtotal DECIMAL(12,2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    shipping_cost DECIMAL(10,2) DEFAULT 0,
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    payment_status VARCHAR(50) DEFAULT 'pending', -- pending, partial, paid
    payment_method VARCHAR(50),
    invoice_number VARCHAR(100),
    notes TEXT,
    created_by INTEGER REFERENCES admin_users(id) ON DELETE SET NULL,
    approved_by INTEGER REFERENCES admin_users(id) ON DELETE SET NULL,
    received_by INTEGER REFERENCES admin_users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en purchase_orders
CREATE TRIGGER update_purchase_orders_updated_at
    BEFORE UPDATE ON purchase_orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Índices para purchase_orders
CREATE INDEX idx_purchase_orders_supplier ON purchase_orders(supplier_id, order_date DESC);
CREATE INDEX idx_purchase_orders_status ON purchase_orders(status, order_date DESC);
CREATE INDEX idx_purchase_orders_date ON purchase_orders(order_date DESC);

-- Tabla de items de órdenes de compra
CREATE TABLE IF NOT EXISTS purchase_order_items (
    id SERIAL PRIMARY KEY,
    purchase_order_id INTEGER REFERENCES purchase_orders(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
    product_name_snapshot VARCHAR(255) NOT NULL, -- Snapshot del nombre del producto al momento de la orden
    quantity_ordered INTEGER NOT NULL,
    quantity_received INTEGER DEFAULT 0,
    unit_cost DECIMAL(10,2) NOT NULL,
    total_cost DECIMAL(12,2) GENERATED ALWAYS AS (quantity_ordered * unit_cost) STORED, -- Calculado
    tax_rate DECIMAL(5,2) DEFAULT 0, -- Tasa de impuesto específica del item si aplica
    discount_percentage DECIMAL(5,2) DEFAULT 0,
    notes TEXT
    -- No created_at/updated_at aquí, se manejan a nivel de la orden de compra
);

-- Índices para purchase_order_items
CREATE INDEX idx_purchase_order_items_order ON purchase_order_items(purchase_order_id);
CREATE INDEX idx_purchase_order_items_product ON purchase_order_items(product_id);

-- Tabla de inventario por lote (para productos perecederos o con trazabilidad)
CREATE TABLE IF NOT EXISTS inventory_batches (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    batch_number VARCHAR(100) NOT NULL UNIQUE,
    quantity_initial INTEGER NOT NULL,
    quantity_remaining INTEGER NOT NULL,
    cost_per_unit DECIMAL(10,2),
    expiration_date DATE,
    production_date DATE,
    supplier_id INTEGER REFERENCES suppliers(id) ON DELETE SET NULL,
    purchase_order_item_id INTEGER REFERENCES purchase_order_items(id) ON DELETE SET NULL, -- Vínculo al item de OC
    location VARCHAR(100), -- Ubicación en el almacén
    is_active BOOLEAN DEFAULT true, -- Para desactivar lotes sin eliminarlos
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en inventory_batches
CREATE TRIGGER update_inventory_batches_updated_at
    BEFORE UPDATE ON inventory_batches
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Índices para inventory_batches
CREATE INDEX idx_inventory_batches_product_expiration ON inventory_batches(product_id, expiration_date) WHERE is_active = true AND quantity_remaining > 0;
CREATE INDEX idx_inventory_batches_expiration ON inventory_batches(expiration_date) WHERE is_active = true AND quantity_remaining > 0;
CREATE INDEX idx_inventory_batches_batch_number ON inventory_batches(batch_number);

-- Tabla de configuración del sistema
CREATE TABLE IF NOT EXISTS system_config (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value TEXT,
    config_type VARCHAR(50) DEFAULT 'string', -- 'string', 'number', 'boolean', 'json'
    description TEXT,
    is_public BOOLEAN DEFAULT false, -- Si puede ser visto por usuarios no-admin
    updated_by INTEGER REFERENCES admin_users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en system_config
CREATE TRIGGER update_system_config_updated_at
    BEFORE UPDATE ON system_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Configuraciones iniciales
INSERT INTO system_config (config_key, config_value, config_type, description, is_public) VALUES
    ('low_stock_threshold_percentage', '20', 'number', 'Porcentaje del stock mínimo para considerar stock bajo', false),
    ('auto_reorder_enabled', 'false', 'boolean', 'Habilitar reorden automático de productos', false),
    ('default_tax_rate', '21', 'number', 'Tasa de IVA por defecto para cálculos', true),
    ('currency_symbol', '$', 'string', 'Símbolo de moneda del sistema', true),
    ('currency_code', 'ARS', 'string', 'Código de moneda del sistema (ISO 4217)', true),
    ('business_name', 'Supermercado Digital', 'string', 'Nombre del negocio para mostrar', true),
    ('business_address', '', 'string', 'Dirección del negocio', true),
    ('business_phone', '', 'string', 'Teléfono de contacto del negocio', true),
    ('business_email', '', 'string', 'Email de contacto del negocio', true)
ON CONFLICT (config_key) DO UPDATE SET
    config_value = EXCLUDED.config_value,
    config_type = EXCLUDED.config_type,
    description = EXCLUDED.description,
    is_public = EXCLUDED.is_public,
    updated_at = NOW();

-- Nuevas tablas para gestión avanzada de inventario

-- Tabla de ajustes de inventario
CREATE TABLE IF NOT EXISTS inventory_adjustments (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
    adjustment_type VARCHAR(50) NOT NULL, -- 'restock', 'damage', 'theft', 'correction', 'initial_stock'
    quantity_change INTEGER NOT NULL,
    reason TEXT,
    cost_impact DECIMAL(10,2), -- Puede ser positivo o negativo
    created_by INTEGER REFERENCES admin_users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Índices para inventory_adjustments
CREATE INDEX idx_inventory_adjustments_product_id ON inventory_adjustments(product_id);
CREATE INDEX idx_inventory_adjustments_type ON inventory_adjustments(adjustment_type);
CREATE INDEX idx_inventory_adjustments_created_at ON inventory_adjustments(created_at DESC);

-- Tabla de alertas de stock bajo
CREATE TABLE IF NOT EXISTS low_stock_alerts (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE UNIQUE, -- UNIQUE para asegurar una alerta activa por producto
    alert_level VARCHAR(20) NOT NULL, -- 'warning', 'critical', 'out_of_stock'
    current_quantity INTEGER NOT NULL,
    threshold_quantity INTEGER NOT NULL,
    notification_sent_at TIMESTAMP,
    last_checked_at TIMESTAMP DEFAULT NOW(),
    resolved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en low_stock_alerts
CREATE TRIGGER update_low_stock_alerts_updated_at
    BEFORE UPDATE ON low_stock_alerts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Índices para low_stock_alerts
CREATE INDEX idx_low_stock_alerts_product_id ON low_stock_alerts(product_id) WHERE resolved_at IS NULL;
CREATE INDEX idx_low_stock_alerts_level ON low_stock_alerts(alert_level) WHERE resolved_at IS NULL;
CREATE INDEX idx_low_stock_alerts_notification_sent_at ON low_stock_alerts(notification_sent_at) WHERE resolved_at IS NULL;

-- Vista para análisis de rotación de inventario
CREATE OR REPLACE VIEW inventory_turnover_analysis AS
WITH sales_data AS (
    SELECT
        oi.product_id,
        SUM(oi.quantity) as units_sold_period,
        SUM(oi.total_price) as revenue_period, -- Asumiendo que order_items tiene total_price
        COUNT(DISTINCT o.id) as orders_with_product_period
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.id
    -- Considerar un período configurable, por ejemplo, últimos 90 días
    WHERE o.created_at >= CURRENT_DATE - INTERVAL '90 days'
    AND o.order_status IN ('delivered', 'completed') -- O los estados que consideren venta finalizada
    GROUP BY oi.product_id
),
avg_inventory AS (
    -- Esta es una simplificación. Un cálculo más preciso podría promediar el stock diario.
    -- O usar (stock_inicial_periodo + stock_final_periodo) / 2 si se tienen esos datos.
    -- Por ahora, usaremos el stock actual como proxy del stock promedio.
    SELECT
        p.id as product_id,
        p.stock_quantity as current_stock_level,
        (SELECT AVG(sm.quantity_after) FROM stock_movements sm WHERE sm.product_id = p.id AND sm.created_at >= CURRENT_DATE - INTERVAL '90 days') as avg_stock_level_period
    FROM products p
),
cost_of_goods_sold AS (
    -- Se necesitaría el costo del producto para calcular COGS.
    -- Asumimos que product_suppliers tiene el cost_price más relevante.
    SELECT
        ps.product_id,
        AVG(ps.cost_price) as avg_cost_price -- Promedio si hay múltiples proveedores/costos
    FROM product_suppliers ps
    WHERE ps.cost_price IS NOT NULL
    GROUP BY ps.product_id
)
SELECT
    p.id as product_id,
    p.name as product_name,
    p.barcode,
    cat.name as category_name,
    COALESCE(ai.current_stock_level, p.stock_quantity) as current_stock, -- Fallback al stock de products
    p.min_stock_alert,
    COALESCE(sd.units_sold_period, 0) as units_sold_last_90d,
    COALESCE(sd.revenue_period, 0) as revenue_last_90d,
    COALESCE(cogs.avg_cost_price, 0) as avg_unit_cost,
    (COALESCE(sd.units_sold_period, 0) * COALESCE(cogs.avg_cost_price, 0)) as cogs_last_90d,
    (COALESCE(sd.revenue_period, 0) - (COALESCE(sd.units_sold_period, 0) * COALESCE(cogs.avg_cost_price, 0))) as gross_profit_last_90d,
    CASE
        WHEN COALESCE(cogs.avg_cost_price, 0) > 0 AND COALESCE(ai.avg_stock_level_period, p.stock_quantity, 0) > 0
        THEN (COALESCE(sd.units_sold_period, 0) * COALESCE(cogs.avg_cost_price, 0)) / (COALESCE(ai.avg_stock_level_period, p.stock_quantity) * COALESCE(cogs.avg_cost_price, 0))
        ELSE 0
    END as inventory_turnover_ratio_90d, -- (COGS / Avg Inventory Value)
    CASE
        WHEN COALESCE(sd.units_sold_period, 0) > 0
        THEN 90.0 / ( (COALESCE(sd.units_sold_period, 0) * COALESCE(cogs.avg_cost_price, 0)) / (COALESCE(ai.avg_stock_level_period, p.stock_quantity, 0) * COALESCE(cogs.avg_cost_price, 0)) )
        WHEN COALESCE(ai.avg_stock_level_period, p.stock_quantity, 0) > 0 THEN 9999 -- Stock pero sin ventas
        ELSE 0
    END as days_sales_of_inventory_90d, -- (365 / Turnover Ratio) - ajustado a 90 días
    (COALESCE(ai.current_stock_level, p.stock_quantity) * COALESCE(cogs.avg_cost_price, p.price * 0.7)) as current_stock_value_at_cost, -- Estimación si no hay costo
    p.updated_at as product_last_update
FROM products p
LEFT JOIN categories cat ON p.category_id = cat.id
LEFT JOIN sales_data sd ON p.id = sd.product_id
LEFT JOIN avg_inventory ai ON p.id = ai.product_id
LEFT JOIN cost_of_goods_sold cogs ON p.id = cogs.product_id
WHERE p.is_available = true;

-- Función para generar número de orden de compra
CREATE OR REPLACE FUNCTION generate_purchase_order_number()
RETURNS TRIGGER AS $$
DECLARE
    next_val BIGINT;
BEGIN
    SELECT nextval('purchase_order_seq') INTO next_val;
    NEW.order_number := 'PO-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(next_val::TEXT, 5, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para generar número de orden automático
CREATE TRIGGER trg_generate_po_number
    BEFORE INSERT ON purchase_orders
    FOR EACH ROW
    WHEN (NEW.order_number IS NULL OR NEW.order_number = '')
    EXECUTE FUNCTION generate_purchase_order_number();

-- Función para registrar cambios en productos (actualizada para usar current_setting)
CREATE OR REPLACE FUNCTION log_product_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_changes JSONB;
    v_user_id INTEGER;
    v_session_user_id TEXT;
BEGIN
    -- Intenta obtener el ID del usuario actual desde la configuración de sesión
    -- La aplicación debe establecer 'app.current_user_id' al inicio de la sesión/transacción del admin
    BEGIN
        v_session_user_id := current_setting('app.current_user_id', true);
        IF v_session_user_id IS NOT NULL AND v_session_user_id ~ '^[0-9]+$' THEN
            v_user_id := v_session_user_id::INTEGER;
        ELSE
            v_user_id := NULL; -- O un ID de usuario por defecto para 'sistema'
        END IF;
    EXCEPTION WHEN UNDEFINED_PARAMETER THEN
        v_user_id := NULL; -- Si el parámetro no está definido
    END;

    v_changes := jsonb_build_object();

    IF OLD.name IS DISTINCT FROM NEW.name THEN
        v_changes := v_changes || jsonb_build_object('name', jsonb_build_object('old', OLD.name, 'new', NEW.name));
    END IF;
    IF OLD.description IS DISTINCT FROM NEW.description THEN
        v_changes := v_changes || jsonb_build_object('description', jsonb_build_object('old', OLD.description, 'new', NEW.description));
    END IF;
    IF OLD.price IS DISTINCT FROM NEW.price THEN
        v_changes := v_changes || jsonb_build_object('price', jsonb_build_object('old', OLD.price, 'new', NEW.price));
    END IF;
    IF OLD.stock_quantity IS DISTINCT FROM NEW.stock_quantity THEN
        v_changes := v_changes || jsonb_build_object('stock_quantity', jsonb_build_object('old', OLD.stock_quantity, 'new', NEW.stock_quantity));
    END IF;
    IF OLD.min_stock_alert IS DISTINCT FROM NEW.min_stock_alert THEN
        v_changes := v_changes || jsonb_build_object('min_stock_alert', jsonb_build_object('old', OLD.min_stock_alert, 'new', NEW.min_stock_alert));
    END IF;
    IF OLD.category_id IS DISTINCT FROM NEW.category_id THEN
        v_changes := v_changes || jsonb_build_object('category_id', jsonb_build_object('old', OLD.category_id, 'new', NEW.category_id));
    END IF;
    IF OLD.is_available IS DISTINCT FROM NEW.is_available THEN
        v_changes := v_changes || jsonb_build_object('is_available', jsonb_build_object('old', OLD.is_available, 'new', NEW.is_available));
    END IF;
    IF OLD.barcode IS DISTINCT FROM NEW.barcode THEN
        v_changes := v_changes || jsonb_build_object('barcode', jsonb_build_object('old', OLD.barcode, 'new', NEW.barcode));
    END IF;
    -- Añadir más campos si es necesario

    IF v_changes != '{}'::jsonb THEN
        INSERT INTO activity_logs (user_id, action, entity_type, entity_id, entity_name, changes)
        VALUES (v_user_id, 'update', 'product', NEW.id, NEW.name, v_changes);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para registrar cambios en productos
CREATE TRIGGER trg_log_product_changes
    AFTER UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION log_product_changes();

-- Insertar usuarios admin de ejemplo (SOLO PARA DESARROLLO)
-- Asegúrate de que la función update_updated_at_column exista (debería estar en init-db.sql)
-- INSERT INTO admin_users (email, name, role, google_id) VALUES
--     ('admin@example.com', 'Administrador Principal', 'admin', 'google_id_admin123'),
--     ('editor@example.com', 'Editor de Contenido', 'editor', 'google_id_editor456'),
--     ('viewer@example.com', 'Visualizador de Datos', 'viewer', 'google_id_viewer789')
-- ON CONFLICT (email) DO NOTHING;
