-- ============================================================================
-- 🤝 SHARED SCHEMA - TABLAS COMPARTIDAS ENTRE COMPONENTES
-- ============================================================================
-- Archivo: init-scripts/02_shared_tables.sql
-- Propósito: Tablas compartidas entre Stock Management y N8N (órdenes, sesiones, etc.)
-- Dependencias: 00_core_schema.sql, 01_stock_management.sql
-- Orden de ejecución: TERCERO (02_)
-- ============================================================================

-- 👥 CLIENTES (usado por N8N y Stock Management)
CREATE TABLE IF NOT EXISTS shared.customers (
    id SERIAL PRIMARY KEY,
    phone VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(255),
    email VARCHAR(255) UNIQUE,
    
    -- Información personal
    date_of_birth DATE,
    gender VARCHAR(10) CHECK (gender IN ('male', 'female', 'other', 'prefer_not_to_say')),
    
    -- Direcciones (JSONB para flexibilidad)
    addresses JSONB DEFAULT '[]', -- Array de direcciones
    default_address_id INTEGER, -- ID de la dirección por defecto
    
    -- Configuraciones
    language_preference VARCHAR(10) DEFAULT 'es',
    timezone VARCHAR(50) DEFAULT 'America/Argentina/Buenos_Aires',
    notification_preferences JSONB DEFAULT '{"email": true, "sms": true, "whatsapp": true}',
    
    -- Estado del cliente
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    verification_method VARCHAR(20), -- 'email', 'phone', 'manual'
    verified_at TIMESTAMP,
    
    -- Estadísticas de compras
    total_orders INTEGER DEFAULT 0,
    total_spent DECIMAL(12,2) DEFAULT 0,
    average_order_value DECIMAL(12,2) DEFAULT 0,
    last_order_date TIMESTAMP,
    
    -- Sistema de fidelización
    loyalty_points INTEGER DEFAULT 0,
    loyalty_tier VARCHAR(20) DEFAULT 'bronze' CHECK (loyalty_tier IN ('bronze', 'silver', 'gold', 'platinum')),
    
    -- Preferencias de compra (para recomendaciones)
    favorite_categories JSONB DEFAULT '[]',
    purchase_patterns JSONB DEFAULT '{}',
    dietary_restrictions JSONB DEFAULT '[]',
    
    -- Datos de comportamiento (para N8N)
    last_interaction_channel VARCHAR(20), -- 'whatsapp', 'web', 'phone'
    interaction_count INTEGER DEFAULT 0,
    preferred_contact_time TIME,
    
    -- Auditoría
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    last_activity TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en customers
CREATE TRIGGER update_customers_updated_at
    BEFORE UPDATE ON shared.customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 📱 SESIONES DE CLIENTES (para N8N WhatsApp)
CREATE TABLE IF NOT EXISTS shared.customer_sessions (
    id SERIAL PRIMARY KEY,
    customer_phone VARCHAR(20) NOT NULL,
    customer_id INTEGER REFERENCES shared.customers(phone) MATCH SIMPLE ON UPDATE CASCADE,
    
    -- Estado de la sesión
    session_state session_state_enum DEFAULT 'browsing',
    current_category_id INTEGER REFERENCES stock.categories(id) ON DELETE SET NULL,
    current_product_id INTEGER REFERENCES stock.products(id) ON DELETE SET NULL,
    
    -- Datos de la sesión
    cart_data JSONB DEFAULT '[]',
    context_data JSONB DEFAULT '{}', -- Historial de conversación, intents, etc.
    preferences JSONB DEFAULT '{}', -- Preferencias temporales de la sesión
    
    -- Información de la conversación
    last_message_id VARCHAR(100),
    last_intent VARCHAR(50),
    intent_confidence DECIMAL(3,2),
    conversation_turns INTEGER DEFAULT 0,
    
    -- AI y personalización
    ai_provider_used VARCHAR(50),
    personalization_data JSONB DEFAULT '{}',
    suggested_products JSONB DEFAULT '[]',
    
    -- Control de tiempo
    expires_at TIMESTAMP DEFAULT (NOW() + INTERVAL '2 hours'),
    last_activity TIMESTAMP DEFAULT NOW(),
    session_duration_seconds INTEGER DEFAULT 0,
    
    -- Metadata
    user_agent TEXT,
    ip_address INET,
    device_info JSONB DEFAULT '{}',
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(customer_phone)
);

-- Trigger para updated_at en customer_sessions
CREATE TRIGGER update_customer_sessions_updated_at
    BEFORE UPDATE ON shared.customer_sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 🛒 ÓRDENES (compartidas entre N8N y Stock Management)
CREATE TABLE IF NOT EXISTS shared.orders (
    id SERIAL PRIMARY KEY,
    order_number VARCHAR(50) NOT NULL UNIQUE DEFAULT generate_order_number('ORD'),
    
    -- Información del cliente
    customer_phone VARCHAR(20) NOT NULL,
    customer_id INTEGER REFERENCES shared.customers(id) ON DELETE SET NULL,
    customer_name VARCHAR(255),
    customer_email VARCHAR(255),
    
    -- Dirección de entrega
    delivery_address JSONB NOT NULL, -- {street, number, city, state, postal_code, notes}
    delivery_coordinates POINT, -- Para optimización de rutas
    delivery_zone VARCHAR(50),
    
    -- Montos
    subtotal DECIMAL(12,2) NOT NULL DEFAULT 0,
    delivery_fee DECIMAL(12,2) DEFAULT 0,
    service_fee DECIMAL(12,2) DEFAULT 0,
    discount_amount DECIMAL(12,2) DEFAULT 0,
    tax_amount DECIMAL(12,2) DEFAULT 0,
    tip_amount DECIMAL(12,2) DEFAULT 0,
    total_amount DECIMAL(12,2) NOT NULL,
    
    -- Estados
    order_status order_status_enum DEFAULT 'pending',
    payment_status payment_status_enum DEFAULT 'pending',
    
    -- Información de pago
    payment_method VARCHAR(50), -- 'cash', 'card', 'transfer', 'credit'
    payment_reference VARCHAR(100),
    payment_metadata JSONB DEFAULT '{}',
    
    -- Origen y canal
    source VARCHAR(20) DEFAULT 'whatsapp' CHECK (source IN ('whatsapp', 'web', 'phone', 'api')),
    channel_metadata JSONB DEFAULT '{}',
    
    -- Tiempos de entrega
    estimated_delivery_time TIMESTAMP,
    requested_delivery_time TIMESTAMP,
    actual_delivery_time TIMESTAMP,
    preparation_time_minutes INTEGER,
    delivery_time_minutes INTEGER,
    
    -- Información adicional
    notes TEXT,
    special_instructions TEXT,
    customer_rating INTEGER CHECK (customer_rating >= 1 AND customer_rating <= 5),
    customer_feedback TEXT,
    
    -- Logística
    delivery_driver_id INTEGER,
    delivery_route_id INTEGER,
    tracking_number VARCHAR(100),
    
    -- Promociones y descuentos
    promo_code VARCHAR(50),
    discount_type VARCHAR(30), -- 'percentage', 'fixed_amount', 'free_delivery'
    loyalty_points_used INTEGER DEFAULT 0,
    loyalty_points_earned INTEGER DEFAULT 0,
    
    -- Auditoría
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    cancelled_at TIMESTAMP,
    cancellation_reason TEXT
);

-- Trigger para updated_at en orders
CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON shared.orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 📝 ITEMS DE ÓRDENES
CREATE TABLE IF NOT EXISTS shared.order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES shared.orders(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES stock.products(id) ON DELETE SET NULL,
    
    -- Snapshot del producto (para mantener histórico)
    product_name VARCHAR(255) NOT NULL,
    product_sku VARCHAR(100),
    product_image_url VARCHAR(500),
    product_category VARCHAR(100),
    
    -- Cantidades y precios
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(12,2) NOT NULL CHECK (unit_price >= 0),
    total_price DECIMAL(12,2) NOT NULL CHECK (total_price >= 0),
    
    -- Descuentos específicos del item
    discount_percentage DECIMAL(5,2) DEFAULT 0,
    discount_amount DECIMAL(12,2) DEFAULT 0,
    
    -- Información adicional
    special_instructions TEXT,
    substitution_allowed BOOLEAN DEFAULT true,
    substitution_preference TEXT,
    
    -- Estado del item
    item_status VARCHAR(30) DEFAULT 'pending' CHECK (item_status IN ('pending', 'confirmed', 'preparing', 'packed', 'out_of_stock', 'substituted', 'cancelled')),
    
    -- Información de sustitución
    substituted_product_id INTEGER REFERENCES stock.products(id) ON DELETE SET NULL,
    substitution_reason TEXT,
    substitution_approved_by_customer BOOLEAN,
    
    -- Lote y trazabilidad
    batch_number VARCHAR(100),
    expiration_date DATE,
    
    created_at TIMESTAMP DEFAULT NOW()
);

-- 💬 LOGS DE MENSAJES (para rate limiting y auditoría)
CREATE TABLE IF NOT EXISTS shared.message_logs (
    id SERIAL PRIMARY KEY,
    
    -- Identificación
    customer_phone VARCHAR(20) NOT NULL,
    customer_id INTEGER REFERENCES shared.customers(id) ON DELETE SET NULL,
    message_id VARCHAR(100) UNIQUE, -- ID del mensaje de WhatsApp
    
    -- Contenido del mensaje
    message_type VARCHAR(30) NOT NULL CHECK (message_type IN ('text', 'image', 'audio', 'video', 'document', 'location', 'contact', 'interactive', 'button', 'list')),
    message_content TEXT,
    message_metadata JSONB DEFAULT '{}',
    
    -- Dirección del mensaje
    direction VARCHAR(10) NOT NULL CHECK (direction IN ('inbound', 'outbound')),
    
    -- Procesamiento
    message_hash VARCHAR(64) UNIQUE,
    rate_limit_exceeded BOOLEAN DEFAULT FALSE,
    processing_status VARCHAR(20) DEFAULT 'pending' CHECK (processing_status IN ('pending', 'processing', 'completed', 'failed', 'skipped')),
    processing_error TEXT,
    processing_time_ms INTEGER,
    
    -- AI y análisis
    intent_detected VARCHAR(50),
    intent_confidence DECIMAL(3,2),
    sentiment_score DECIMAL(3,2), -- -1 a 1
    ai_provider_used VARCHAR(50),
    entities_extracted JSONB DEFAULT '{}',
    
    -- Contexto de la conversación
    conversation_id VARCHAR(100),
    turn_number INTEGER,
    response_generated BOOLEAN DEFAULT FALSE,
    response_time_ms INTEGER,
    
    -- Información técnica
    ip_address INET,
    user_agent TEXT,
    webhook_source VARCHAR(50),
    
    -- Timestamps
    message_timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 🔄 WEBHOOKS Y INTEGRACIONES
CREATE TABLE IF NOT EXISTS shared.webhook_logs (
    id SERIAL PRIMARY KEY,
    
    -- Información del webhook
    webhook_type VARCHAR(50) NOT NULL, -- 'whatsapp', 'payment', 'delivery', 'stock'
    source_system VARCHAR(50) NOT NULL,
    endpoint_path VARCHAR(255),
    
    -- Request data
    request_method VARCHAR(10) NOT NULL,
    request_headers JSONB,
    request_body JSONB,
    request_ip INET,
    
    -- Response data
    response_status INTEGER,
    response_headers JSONB,
    response_body JSONB,
    response_time_ms INTEGER,
    
    -- Processing
    processing_status VARCHAR(20) DEFAULT 'received' CHECK (processing_status IN ('received', 'processing', 'completed', 'failed', 'retry')),
    processing_attempts INTEGER DEFAULT 0,
    processing_error TEXT,
    retry_at TIMESTAMP,
    
    -- Metadata
    correlation_id VARCHAR(100),
    idempotency_key VARCHAR(100),
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en webhook_logs
CREATE TRIGGER update_webhook_logs_updated_at
    BEFORE UPDATE ON shared.webhook_logs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 📊 EVENTOS DEL SISTEMA (Event Sourcing)
CREATE TABLE IF NOT EXISTS shared.system_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Identificación del evento
    event_type VARCHAR(100) NOT NULL,
    event_version INTEGER DEFAULT 1,
    aggregate_type VARCHAR(50) NOT NULL, -- 'order', 'customer', 'product', 'session'
    aggregate_id VARCHAR(100) NOT NULL,
    
    -- Datos del evento
    event_data JSONB NOT NULL,
    metadata JSONB DEFAULT '{}',
    
    -- Contexto
    user_id INTEGER,
    session_id VARCHAR(100),
    correlation_id VARCHAR(100),
    causation_id UUID, -- ID del evento que causó este evento
    
    -- Información técnica
    source_system VARCHAR(50) DEFAULT 'stock_management',
    ip_address INET,
    user_agent TEXT,
    
    -- Timestamp
    event_timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

-- 💳 PAGOS Y TRANSACCIONES
CREATE TABLE IF NOT EXISTS shared.payments (
    id SERIAL PRIMARY KEY,
    
    -- Relación con orden
    order_id INTEGER NOT NULL REFERENCES shared.orders(id) ON DELETE CASCADE,
    payment_number VARCHAR(50) UNIQUE NOT NULL DEFAULT generate_order_number('PAY'),
    
    -- Información del pago
    payment_method VARCHAR(50) NOT NULL, -- 'cash', 'card', 'transfer', 'mercadopago', 'stripe'
    payment_provider VARCHAR(50), -- 'mercadopago', 'stripe', 'manual'
    provider_payment_id VARCHAR(100),
    
    -- Montos
    amount DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    currency VARCHAR(3) DEFAULT 'ARS',
    exchange_rate DECIMAL(10,4) DEFAULT 1,
    amount_in_base_currency DECIMAL(12,2),
    
    -- Estado
    payment_status VARCHAR(30) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'processing', 'completed', 'failed', 'cancelled', 'refunded', 'partially_refunded')),
    
    -- Información de la transacción
    transaction_id VARCHAR(100),
    authorization_code VARCHAR(100),
    reference_number VARCHAR(100),
    
    -- Detalles de tarjeta (si aplica)
    card_last_four VARCHAR(4),
    card_brand VARCHAR(20),
    card_type VARCHAR(20), -- 'credit', 'debit'
    
    -- Información de procesamiento
    processing_fee DECIMAL(8,2) DEFAULT 0,
    gateway_response JSONB,
    failure_reason TEXT,
    failure_code VARCHAR(50),
    
    -- Reembolsos
    refunded_amount DECIMAL(12,2) DEFAULT 0,
    refund_reason TEXT,
    
    -- Timestamps
    paid_at TIMESTAMP,
    failed_at TIMESTAMP,
    refunded_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en payments
CREATE TRIGGER update_payments_updated_at
    BEFORE UPDATE ON shared.payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 📦 ENTREGAS Y LOGÍSTICA
CREATE TABLE IF NOT EXISTS shared.deliveries (
    id SERIAL PRIMARY KEY,
    
    -- Relación con orden
    order_id INTEGER NOT NULL REFERENCES shared.orders(id) ON DELETE CASCADE,
    delivery_number VARCHAR(50) UNIQUE NOT NULL DEFAULT generate_order_number('DEL'),
    
    -- Información del delivery
    delivery_method VARCHAR(30) DEFAULT 'home_delivery' CHECK (delivery_method IN ('home_delivery', 'pickup', 'express', 'scheduled')),
    delivery_zone VARCHAR(50),
    
    -- Dirección de entrega
    delivery_address JSONB NOT NULL,
    delivery_coordinates POINT,
    delivery_instructions TEXT,
    
    -- Driver y vehículo
    driver_id INTEGER,
    driver_name VARCHAR(255),
    driver_phone VARCHAR(20),
    vehicle_info JSONB,
    
    -- Estado de la entrega
    delivery_status VARCHAR(30) DEFAULT 'pending' CHECK (delivery_status IN ('pending', 'assigned', 'picked_up', 'in_transit', 'delivered', 'failed', 'returned')),
    
    -- Tiempos
    estimated_pickup_time TIMESTAMP,
    actual_pickup_time TIMESTAMP,
    estimated_delivery_time TIMESTAMP,
    actual_delivery_time TIMESTAMP,
    
    -- Tracking
    tracking_number VARCHAR(100) UNIQUE,
    tracking_url VARCHAR(500),
    gps_coordinates JSONB DEFAULT '[]', -- Array de coordenadas para tracking
    
    -- Información de entrega
    delivered_to VARCHAR(255), -- Nombre de quien recibió
    delivery_photo_url VARCHAR(500),
    customer_signature_url VARCHAR(500),
    delivery_notes TEXT,
    
    -- Problemas y resolución
    delivery_attempts INTEGER DEFAULT 0,
    failed_delivery_reason TEXT,
    rescheduled_to TIMESTAMP,
    
    -- Costos
    delivery_cost DECIMAL(8,2),
    driver_payment DECIMAL(8,2),
    fuel_cost DECIMAL(8,2),
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en deliveries
CREATE TRIGGER update_deliveries_updated_at
    BEFORE UPDATE ON shared.deliveries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- 📊 ÍNDICES OPTIMIZADOS PARA RENDIMIENTO
-- =============================================================================

-- Índices para customers
CREATE INDEX IF NOT EXISTS idx_customers_phone ON shared.customers(phone);
CREATE INDEX IF NOT EXISTS idx_customers_email ON shared.customers(email) WHERE email IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_customers_active ON shared.customers(is_active, loyalty_tier) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_customers_loyalty ON shared.customers(loyalty_tier, loyalty_points DESC);
CREATE INDEX IF NOT EXISTS idx_customers_last_order ON shared.customers(last_order_date DESC) WHERE last_order_date IS NOT NULL;

-- Índices para customer_sessions
CREATE INDEX IF NOT EXISTS idx_customer_sessions_phone ON shared.customer_sessions(customer_phone);
CREATE INDEX IF NOT EXISTS idx_customer_sessions_expires ON shared.customer_sessions(expires_at) WHERE expires_at > NOW();
CREATE INDEX IF NOT EXISTS idx_customer_sessions_state ON shared.customer_sessions(session_state, last_activity DESC);
CREATE INDEX IF NOT EXISTS idx_customer_sessions_activity ON shared.customer_sessions(last_activity DESC);

-- Índices para orders
CREATE INDEX IF NOT EXISTS idx_orders_customer_phone ON shared.orders(customer_phone, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_status_date ON shared.orders(order_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON shared.orders(payment_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_number ON shared.orders(order_number);
CREATE INDEX IF NOT EXISTS idx_orders_source ON shared.orders(source, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_delivery_zone ON shared.orders(delivery_zone, created_at DESC) WHERE delivery_zone IS NOT NULL;

-- Índices para order_items
CREATE INDEX IF NOT EXISTS idx_order_items_order ON shared.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product ON shared.order_items(product_id, created_at DESC) WHERE product_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_order_items_status ON shared.order_items(item_status, created_at DESC);

-- Índices para message_logs
CREATE INDEX IF NOT EXISTS idx_message_logs_phone_time ON shared.message_logs(customer_phone, message_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_message_logs_hash ON shared.message_logs(message_hash) WHERE message_hash IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_message_logs_processing ON shared.message_logs(processing_status, created_at DESC) WHERE processing_status != 'completed';
CREATE INDEX IF NOT EXISTS idx_message_logs_intent ON shared.message_logs(intent_detected, intent_confidence DESC) WHERE intent_detected IS NOT NULL;

-- Índices para webhook_logs
CREATE INDEX IF NOT EXISTS idx_webhook_logs_type_status ON shared.webhook_logs(webhook_type, processing_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_webhook_logs_correlation ON shared.webhook_logs(correlation_id) WHERE correlation_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_webhook_logs_retry ON shared.webhook_logs(retry_at) WHERE retry_at IS NOT NULL AND retry_at <= NOW();

-- Índices para system_events
CREATE INDEX IF NOT EXISTS idx_system_events_aggregate ON shared.system_events(aggregate_type, aggregate_id, event_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_system_events_type_time ON shared.system_events(event_type, event_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_system_events_correlation ON shared.system_events(correlation_id) WHERE correlation_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_system_events_causation ON shared.system_events(causation_id) WHERE causation_id IS NOT NULL;

-- Índices para payments
CREATE INDEX IF NOT EXISTS idx_payments_order ON shared.payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_status_date ON shared.payments(payment_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_provider ON shared.payments(payment_provider, provider_payment_id) WHERE payment_provider IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_payments_transaction ON shared.payments(transaction_id) WHERE transaction_id IS NOT NULL;

-- Índices para deliveries
CREATE INDEX IF NOT EXISTS idx_deliveries_order ON shared.deliveries(order_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_status_date ON shared.deliveries(delivery_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_deliveries_driver ON shared.deliveries(driver_id, created_at DESC) WHERE driver_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_deliveries_zone ON shared.deliveries(delivery_zone, delivery_status) WHERE delivery_zone IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_deliveries_tracking ON shared.deliveries(tracking_number) WHERE tracking_number IS NOT NULL;

-- =============================================================================
-- 🔧 FUNCIONES ESPECÍFICAS PARA SHARED SCHEMA
-- =============================================================================

-- Función optimizada para obtener sesión con contexto completo
CREATE OR REPLACE FUNCTION shared.get_session_with_context(customer_phone_param VARCHAR)
RETURNS TABLE (
    session_data JSONB,
    customer_data JSONB,
    recent_orders JSONB,
    interaction_history JSONB
) AS $
DECLARE
    v_session_data JSONB;
    v_customer_data JSONB;
    v_recent_orders JSONB;
    v_interaction_history JSONB;
BEGIN
    -- Obtener sesión activa
    SELECT to_jsonb(cs.*) INTO v_session_data
    FROM shared.customer_sessions cs
    WHERE cs.customer_phone = customer_phone_param
      AND cs.expires_at > NOW()
    ORDER BY cs.updated_at DESC
    LIMIT 1;

    -- Obtener datos del cliente
    SELECT to_jsonb(c.*) INTO v_customer_data
    FROM shared.customers c
    WHERE c.phone = customer_phone_param;

    -- Obtener órdenes recientes (últimas 5)
    SELECT jsonb_agg(order_data.*)
    INTO v_recent_orders
    FROM (
        SELECT 
            o.id, o.order_number, o.total_amount, o.order_status, 
            o.created_at, o.estimated_delivery_time,
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'product_name', oi.product_name,
                        'quantity', oi.quantity,
                        'unit_price', oi.unit_price
                    )
                )
                FROM shared.order_items oi 
                WHERE oi.order_id = o.id
            ) as items
        FROM shared.orders o
        WHERE o.customer_phone = customer_phone_param
        ORDER BY o.created_at DESC
        LIMIT 5
    ) order_data;

    -- Obtener historial de interacciones recientes
    SELECT jsonb_agg(msg_data.*)
    INTO v_interaction_history
    FROM (
        SELECT 
            ml.message_type, ml.intent_detected, ml.sentiment_score,
            ml.message_timestamp, ml.direction
        FROM shared.message_logs ml
        WHERE ml.customer_phone = customer_phone_param
          AND ml.message_timestamp > NOW() - INTERVAL '7 days'
        ORDER BY ml.message_timestamp DESC
        LIMIT 20
    ) msg_data;

    RETURN QUERY SELECT
        COALESCE(v_session_data, '{}'::jsonb),
        COALESCE(v_customer_data, '{}'::jsonb),
        COALESCE(v_recent_orders, '[]'::jsonb),
        COALESCE(v_interaction_history, '[]'::jsonb);
END;
$ LANGUAGE plpgsql;

-- Función para registrar evento del sistema
CREATE OR REPLACE FUNCTION shared.log_system_event(
    event_type_param VARCHAR,
    aggregate_type_param VARCHAR,
    aggregate_id_param VARCHAR,
    event_data_param JSONB,
    user_id_param INTEGER DEFAULT NULL,
    session_id_param VARCHAR DEFAULT NULL,
    source_system_param VARCHAR DEFAULT 'stock_management'
) RETURNS UUID AS $
DECLARE
    event_id UUID;
BEGIN
    INSERT INTO shared.system_events (
        event_type, aggregate_type, aggregate_id, event_data,
        user_id, session_id, source_system
    ) VALUES (
        event_type_param, aggregate_type_param, aggregate_id_param, event_data_param,
        user_id_param, session_id_param, source_system_param
    ) RETURNING id INTO event_id;
    
    RETURN event_id;
END;
$ LANGUAGE plpgsql;

-- Función para actualizar estadísticas del cliente
CREATE OR REPLACE FUNCTION shared.update_customer_stats(customer_phone_param VARCHAR)
RETURNS VOID AS $
DECLARE
    order_stats RECORD;
BEGIN
    -- Calcular estadísticas de órdenes
    SELECT 
        COUNT(*) as total_orders,
        COALESCE(SUM(total_amount), 0) as total_spent,
        COALESCE(AVG(total_amount), 0) as average_order_value,
        MAX(created_at) as last_order_date
    INTO order_stats
    FROM shared.orders
    WHERE customer_phone = customer_phone_param
      AND order_status IN ('completed', 'delivered');
    
    -- Actualizar estadísticas del cliente
    UPDATE shared.customers
    SET 
        total_orders = order_stats.total_orders,
        total_spent = order_stats.total_spent,
        average_order_value = order_stats.average_order_value,
        last_order_date = order_stats.last_order_date,
        -- Actualizar tier de lealtad basado en total gastado
        loyalty_tier = CASE 
            WHEN order_stats.total_spent >= 50000 THEN 'platinum'
            WHEN order_stats.total_spent >= 25000 THEN 'gold'
            WHEN order_stats.total_spent >= 10000 THEN 'silver'
            ELSE 'bronze'
        END,
        updated_at = NOW()
    WHERE phone = customer_phone_param;
    
    -- Log del evento
    PERFORM shared.log_system_event(
        'customer_stats_updated',
        'customer',
        customer_phone_param,
        jsonb_build_object(
            'total_orders', order_stats.total_orders,
            'total_spent', order_stats.total_spent,
            'average_order_value', order_stats.average_order_value
        )
    );
END;
$ LANGUAGE plpgsql;

-- Función para limpiar sesiones expiradas
CREATE OR REPLACE FUNCTION shared.cleanup_expired_sessions()
RETURNS INTEGER AS $
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM shared.customer_sessions
    WHERE expires_at < NOW() - INTERVAL '1 day';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Log del cleanup
    PERFORM shared.log_system_event(
        'expired_sessions_cleaned',
        'system',
        'cleanup',
        jsonb_build_object('deleted_sessions', deleted_count),
        NULL,
        NULL,
        'system'
    );
    
    RETURN deleted_count;
END;
$ LANGUAGE plpgsql;

-- =============================================================================
-- 📊 VISTAS PARA REPORTES Y ANÁLISIS
-- =============================================================================

-- Vista para estadísticas de órdenes
CREATE OR REPLACE VIEW shared.order_statistics AS
SELECT 
    DATE(created_at) as order_date,
    COUNT(*) as total_orders,
    COUNT(*) FILTER (WHERE order_status = 'delivered') as completed_orders,
    COUNT(*) FILTER (WHERE order_status = 'cancelled') as cancelled_orders,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as average_order_value,
    SUM(total_amount) FILTER (WHERE order_status = 'delivered') as completed_revenue,
    COUNT(DISTINCT customer_phone) as unique_customers,
    source
FROM shared.orders
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(created_at), source
ORDER BY order_date DESC, source;

-- Vista para análisis de clientes
CREATE OR REPLACE VIEW shared.customer_analytics AS
SELECT 
    c.*,
    COALESCE(os.order_count, 0) as order_count_30d,
    COALESCE(os.revenue_30d, 0) as revenue_30d,
    COALESCE(ms.message_count, 0) as message_count_30d,
    COALESCE(ms.last_interaction, c.last_activity) as last_interaction_date,
    CASE 
        WHEN c.last_activity > NOW() - INTERVAL '7 days' THEN 'active'
        WHEN c.last_activity > NOW() - INTERVAL '30 days' THEN 'inactive'
        ELSE 'dormant'
    END as customer_status
FROM shared.customers c
LEFT JOIN (
    SELECT 
        customer_phone,
        COUNT(*) as order_count,
        SUM(total_amount) as revenue_30d
    FROM shared.orders
    WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY customer_phone
) os ON c.phone = os.customer_phone
LEFT JOIN (
    SELECT 
        customer_phone,
        COUNT(*) as message_count,
        MAX(message_timestamp) as last_interaction
    FROM shared.message_logs
    WHERE message_timestamp >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY customer_phone
) ms ON c.phone = ms.customer_phone;

-- ✅ VERIFICACIÓN DE INSTALACIÓN
DO $
BEGIN
    RAISE NOTICE '✅ Shared Schema instalado correctamente';
    RAISE NOTICE '👥 Tablas de clientes y sesiones creadas';
    RAISE NOTICE '🛒 Sistema de órdenes completo implementado';
    RAISE NOTICE '💬 Logs de mensajes y webhooks configurados';
    RAISE NOTICE '📊 Vistas de análisis y funciones optimizadas disponibles';
END $;
    