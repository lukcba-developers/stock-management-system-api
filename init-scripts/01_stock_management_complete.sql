-- ============================================================================
-- 📦 STOCK MANAGEMENT SCHEMA - SISTEMA DE GESTIÓN DE INVENTARIO CON MULTI-TENANCY
-- ============================================================================
-- Archivo: init-scripts/01_stock_management.sql
-- Propósito: Tablas específicas para el sistema de gestión de stock con soporte SaaS
-- Dependencias: 00_core_schema.sql
-- Orden de ejecución: SEGUNDO (01_)
-- ============================================================================

-- 👥 USUARIOS AUTORIZADOS SAAS (Movido aquí para dependencias)
CREATE TABLE IF NOT EXISTS saas.authorized_users (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,

    -- Información del usuario
    name VARCHAR(255),
    google_id VARCHAR(255) UNIQUE,
    picture VARCHAR(500),

    -- Permisos
    role user_role_enum DEFAULT 'viewer',
    permissions JSONB DEFAULT '{}',      -- Permisos específicos

    -- Estado
    status VARCHAR(30) DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'suspended', 'removed')),
    invitation_token VARCHAR(255) UNIQUE,
    invitation_sent_at TIMESTAMP,
    invitation_accepted_at TIMESTAMP,

    -- Acceso
    last_login TIMESTAMP,
    login_count INTEGER DEFAULT 0,
    password_hash VARCHAR(255), -- Para login tradicional si es necesario

    -- Configuraciones del usuario
    preferences JSONB DEFAULT '{}',
    notifications_enabled BOOLEAN DEFAULT true,
    dashboard_config JSONB DEFAULT '{}',
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP,

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    UNIQUE (organization_id, email)
);

-- Trigger para updated_at en authorized_users
CREATE TRIGGER update_authorized_users_updated_at
    BEFORE UPDATE ON saas.authorized_users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Índices para authorized_users
CREATE INDEX IF NOT EXISTS idx_authorized_users_email ON saas.authorized_users(email);
CREATE INDEX IF NOT EXISTS idx_authorized_users_org_status ON saas.authorized_users(organization_id, status);
CREATE INDEX IF NOT EXISTS idx_authorized_users_google_id ON saas.authorized_users(google_id) WHERE google_id IS NOT NULL;

-- 🏷️ CATEGORÍAS DE PRODUCTOS (Multi-tenant)
CREATE TABLE IF NOT EXISTS stock.categories (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    icon_emoji VARCHAR(10),
    parent_id INTEGER REFERENCES stock.categories(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    seo_slug VARCHAR(120),
    meta_title VARCHAR(120),
    meta_description VARCHAR(160),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(organization_id, name)
);

-- Trigger para updated_at en categories
CREATE TRIGGER update_categories_updated_at
    BEFORE UPDATE ON stock.categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 📦 PRODUCTOS PRINCIPALES (Multi-tenant)
CREATE TABLE IF NOT EXISTS stock.products (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
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
    barcode VARCHAR(100),
    sku VARCHAR(100),
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
    seo_slug VARCHAR(150),
    
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
    ),
    UNIQUE(organization_id, barcode) WHERE barcode IS NOT NULL,
    UNIQUE(organization_id, sku) WHERE sku IS NOT NULL
);

-- Trigger para updated_at en products
CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON stock.products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Función para obtener productos con bajo stock (Multi-tenant)
CREATE OR REPLACE FUNCTION stock.get_low_stock_products(org_id INTEGER, limit_param INTEGER DEFAULT 50)
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
    WHERE p.organization_id = org_id
      AND p.is_available = true
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
-- 📊 VISTAS MATERIALIZADAS PARA RENDIMIENTO (Multi-tenant)
-- =============================================================================

-- Vista materializada para productos con información completa (Multi-tenant)
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
LEFT JOIN stock.categories c ON p.category_id = c.id AND c.organization_id = p.organization_id
LEFT JOIN stock.product_suppliers ps ON p.id = ps.product_id AND ps.is_primary = true
LEFT JOIN stock.suppliers s ON ps.supplier_id = s.id AND s.organization_id = p.organization_id
LEFT JOIN (
    SELECT 
        organization_id,
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
    GROUP BY organization_id, product_id
) movement_stats ON p.organization_id = movement_stats.organization_id AND p.id = movement_stats.product_id;

-- Índice único para la vista materializada
CREATE UNIQUE INDEX IF NOT EXISTS idx_products_with_details_org_id ON stock.products_with_details (organization_id, id);

