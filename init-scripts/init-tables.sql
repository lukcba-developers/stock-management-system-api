-- Tabla de categorías
CREATE TABLE IF NOT EXISTS categories (
                            id SERIAL PRIMARY KEY,
                            name VARCHAR(100) NOT NULL UNIQUE,
                            description TEXT,
                            icon_emoji VARCHAR(10),
                            is_active BOOLEAN DEFAULT true,
                            sort_order INTEGER DEFAULT 0,
                            created_at TIMESTAMP DEFAULT NOW(),
                            updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TRIGGER update_categories_updated_at
    BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Tabla de productos
CREATE TABLE IF NOT EXISTS products (
                          id SERIAL PRIMARY KEY,
                          name VARCHAR(255) NOT NULL UNIQUE, -- Añadido UNIQUE para evitar duplicados por nombre
                          description TEXT,
                          price DECIMAL(10,2) NOT NULL,
                          original_price DECIMAL(10,2),
                          stock_quantity INTEGER DEFAULT 0,
                          min_stock_alert INTEGER DEFAULT 5,
                          category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
                          image_url VARCHAR(500),
                          barcode VARCHAR(100) UNIQUE, -- Añadido barcode
                          brand VARCHAR(100),
                          weight_unit VARCHAR(20),
                          weight_value DECIMAL(8,2),
                          is_available BOOLEAN DEFAULT true,
                          is_featured BOOLEAN DEFAULT false,
                          popularity_score INTEGER DEFAULT 0,
                          discount_percentage INTEGER DEFAULT 0,
                          meta_keywords TEXT,
                          search_vector TSVECTOR, -- Nueva columna para búsqueda full-text
                          created_at TIMESTAMP DEFAULT NOW(),
                          updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Función para actualizar search_vector en products
CREATE OR REPLACE FUNCTION update_products_search_vector()
RETURNS TRIGGER AS $$
BEGIN
   NEW.search_vector = to_tsvector('spanish', NEW.name || ' ' || COALESCE(NEW.description, '') || ' ' || COALESCE(NEW.meta_keywords, ''));
   RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER trg_update_products_search_vector
    BEFORE INSERT OR UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_products_search_vector();

-- Índices optimizados
CREATE INDEX idx_products_name_gin ON products USING gin(to_tsvector('spanish', name));
CREATE INDEX idx_products_available ON products(is_available, stock_quantity) WHERE stock_quantity > 0;
CREATE INDEX idx_products_category ON products(category_id) WHERE is_available = true;
CREATE INDEX idx_products_barcode ON products(barcode) WHERE barcode IS NOT NULL;

-- Nuevos índices solicitados
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_products_search_vector ON products USING GIN(search_vector);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_products_category_stock ON products(category_id, stock_quantity);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_products_price_range ON products(price) WHERE is_available = true;

-- Tabla de clientes
CREATE TABLE IF NOT EXISTS customers (
                           id SERIAL PRIMARY KEY,
                           phone VARCHAR(20) NOT NULL UNIQUE,
                           name VARCHAR(255),
                           email VARCHAR(255) UNIQUE, -- Añadido UNIQUE
                           default_address TEXT,
                           is_active BOOLEAN DEFAULT true,
                           total_orders INTEGER DEFAULT 0,
                           total_spent DECIMAL(12,2) DEFAULT 0,
                           loyalty_points INTEGER DEFAULT 0,
                           preferences_history JSONB DEFAULT '[]', -- Mejora Propuesta: MCP
                           purchase_patterns JSONB DEFAULT '[]',   -- Mejora Propuesta: MCP
                           customer_profile JSONB DEFAULT '{}',    -- Mejora Propuesta: MCP
                           created_at TIMESTAMP DEFAULT NOW(),
                           last_activity TIMESTAMP DEFAULT NOW(),
                           updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TRIGGER update_customers_updated_at
    BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Tabla de sesiones
CREATE TABLE IF NOT EXISTS customer_sessions (
                                   id SERIAL PRIMARY KEY,
                                   customer_phone VARCHAR(20) NOT NULL, -- No necesita FK a customers.phone directamente si se maneja por la app
                                   session_state VARCHAR(50) DEFAULT 'browsing',
                                   current_category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
                                   cart_data JSONB DEFAULT '[]',
                                   context_data JSONB DEFAULT '{}', -- Can store conversation_history, current_intent, pending_actions for MCP
                                   last_message_id VARCHAR(100),
                                   expires_at TIMESTAMP DEFAULT (NOW() + INTERVAL '2 hours'),
                                   created_at TIMESTAMP DEFAULT NOW(),
                                   updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TRIGGER update_sessions_updated_at
    BEFORE UPDATE ON customer_sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Tabla para rate limiting (message_logs de la guía original)
CREATE TABLE IF NOT EXISTS message_logs (
                              id SERIAL PRIMARY KEY,
                              customer_phone VARCHAR(20) NOT NULL,
                              message_timestamp TIMESTAMP DEFAULT NOW(),
                              message_type VARCHAR(20) DEFAULT 'incoming',
                              message_hash VARCHAR(32) UNIQUE, -- Mejora Propuesta: Flow 1
                              rate_limit_exceeded BOOLEAN DEFAULT FALSE, -- Mejora Propuesta: Flow 1
                              ip_address INET, -- Mejora Propuesta: Flow 1
                              user_agent TEXT, -- Mejora Propuesta: Flow 1
                              message_content TEXT -- Mejora Propuesta: Flow 1
);

CREATE INDEX idx_message_logs_phone_time ON message_logs(customer_phone, message_timestamp DESC);
CREATE INDEX idx_message_logs_hash ON message_logs(message_hash); -- Mejora Propuesta: Flow 1

-- Tabla de pedidos
CREATE TABLE IF NOT EXISTS orders (
                        id SERIAL PRIMARY KEY,
                        order_number VARCHAR(20) UNIQUE NOT NULL,
                        customer_phone VARCHAR(20) NOT NULL, -- No necesita FK a customers.phone directamente
                        customer_name VARCHAR(255),
                        delivery_address TEXT NOT NULL,
                        subtotal DECIMAL(10,2) NOT NULL,
                        delivery_fee DECIMAL(8,2) DEFAULT 0,
                        total_amount DECIMAL(10,2) NOT NULL,
                        payment_method VARCHAR(50) DEFAULT 'cash',
                        order_status VARCHAR(20) DEFAULT 'pending', -- e.g., pending, confirmed, preparing, dispatched, delivered, cancelled
                        created_at TIMESTAMP DEFAULT NOW(),
                        updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Tabla de items del pedido
CREATE TABLE IF NOT EXISTS order_items (
                             id SERIAL PRIMARY KEY,
                             order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
                             product_id INTEGER REFERENCES products(id) ON DELETE SET NULL, -- SET NULL para mantener el item si el producto se borra
                             product_name VARCHAR(255) NOT NULL, -- Snapshot del nombre
                             quantity INTEGER NOT NULL,
                             unit_price DECIMAL(10,2) NOT NULL,
                             total_price DECIMAL(10,2) NOT NULL
);

-- Tabla de logs de errores
CREATE TABLE IF NOT EXISTS error_logs (
                            id SERIAL PRIMARY KEY,
                            workflow_name VARCHAR(255),
                            node_name VARCHAR(255),
                            error_message TEXT,
                            created_at TIMESTAMP DEFAULT NOW()
);

-- Tabla para Event Sourcing (Mejora Propuesta)
CREATE TABLE IF NOT EXISTS events (
                        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
                        timestamp TIMESTAMPTZ DEFAULT NOW(),
                        aggregate_id VARCHAR(255),
                        event_type VARCHAR(100) NOT NULL,
                        payload JSONB,
                        metadata JSONB
);
CREATE INDEX idx_events_aggregate_id ON events(aggregate_id);
CREATE INDEX idx_events_event_type ON events(event_type);

-- Tabla para AI Response Cache (Opcional, si no se usa Redis exclusivamente)
CREATE TABLE IF NOT EXISTS ai_response_cache (
                                   cache_key VARCHAR(255) PRIMARY KEY,
                                   response_data JSONB NOT NULL,
                                   model_used VARCHAR(100),
                                   intent VARCHAR(100),
                                   hit_count INTEGER DEFAULT 0,
                                   is_valid BOOLEAN DEFAULT TRUE,
                                   created_at TIMESTAMP DEFAULT NOW(),
                                   last_accessed TIMESTAMP DEFAULT NOW()
);
