-- ============================================================================
-- 🔧 MISSING CRITICAL TABLES - Elementos Críticos Faltantes
-- ============================================================================
-- Archivo: init-scripts/04_missing_critical_tables.sql
-- Propósito: Tablas críticas que faltaron en la migración inicial
-- Dependencias: 00_core_schema.sql, 01_stock_management.sql, 02_shared_tables.sql
-- Orden de ejecución: CUARTO (04_)
-- ============================================================================

-- 📊 AJUSTES DE INVENTARIO (CRÍTICO para Stock Management)
CREATE TABLE IF NOT EXISTS stock.inventory_adjustments (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES stock.products(id) ON DELETE SET NULL,
    adjustment_type VARCHAR(50) NOT NULL CHECK (adjustment_type IN ('restock', 'damage', 'theft', 'correction', 'expired', 'returned', 'found', 'initial_stock')),
    quantity_change INTEGER NOT NULL,
    quantity_before INTEGER NOT NULL,
    quantity_after INTEGER NOT NULL,
    reason TEXT NOT NULL,
    cost_impact DECIMAL(12,2) DEFAULT 0,
    supporting_documentation JSONB DEFAULT '[]', -- URLs de documentos de soporte
    batch_number VARCHAR(100),
    created_by INTEGER REFERENCES stock.admin_users(id) ON DELETE SET NULL,
    approved_by INTEGER REFERENCES stock.admin_users(id) ON DELETE SET NULL,
    approval_required BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Índices para inventory_adjustments
CREATE INDEX IF NOT EXISTS idx_inventory_adjustments_product_id ON stock.inventory_adjustments(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_adjustments_type ON stock.inventory_adjustments(adjustment_type);
CREATE INDEX IF NOT EXISTS idx_inventory_adjustments_created_at ON stock.inventory_adjustments(created_at DESC);

-- 📅 EVENT SOURCING (CRÍTICO para N8N y auditoría)
CREATE TABLE IF NOT EXISTS shared.events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    aggregate_id VARCHAR(255) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    aggregate_type VARCHAR(50) NOT NULL, -- 'order', 'customer', 'product', 'session'
    event_version INTEGER DEFAULT 1,
    payload JSONB NOT NULL,
    metadata JSONB DEFAULT '{}',
    
    -- Contexto del evento
    user_id INTEGER,
    session_id VARCHAR(100),
    correlation_id VARCHAR(100),
    causation_id UUID, -- ID del evento que causó este evento
    
    -- Información técnica
    source_system VARCHAR(50) DEFAULT 'stock_management',
    ip_address INET,
    user_agent TEXT
);

-- Índices para events
CREATE INDEX IF NOT EXISTS idx_events_aggregate_id ON shared.events(aggregate_id);
CREATE INDEX IF NOT EXISTS idx_events_aggregate_type ON shared.events(aggregate_type, aggregate_id);
CREATE INDEX IF NOT EXISTS idx_events_event_type ON shared.events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_timestamp ON shared.events(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_events_correlation_id ON shared.events(correlation_id) WHERE correlation_id IS NOT NULL;

-- 🤖 CACHÉ DE RESPUESTAS DE IA (CRÍTICO para N8N performance)
CREATE TABLE IF NOT EXISTS shared.ai_response_cache (
    cache_key VARCHAR(255) PRIMARY KEY,
    response_data JSONB NOT NULL,
    model_used VARCHAR(100),
    intent VARCHAR(100),
    message_hash VARCHAR(64),
    hit_count INTEGER DEFAULT 0,
    is_valid BOOLEAN DEFAULT TRUE,
    confidence_score DECIMAL(3,2),
    processing_time_ms INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    last_accessed TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP DEFAULT (NOW() + INTERVAL '24 hours')
);

-- Índices para ai_response_cache
CREATE INDEX IF NOT EXISTS idx_ai_cache_message_hash ON shared.ai_response_cache(message_hash) WHERE message_hash IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ai_cache_intent ON shared.ai_response_cache(intent) WHERE intent IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ai_cache_expires_at ON shared.ai_response_cache(expires_at);
CREATE INDEX IF NOT EXISTS idx_ai_cache_last_accessed ON shared.ai_response_cache(last_accessed DESC);

-- 🔄 FUNCIONES PARA NÚMERO DE ORDEN DE COMPRA
-- Secuencia para órdenes de compra
CREATE SEQUENCE IF NOT EXISTS stock.purchase_order_seq START 1;

-- Función para generar número de orden de compra
CREATE OR REPLACE FUNCTION stock.generate_purchase_order_number()
RETURNS TRIGGER AS $$
DECLARE
    next_val BIGINT;
BEGIN
    SELECT nextval('stock.purchase_order_seq') INTO next_val;
    NEW.order_number := 'PO-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(next_val::TEXT, 5, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para generar número de orden automático
CREATE TRIGGER trg_generate_po_number
    BEFORE INSERT ON stock.purchase_orders
    FOR EACH ROW
    WHEN (NEW.order_number IS NULL OR NEW.order_number = '')
    EXECUTE FUNCTION stock.generate_purchase_order_number();

-- 🎯 FUNCIÓN PARA REGISTRAR EVENTOS DEL SISTEMA
CREATE OR REPLACE FUNCTION shared.log_system_event(
    event_type_param VARCHAR,
    aggregate_type_param VARCHAR,
    aggregate_id_param VARCHAR,
    payload_param JSONB,
    user_id_param INTEGER DEFAULT NULL,
    session_id_param VARCHAR DEFAULT NULL,
    source_system_param VARCHAR DEFAULT 'stock_management'
) RETURNS UUID AS $$
DECLARE
    event_id UUID;
BEGIN
    INSERT INTO shared.events (
        event_type, aggregate_type, aggregate_id, payload,
        user_id, session_id, source_system
    ) VALUES (
        event_type_param, aggregate_type_param, aggregate_id_param, payload_param,
        user_id_param, session_id_param, source_system_param
    ) RETURNING id INTO event_id;
    
    RETURN event_id;
END;
$$ LANGUAGE plpgsql;

-- 🧹 FUNCIÓN PARA LIMPIAR CACHÉ EXPIRADO
CREATE OR REPLACE FUNCTION shared.cleanup_expired_cache()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM shared.ai_response_cache
    WHERE expires_at < NOW() OR last_accessed < NOW() - INTERVAL '7 days';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Log del cleanup
    PERFORM shared.log_system_event(
        'cache_cleanup_completed',
        'system',
        'ai_cache',
        jsonb_build_object('deleted_entries', deleted_count),
        NULL,
        NULL,
        'system'
    );
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- 📝 FUNCIÓN PARA REGISTRAR CAMBIOS EN PRODUCTOS
CREATE OR REPLACE FUNCTION stock.log_product_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_changes JSONB;
    v_user_id INTEGER;
    v_session_user_id TEXT;
BEGIN
    -- Intenta obtener el ID del usuario actual desde la configuración de sesión
    BEGIN
        v_session_user_id := current_setting('app.current_user_id', true);
        IF v_session_user_id IS NOT NULL AND v_session_user_id ~ '^[0-9]+$' THEN
            v_user_id := v_session_user_id::INTEGER;
        ELSE
            v_user_id := NULL;
        END IF;
    EXCEPTION WHEN UNDEFINED_PARAMETER THEN
        v_user_id := NULL;
    END;

    v_changes := jsonb_build_object();

    -- Detectar cambios significativos
    IF OLD.name IS DISTINCT FROM NEW.name THEN
        v_changes := v_changes || jsonb_build_object('name', jsonb_build_object('old', OLD.name, 'new', NEW.name));
    END IF;
    IF OLD.price IS DISTINCT FROM NEW.price THEN
        v_changes := v_changes || jsonb_build_object('price', jsonb_build_object('old', OLD.price, 'new', NEW.price));
    END IF;
    IF OLD.stock_quantity IS DISTINCT FROM NEW.stock_quantity THEN
        v_changes := v_changes || jsonb_build_object('stock_quantity', jsonb_build_object('old', OLD.stock_quantity, 'new', NEW.stock_quantity));
    END IF;
    IF OLD.is_available IS DISTINCT FROM NEW.is_available THEN
        v_changes := v_changes || jsonb_build_object('is_available', jsonb_build_object('old', OLD.is_available, 'new', NEW.is_available));
    END IF;

    -- Solo registrar si hay cambios
    IF v_changes != '{}'::jsonb THEN
        INSERT INTO shared.activity_logs (user_id, action, entity_type, entity_id, entity_name, changes)
        VALUES (v_user_id, 'update', 'product', NEW.id, NEW.name, v_changes);
        
        -- También registrar evento
        PERFORM shared.log_system_event(
            'product_updated',
            'product',
            NEW.id::VARCHAR,
            jsonb_build_object('changes', v_changes, 'product_name', NEW.name),
            v_user_id,
            NULL,
            'stock_management'
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para registrar cambios en productos
CREATE TRIGGER trg_log_product_changes
    AFTER UPDATE ON stock.products
    FOR EACH ROW
    EXECUTE FUNCTION stock.log_product_changes();

-- 🕒 FUNCIÓN PARA LIMPIAR SESIONES EXPIRADAS
CREATE OR REPLACE FUNCTION shared.cleanup_expired_sessions()
RETURNS INTEGER AS $$
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
        'sessions',
        jsonb_build_object('deleted_sessions', deleted_count),
        NULL,
        NULL,
        'system'
    );
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- ✅ VERIFICACIÓN DE INSTALACIÓN
DO $$
BEGIN
    RAISE NOTICE '✅ Missing Critical Tables instaladas correctamente';
    RAISE NOTICE '📊 inventory_adjustments: Tabla de ajustes de inventario';
    RAISE NOTICE '📅 events: Event sourcing implementado';
    RAISE NOTICE '🤖 ai_response_cache: Caché de IA para performance';
    RAISE NOTICE '🔄 Funciones de auditoría y cleanup implementadas';
    RAISE NOTICE '⚡ Triggers automáticos configurados';
END $$;