-- Vista para estadísticas del dashboard (Multi-tenant)
CREATE OR REPLACE VIEW stock.dashboard_stats AS
SELECT 
    organization_id,
    COUNT(*) FILTER (WHERE is_available = true) as total_products,
    COUNT(*) FILTER (WHERE is_available = true AND stock_quantity <= min_stock_alert AND stock_quantity > 0) as low_stock_products,
    COUNT(*) FILTER (WHERE is_available = true AND stock_quantity = 0) as out_of_stock_products,
    COUNT(*) FILTER (WHERE is_available = true AND max_stock_limit IS NOT NULL AND stock_quantity >= max_stock_limit) as overstock_products,
    SUM(CASE WHEN is_available = true THEN stock_quantity * price ELSE 0 END) as total_inventory_value,
    SUM(CASE WHEN is_available = true THEN stock_quantity * COALESCE(cost_price, price * 0.7) ELSE 0 END) as total_inventory_cost,
    COUNT(DISTINCT category_id) FILTER (WHERE is_available = true) as active_categories,
    AVG(stock_quantity) FILTER (WHERE is_available = true AND stock_quantity > 0) as avg_stock_level
FROM stock.products
GROUP BY organization_id;

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

-- =============================================================================
-- 🏢 PLANES DE SUSCRIPCIÓN SAAS
-- =============================================================================

-- Tabla de planes de suscripción
CREATE TABLE IF NOT EXISTS saas.subscription_plans (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    description TEXT,

    -- Precios
    monthly_price DECIMAL(10, 2),
    yearly_price DECIMAL(10, 2),
    currency VARCHAR(3) DEFAULT 'USD',

    -- Límites
    max_users INTEGER,
    max_products INTEGER,
    max_monthly_orders INTEGER,
    max_categories INTEGER,
    storage_gb INTEGER,

    -- Features
    features JSONB NOT NULL DEFAULT '{}',

    -- Configuración
    is_active BOOLEAN DEFAULT true,
    is_featured BOOLEAN DEFAULT false,
    sort_order INTEGER DEFAULT 0,

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en subscription_plans
CREATE TRIGGER update_subscription_plans_updated_at
    BEFORE UPDATE ON saas.subscription_plans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insertar planes predefinidos
INSERT INTO saas.subscription_plans (name, display_name, monthly_price, yearly_price, max_users, max_products, max_monthly_orders, max_categories, storage_gb, features) VALUES 
    ('starter', 'Plan Starter', 29.00, 290.00, 5, 100, 500, 20, 1, '{"api_access": false, "priority_support": false, "custom_branding": false}'),
    ('professional', 'Plan Professional', 99.00, 990.00, 20, 1000, 2000, 50, 10, '{"api_access": true, "priority_support": false, "custom_branding": true, "advanced_analytics": true}'),
    ('enterprise', 'Plan Enterprise', 299.00, 2990.00, 100, 10000, 10000, 999, 100, '{"api_access": true, "priority_support": true, "custom_branding": true, "advanced_analytics": true, "dedicated_support": true}')
ON CONFLICT (name) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    monthly_price = EXCLUDED.monthly_price,
    yearly_price = EXCLUDED.yearly_price,
    max_users = EXCLUDED.max_users,
    max_products = EXCLUDED.max_products,
    max_monthly_orders = EXCLUDED.max_monthly_orders,
    max_categories = EXCLUDED.max_categories,
    storage_gb = EXCLUDED.storage_gb,
    features = EXCLUDED.features,
    updated_at = NOW();

-- =============================================================================
-- 🔒 ROW LEVEL SECURITY (RLS) PARA STOCK MANAGEMENT
-- =============================================================================

-- Habilitar RLS en productos
ALTER TABLE stock.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY products_isolation ON stock.products
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id());

-- Habilitar RLS en categorías
ALTER TABLE stock.categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY categories_isolation ON stock.categories
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id());

-- Habilitar RLS en proveedores
ALTER TABLE stock.suppliers ENABLE ROW LEVEL SECURITY;
CREATE POLICY suppliers_isolation ON stock.suppliers
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id());

-- Habilitar RLS en movimientos de stock
ALTER TABLE stock.stock_movements ENABLE ROW LEVEL SECURITY;
CREATE POLICY stock_movements_isolation ON stock.stock_movements
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id());

-- Habilitar RLS en órdenes de compra
ALTER TABLE stock.purchase_orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY purchase_orders_isolation ON stock.purchase_orders
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id());

-- Habilitar RLS en alertas de stock
ALTER TABLE stock.stock_alerts ENABLE ROW LEVEL SECURITY;
CREATE POLICY stock_alerts_isolation ON stock.stock_alerts
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id());

