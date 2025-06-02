-- Nuevas tablas para gestión avanzada de inventario
CREATE TABLE IF NOT EXISTS inventory_adjustments (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id),
    adjustment_type VARCHAR(50) NOT NULL, -- 'restock', 'damage', 'theft', 'correction'
    quantity_change INTEGER NOT NULL,
    reason TEXT,
    cost_impact DECIMAL(10,2),
    created_by INTEGER REFERENCES admin_users(id),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS product_suppliers (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id),
    supplier_name VARCHAR(255) NOT NULL,
    supplier_contact VARCHAR(255),
    cost_price DECIMAL(10,2),
    lead_time_days INTEGER,
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS low_stock_alerts (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id),
    alert_level VARCHAR(20), -- 'warning', 'critical', 'out_of_stock'
    notification_sent BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_inventory_adjustments_product_id ON inventory_adjustments(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_adjustments_created_at ON inventory_adjustments(created_at);
CREATE INDEX IF NOT EXISTS idx_product_suppliers_product_id ON product_suppliers(product_id);
CREATE INDEX IF NOT EXISTS idx_low_stock_alerts_product_id ON low_stock_alerts(product_id);
CREATE INDEX IF NOT EXISTS idx_low_stock_alerts_notification_sent ON low_stock_alerts(notification_sent); 