-- Habilitar RLS en ajustes de inventario
ALTER TABLE stock.inventory_adjustments ENABLE ROW LEVEL SECURITY;
CREATE POLICY inventory_adjustments_isolation ON stock.inventory_adjustments
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id());

-- Habilitar RLS en lotes de inventario
ALTER TABLE stock.inventory_batches ENABLE ROW LEVEL SECURITY;
CREATE POLICY inventory_batches_isolation ON stock.inventory_batches
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id());

-- Habilitar RLS en relación productos-proveedores
ALTER TABLE stock.product_suppliers ENABLE ROW LEVEL SECURITY;
CREATE POLICY product_suppliers_isolation ON stock.product_suppliers
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id());

-- Habilitar RLS en items de órdenes de compra
ALTER TABLE stock.purchase_order_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY purchase_order_items_isolation ON stock.purchase_order_items
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id());

-- Habilitar RLS en usuarios autorizados
ALTER TABLE saas.authorized_users ENABLE ROW LEVEL SECURITY;
CREATE POLICY authorized_users_isolation ON saas.authorized_users
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id());

-- =============================================================================
-- 📊 DATOS INICIALES Y MIGRACIÓN
-- =============================================================================

-- Crear organización demo si no existe
INSERT INTO saas.organizations (name, slug, subscription_plan, max_users, max_products, max_monthly_orders, max_categories, storage_gb)
VALUES ('Empresa Demo', 'empresa-demo', 'professional', 20, 1000, 2000, 50, 10)
ON CONFLICT (slug) DO NOTHING;

-- Crear usuario owner demo
DO $
DECLARE
    demo_org_id INTEGER;
BEGIN
    SELECT id INTO demo_org_id FROM saas.organizations WHERE slug = 'empresa-demo';
    
    IF demo_org_id IS NOT NULL THEN
        INSERT INTO saas.authorized_users (organization_id, email, name, role, status)
        VALUES (demo_org_id, 'admin@empresa-demo.com', 'Administrador Demo', 'owner', 'active')
        ON CONFLICT (organization_id, email) DO NOTHING;
    END IF;
END $;

-- ✅ VERIFICACIÓN DE INSTALACIÓN
DO $
BEGIN
    RAISE NOTICE '✅ Stock Management Schema con SaaS instalado correctamente';
    RAISE NOTICE '📦 Tablas principales: products, categories, suppliers, movements (Multi-tenant)';
    RAISE NOTICE '👥 Usuarios autorizados y planes de suscripción configurados';
    RAISE NOTICE '🔍 Vistas materializadas y funciones optimizadas creadas';
    RAISE NOTICE '📊 Índices de rendimiento aplicados';
    RAISE NOTICE '🚨 Sistema de alertas configurado';
    RAISE NOTICE '🔒 Row Level Security (RLS) habilitado en todas las tablas';
    RAISE NOTICE '🏢 Organización demo creada: empresa-demo';
END $; para actualizar search_vector automáticamente
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

-- 📊 MOVIMIENTOS DE STOCK (Multi-tenant)
CREATE TABLE IF NOT EXISTS stock.stock_movements (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
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
    user_id INTEGER REFERENCES saas.authorized_users(id) ON DELETE SET NULL,
    notes TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

-- 🏪 PROVEEDORES (Multi-tenant)
CREATE TABLE IF NOT EXISTS stock.suppliers (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255),
    email VARCHAR(255),
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
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(organization_id, name)
);

-- Trigger para updated_at en suppliers
CREATE TRIGGER update_suppliers_updated_at
    BEFORE UPDATE ON stock.suppliers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 🔗 RELACIÓN PRODUCTOS-PROVEEDORES (Multi-tenant)
CREATE TABLE IF NOT EXISTS stock.product_suppliers (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
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

-- 📋 ÓRDENES DE COMPRA (Multi-tenant)
CREATE TABLE IF NOT EXISTS stock.purchase_orders (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
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
    created_by INTEGER REFERENCES saas.authorized_users(id) ON DELETE SET NULL,
    approved_by INTEGER REFERENCES saas.authorized_users(id) ON DELETE SET NULL,
    received_by INTEGER REFERENCES saas.authorized_users(id) ON DELETE SET NULL,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en purchase_orders
CREATE TRIGGER update_purchase_orders_updated_at
    BEFORE UPDATE ON stock.purchase_orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 📝 ITEMS DE ÓRDENES DE COMPRA (Multi-tenant)
CREATE TABLE IF NOT EXISTS stock.purchase_order_items (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
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

-- 📦 INVENTARIO POR LOTES (Multi-tenant)
CREATE TABLE IF NOT EXISTS stock.inventory_batches (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
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
    
    UNIQUE(organization_id, batch_number, product_id),
    
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

-- 📊 AJUSTES DE INVENTARIO (Multi-tenant)
CREATE TABLE IF NOT EXISTS stock.inventory_adjustments (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES stock.products(id) ON DELETE SET NULL,
    adjustment_type VARCHAR(50) NOT NULL CHECK (adjustment_type IN ('restock', 'damage', 'theft', 'correction', 'expired', 'returned', 'found', 'initial_stock')),
    quantity_change INTEGER NOT NULL,
    quantity_before INTEGER NOT NULL,
    quantity_after INTEGER NOT NULL,
    reason TEXT NOT NULL,
    cost_impact DECIMAL(12,2) DEFAULT 0,
    supporting_documentation JSONB DEFAULT '[]', -- URLs de documentos de soporte
    batch_number VARCHAR(100),
    created_by INTEGER REFERENCES saas.authorized_users(id) ON DELETE SET NULL,
    approved_by INTEGER REFERENCES saas.authorized_users(id) ON DELETE SET NULL,
    approval_required BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 🚨 ALERTAS DE STOCK (Multi-tenant)
CREATE TABLE IF NOT EXISTS stock.stock_alerts (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES stock.products(id) ON DELETE CASCADE,
    alert_type VARCHAR(50) NOT NULL CHECK (alert_type IN ('low_stock', 'out_of_stock', 'expiring_soon', 'expired', 'overstock')),
    alert_level VARCHAR(20) NOT NULL CHECK (alert_level IN ('info', 'warning', 'critical')),
    
    -- Datos del stock
    current_quantity INTEGER NOT NULL,
    threshold_quantity INTEGER,
    expiration_date DATE, -- Para alertas de vencimiento
    
    -- Estado de la alerta
    is_acknowledged BOOLEAN DEFAULT false,
    acknowledged_by INTEGER REFERENCES saas.authorized_users(id) ON DELETE SET NULL,
    acknowledged_at TIMESTAMP,
    
    -- Notificaciones
    notification_sent_at TIMESTAMP,
    notification_channels JSONB DEFAULT '[]', -- ['email', 'sms', 'webhook']
    
    -- Resolución
    is_resolved BOOLEAN DEFAULT false,
    resolved_at TIMESTAMP,
    resolved_by INTEGER REFERENCES saas.authorized_users(id) ON DELETE SET NULL,
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

-- =============================================================================
-- 📊 ÍNDICES OPTIMIZADOS PARA RENDIMIENTO (Multi-tenant)
-- =============================================================================

-- Índices para categories
CREATE INDEX IF NOT EXISTS idx_categories_org_active_sort ON stock.categories(organization_id, is_active, sort_order) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_categories_parent ON stock.categories(parent_id) WHERE parent_id IS NOT NULL;

-- Índices para products
CREATE INDEX IF NOT EXISTS idx_products_org_category_available ON stock.products(organization_id, category_id, is_available) WHERE is_available = true;
CREATE INDEX IF NOT EXISTS idx_products_org_stock_status ON stock.products(organization_id, stock_quantity, min_stock_alert) WHERE is_available = true;
CREATE INDEX IF NOT EXISTS idx_products_search_vector ON stock.products USING GIN(search_vector);
CREATE INDEX IF NOT EXISTS idx_products_org_barcode ON stock.products(organization_id, barcode) WHERE barcode IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_products_org_sku ON stock.products(organization_id, sku) WHERE sku IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_products_org_featured ON stock.products(organization_id, is_featured, popularity_score DESC) WHERE is_featured = true AND is_available = true;
CREATE INDEX IF NOT EXISTS idx_products_org_price_range ON stock.products(organization_id, price) WHERE is_available = true;
CREATE INDEX IF NOT EXISTS idx_products_org_brand ON stock.products(organization_id, brand) WHERE brand IS NOT NULL;

-- Índices para stock_movements
CREATE INDEX IF NOT EXISTS idx_stock_movements_org_product_date ON stock.stock_movements(organization_id, product_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_movements_org_type_date ON stock.stock_movements(organization_id, movement_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_movements_reference ON stock.stock_movements(reference_type, reference_id) WHERE reference_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_stock_movements_org_user ON stock.stock_movements(organization_id, user_id, created_at DESC) WHERE user_id IS NOT NULL;

-- Índices para suppliers
CREATE INDEX IF NOT EXISTS idx_suppliers_org_active ON stock.suppliers(organization_id, is_active, name) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_suppliers_org_rating ON stock.suppliers(organization_id, rating DESC) WHERE is_active = true;

-- Índices para purchase_orders
CREATE INDEX IF NOT EXISTS idx_purchase_orders_org_supplier_status ON stock.purchase_orders(organization_id, supplier_id, status, order_date DESC);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_org_status_date ON stock.purchase_orders(organization_id, status, order_date DESC);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_number ON stock.purchase_orders(order_number);

-- Índices para inventory_batches
CREATE INDEX IF NOT EXISTS idx_inventory_batches_org_product_expiry ON stock.inventory_batches(organization_id, product_id, expiration_date) WHERE is_active = true AND quantity_remaining > 0;
CREATE INDEX IF NOT EXISTS idx_inventory_batches_org_expiring ON stock.inventory_batches(organization_id, expiration_date) WHERE is_active = true AND quantity_remaining > 0 AND expiration_date IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_inventory_batches_org_batch_number ON stock.inventory_batches(organization_id, batch_number);

-- Índices para stock_alerts
CREATE INDEX IF NOT EXISTS idx_stock_alerts_org_product_unresolved ON stock.stock_alerts(organization_id, product_id, created_at DESC) WHERE NOT is_resolved;
CREATE INDEX IF NOT EXISTS idx_stock_alerts_org_type_level ON stock.stock_alerts(organization_id, alert_type, alert_level, created_at DESC) WHERE NOT is_resolved;

-- Índices para inventory_adjustments
CREATE INDEX IF NOT EXISTS idx_inventory_adjustments_org_product_id ON stock.inventory_adjustments(organization_id, product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_adjustments_org_type ON stock.inventory_adjustments(organization_id, adjustment_type);
CREATE INDEX IF NOT EXISTS idx_inventory_adjustments_org_created_at ON stock.inventory_adjustments(organization_id, created_at DESC);

-- =============================================================================
-- 🔧 FUNCIONES ESPECÍFICAS DEL SISTEMA DE STOCK (Multi-tenant)
-- =============================================================================

-- Función para actualizar stock de producto con validaciones (Multi-tenant)
CREATE OR REPLACE FUNCTION stock.update_product_stock(
    org_id INTEGER,
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
    WHERE id = product_id_param 
      AND organization_id = org_id 
      AND is_available = true;
    
    IF old_quantity IS NULL THEN
        RAISE EXCEPTION 'Producto con ID % no encontrado o no disponible para organización %', product_id_param, org_id;
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
    WHERE id = product_id_param 
      AND organization_id = org_id;
    
    -- Registrar movimiento si hay cambio
    IF quantity_diff != 0 THEN
        INSERT INTO stock.stock_movements (
            organization_id, product_id, movement_type, quantity_change,
            quantity_before, quantity_after, reason, 
            user_id, reference_type, reference_id
        ) VALUES (
            org_id, product_id_param, movement_type_val, ABS(quantity_diff),
            old_quantity, new_quantity, movement_reason, 
            user_id_param, reference_type_param, reference_id_param
        );
    END IF;
    
    -- Verificar alertas de stock
    PERFORM stock.check_stock_alerts(org_id, product_id_param);
    
    RETURN TRUE;
END;
$func$ LANGUAGE plpgsql;

-- Función para verificar y crear alertas de stock (Multi-tenant)
CREATE OR REPLACE FUNCTION stock.check_stock_alerts(org_id INTEGER, product_id_param INTEGER)
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
    WHERE id = product_id_param AND organization_id = org_id;
    
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
        WHERE organization_id = org_id
          AND product_id = product_id_param 
          AND alert_type IN ('low_stock', 'out_of_stock')
          AND NOT is_resolved;
        RETURN;
    END IF;
    
    -- Verificar si ya existe una alerta similar activa
    SELECT id INTO existing_alert_id
    FROM stock.stock_alerts
    WHERE organization_id = org_id
      AND product_id = product_id_param
      AND alert_type = alert_type_val
      AND NOT is_resolved
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF existing_alert_id IS NULL THEN
        -- Crear nueva alerta
        INSERT INTO stock.stock_alerts (
            organization_id, product_id, alert_type, alert_level,
            current_quantity, threshold_quantity
        ) VALUES (
            org_id, product_id_param, alert_type_val, alert_level_val,
            product_record.stock_quantity, product_record.min_stock_alert
        );
        
        -- También crear alerta en el sistema global
        INSERT INTO shared.system_alerts (
            organization_id, alert_type, title, message, severity,
            entity_type, entity_id, metadata
        ) VALUES (
            org_id,
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

-- Función