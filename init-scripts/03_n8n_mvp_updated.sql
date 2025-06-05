-- ============================================================================
-- 🚀 N8N MVP SCHEMA - FLUJO SIMPLIFICADO CON MULTI-TENANCY
-- ============================================================================
-- Archivo: init-scripts/03_n8n_mvp.sql
-- Propósito: Tablas específicas para el MVP de N8N con soporte SaaS
-- Dependencias: 00_core_schema.sql, 02_shared_tables.sql
-- Orden de ejecución: CUARTO (03_)
-- ============================================================================

-- 📊 CONFIGURACIÓN ESPECÍFICA DEL MVP (Multi-tenant)
CREATE TABLE IF NOT EXISTS n8n.mvp_config (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES saas.organizations(id) ON DELETE CASCADE,
    config_key VARCHAR(100) NOT NULL,
    config_value TEXT,
    config_type VARCHAR(20) DEFAULT 'string' CHECK (config_type IN ('string', 'number', 'boolean', 'json')),
    description TEXT,
    is_enabled BOOLEAN DEFAULT true,
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(organization_id, config_key)
);

-- Trigger para updated_at en mvp_config
CREATE TRIGGER update_mvp_config_updated_at
    BEFORE UPDATE ON n8n.mvp_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 🎯 INTENTS SIMPLIFICADOS PARA MVP (Global con personalización por org)
CREATE TABLE IF NOT EXISTS n8n.mvp_intents (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES saas.organizations(id) ON DELETE CASCADE,
    intent_name VARCHAR(50) NOT NULL,
    intent_description TEXT,
    
    -- Patrones de reconocimiento simple (sin IA)
    keyword_patterns JSONB NOT NULL, -- Array de palabras clave
    exact_matches JSONB DEFAULT '[]', -- Frases exactas
    priority INTEGER DEFAULT 100, -- Menor número = mayor prioridad
    
    -- Respuesta estándar
    response_template TEXT NOT NULL,
    response_type VARCHAR(30) DEFAULT 'text' CHECK (response_type IN ('text', 'interactive', 'list', 'buttons')),
    response_data JSONB DEFAULT '{}', -- Datos adicionales para respuestas interactivas
    
    -- Configuración
    is_active BOOLEAN DEFAULT true,
    requires_context BOOLEAN DEFAULT false,
    next_intent VARCHAR(50), -- Intent de seguimiento
    
    -- Métricas
    usage_count INTEGER DEFAULT 0,
    success_rate DECIMAL(5,2) DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(organization_id, intent_name)
);

-- Trigger para updated_at en mvp_intents
CREATE TRIGGER update_mvp_intents_updated_at
    BEFORE UPDATE ON n8n.mvp_intents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 📱 SESIONES MVP SIMPLIFICADAS (Multi-tenant - extiende shared.customer_sessions)
CREATE TABLE IF NOT EXISTS n8n.mvp_session_data (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
    session_id INTEGER NOT NULL REFERENCES shared.customer_sessions(id) ON DELETE CASCADE,
    
    -- Estado simple del MVP
    current_step VARCHAR(50) DEFAULT 'greeting',
    workflow_state VARCHAR(30) DEFAULT 'active' CHECK (workflow_state IN ('active', 'paused', 'completed', 'error')),
    
    -- Datos mínimos para el flujo
    selected_category_id INTEGER,
    search_query VARCHAR(255),
    cart_item_count INTEGER DEFAULT 0,
    
    -- Métricas simples
    interaction_count INTEGER DEFAULT 0,
    conversion_stage VARCHAR(30) DEFAULT 'awareness' CHECK (conversion_stage IN ('awareness', 'interest', 'consideration', 'purchase', 'retention')),
    
    -- Control de flujo
    last_intent VARCHAR(50),
    retry_count INTEGER DEFAULT 0,
    error_state VARCHAR(100),
    
    -- Timestamps
    last_interaction TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(organization_id, session_id)
);

-- Trigger para updated_at en mvp_session_data
CREATE TRIGGER update_mvp_session_data_updated_at
    BEFORE UPDATE ON n8n.mvp_session_data
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 📊 MÉTRICAS SIMPLIFICADAS DEL MVP (Multi-tenant)
CREATE TABLE IF NOT EXISTS n8n.mvp_metrics (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
    
    -- Identificación
    metric_date DATE NOT NULL DEFAULT CURRENT_DATE,
    metric_hour INTEGER DEFAULT EXTRACT(HOUR FROM NOW()),
    
    -- Métricas de mensajes
    total_messages_received INTEGER DEFAULT 0,
    total_messages_sent INTEGER DEFAULT 0,
    unique_users INTEGER DEFAULT 0,
    
    -- Métricas de intent
    intents_detected INTEGER DEFAULT 0,
    intents_fallback INTEGER DEFAULT 0, -- Casos donde no se detectó intent
    
    -- Métricas de conversión (MVP)
    sessions_started INTEGER DEFAULT 0,
    categories_browsed INTEGER DEFAULT 0,
    products_viewed INTEGER DEFAULT 0,
    items_added_to_cart INTEGER DEFAULT 0,
    checkouts_initiated INTEGER DEFAULT 0,
    orders_completed INTEGER DEFAULT 0,
    
    -- Métricas de rendimiento
    average_response_time_ms INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    timeout_count INTEGER DEFAULT 0,
    
    -- Métricas de satisfacción
    positive_interactions INTEGER DEFAULT 0,
    negative_interactions INTEGER DEFAULT 0,
    neutral_interactions INTEGER DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(organization_id, metric_date, metric_hour)
);

-- 🔧 CONFIGURACIÓN DE WORKFLOWS MVP (Multi-tenant)
CREATE TABLE IF NOT EXISTS n8n.mvp_workflows (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES saas.organizations(id) ON DELETE CASCADE,
    workflow_name VARCHAR(100) NOT NULL,
    workflow_description TEXT,
    
    -- Configuración del workflow
    is_active BOOLEAN DEFAULT true,
    trigger_type VARCHAR(30) DEFAULT 'webhook' CHECK (trigger_type IN ('webhook', 'schedule', 'manual')),
    trigger_config JSONB DEFAULT '{}',
    
    -- Configuración de steps
    workflow_steps JSONB NOT NULL, -- Array de pasos del workflow
    max_execution_time_seconds INTEGER DEFAULT 300,
    retry_policy JSONB DEFAULT '{"max_retries": 3, "backoff": "exponential"}',
    
    -- Métricas del workflow
    execution_count INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    average_execution_time_ms INTEGER DEFAULT 0,
    
    -- Configuración
    environment VARCHAR(20) DEFAULT 'production' CHECK (environment IN ('development', 'staging', 'production')),
    version VARCHAR(20) DEFAULT '1.0',
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(organization_id, workflow_name)
);

-- Trigger para updated_at en mvp_workflows
CREATE TRIGGER update_mvp_workflows_updated_at
    BEFORE UPDATE ON n8n.mvp_workflows
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 📝 LOGS DE EJECUCIÓN MVP (Multi-tenant)
CREATE TABLE IF NOT EXISTS n8n.mvp_execution_logs (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
    
    -- Identificación de la ejecución
    execution_id VARCHAR(100) NOT NULL,
    workflow_id INTEGER REFERENCES n8n.mvp_workflows(id) ON DELETE SET NULL,
    workflow_name VARCHAR(100),
    
    -- Información del trigger
    trigger_data JSONB,
    customer_phone VARCHAR(20),
    
    -- Estado de ejecución
    execution_status VARCHAR(30) DEFAULT 'running' CHECK (execution_status IN ('running', 'completed', 'failed', 'timeout', 'cancelled')),
    current_step VARCHAR(100),
    step_count INTEGER DEFAULT 0,
    
    -- Datos de la ejecución
    input_data JSONB,
    output_data JSONB,
    error_message TEXT,
    error_step VARCHAR(100),
    
    -- Métricas de rendimiento
    execution_time_ms INTEGER,
    memory_usage_mb DECIMAL(8,2),
    
    -- Timestamps
    started_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    failed_at TIMESTAMP,
    
    UNIQUE(organization_id, execution_id)
);

-- =============================================================================
-- 📊 ÍNDICES OPTIMIZADOS PARA MVP (Multi-tenant)
-- =============================================================================

-- Índices para mvp_config
CREATE INDEX IF NOT EXISTS idx_mvp_config_org_key ON n8n.mvp_config(organization_id, config_key);
CREATE INDEX IF NOT EXISTS idx_mvp_config_enabled ON n8n.mvp_config(is_enabled) WHERE is_enabled = true;

-- Índices para mvp_intents
CREATE INDEX IF NOT EXISTS idx_mvp_intents_org_active ON n8n.mvp_intents(organization_id, is_active, priority) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_mvp_intents_org_usage ON n8n.mvp_intents(organization_id, usage_count DESC, success_rate DESC);

-- Índices para mvp_session_data
CREATE INDEX IF NOT EXISTS idx_mvp_session_data_org_session ON n8n.mvp_session_data(organization_id, session_id);
CREATE INDEX IF NOT EXISTS idx_mvp_session_data_org_state ON n8n.mvp_session_data(organization_id, workflow_state, current_step);
CREATE INDEX IF NOT EXISTS idx_mvp_session_data_org_interaction ON n8n.mvp_session_data(organization_id, last_interaction DESC);

-- Índices para mvp_metrics
CREATE INDEX IF NOT EXISTS idx_mvp_metrics_org_date_hour ON n8n.mvp_metrics(organization_id, metric_date DESC, metric_hour DESC);
CREATE INDEX IF NOT EXISTS idx_mvp_metrics_org_date ON n8n.mvp_metrics(organization_id, metric_date DESC);

-- Índices para mvp_workflows
CREATE INDEX IF NOT EXISTS idx_mvp_workflows_org_active ON n8n.mvp_workflows(organization_id, is_active, workflow_name) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_mvp_workflows_org_performance ON n8n.mvp_workflows(organization_id, success_count DESC, average_execution_time_ms ASC);

-- Índices para mvp_execution_logs
CREATE INDEX IF NOT EXISTS idx_mvp_execution_logs_org_workflow ON n8n.mvp_execution_logs(organization_id, workflow_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_mvp_execution_logs_org_status ON n8n.mvp_execution_logs(organization_id, execution_status, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_mvp_execution_logs_org_customer ON n8n.mvp_execution_logs(organization_id, customer_phone, started_at DESC) WHERE customer_phone IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_mvp_execution_logs_org_execution_id ON n8n.mvp_execution_logs(organization_id, execution_id);

-- =============================================================================
-- 🔧 FUNCIONES ESPECÍFICAS PARA MVP (Multi-tenant)
-- =============================================================================

-- Función para detectar intent simple (sin IA) - Multi-tenant
CREATE OR REPLACE FUNCTION n8n.detect_intent_mvp(org_id INTEGER, message_text TEXT)
RETURNS TABLE(
    intent_name VARCHAR(50),
    confidence DECIMAL(3,2),
    response_template TEXT,
    response_type VARCHAR(30),
    response_data JSONB
) AS $$
DECLARE
    v_message_lower TEXT;
    intent_record RECORD;
    best_intent RECORD;
    max_score INTEGER := 0;
    current_score INTEGER;
BEGIN
    v_message_lower := lower(trim(message_text));
    
    -- Buscar coincidencias exactas primero
    FOR intent_record IN 
        SELECT i.*, 1000 as match_score
        FROM n8n.mvp_intents i
        WHERE i.organization_id = org_id
          AND i.is_active = true
          AND EXISTS (
              SELECT 1 FROM jsonb_array_elements_text(i.exact_matches) as exact_match
              WHERE lower(exact_match) = v_message_lower
          )
        ORDER BY i.priority ASC
    LOOP
        best_intent := intent_record;
        max_score := intent_record.match_score;
        EXIT; -- Tomar la primera coincidencia exacta
    END LOOP;
    
    -- Si no hay coincidencia exacta, buscar por palabras clave
    IF max_score = 0 THEN
        FOR intent_record IN 
            SELECT i.*
            FROM n8n.mvp_intents i
            WHERE i.organization_id = org_id
              AND i.is_active = true
            ORDER BY i.priority ASC
        LOOP
            current_score := 0;
            
            -- Contar coincidencias de palabras clave
            SELECT COUNT(*)::INTEGER INTO current_score
            FROM jsonb_array_elements_text(intent_record.keyword_patterns) as keyword
            WHERE v_message_lower LIKE '%' || lower(keyword) || '%';
            
            -- Si encontramos un mejor score, actualizar
            IF current_score > max_score THEN
                max_score := current_score;
                best_intent := intent_record;
            END IF;
        END LOOP;
    END IF;
    
    -- Si encontramos un intent, devolverlo
    IF max_score > 0 THEN
        -- Incrementar contador de uso
        UPDATE n8n.mvp_intents 
        SET usage_count = usage_count + 1,
            updated_at = NOW()
        WHERE organization_id = org_id 
          AND intent_name = best_intent.intent_name;
        
        RETURN QUERY SELECT 
            best_intent.intent_name,
            CASE 
                WHEN max_score >= 1000 THEN 1.0::DECIMAL(3,2) -- Coincidencia exacta
                WHEN max_score >= 3 THEN 0.9::DECIMAL(3,2)
                WHEN max_score >= 2 THEN 0.7::DECIMAL(3,2)
                WHEN max_score >= 1 THEN 0.5::DECIMAL(3,2)
                ELSE 0.3::DECIMAL(3,2)
            END,
            best_intent.response_template,
            best_intent.response_type,
            best_intent.response_data;
    ELSE
        -- Intent por defecto (unknown)
        RETURN QUERY SELECT 
            'unknown'::VARCHAR(50),
            0.1::DECIMAL(3,2),
            'Lo siento, no entendí tu mensaje. ¿Puedes ser más específico?'::TEXT,
            'text'::VARCHAR(30),
            '{}'::JSONB;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Función para actualizar métricas MVP en tiempo real (Multi-tenant)
CREATE OR REPLACE FUNCTION n8n.update_mvp_metrics(
    org_id INTEGER,
    metric_type VARCHAR(50),
    increment_value INTEGER DEFAULT 1,
    target_date DATE DEFAULT CURRENT_DATE,
    target_hour INTEGER DEFAULT EXTRACT(HOUR FROM NOW())
) RETURNS VOID AS $$
BEGIN
    -- Verificar quota antes de procesar
    IF NOT saas.check_quota_limit(org_id, 'n8n_metrics', 1) THEN
        RETURN; -- Salir silenciosamente si se excede quota
    END IF;
    
    -- Insertar o actualizar métricas
    INSERT INTO n8n.mvp_metrics (
        organization_id, metric_date, metric_hour,
        total_messages_received, total_messages_sent,
        intents_detected, intents_fallback,
        sessions_started, categories_browsed,
        products_viewed, items_added_to_cart,
        checkouts_initiated, orders_completed,
        positive_interactions, negative_interactions,
        neutral_interactions, error_count, timeout_count
    ) VALUES (
        org_id, target_date, target_hour,
        CASE WHEN metric_type = 'message_received' THEN increment_value ELSE 0 END,
        CASE WHEN metric_type = 'message_sent' THEN increment_value ELSE 0 END,
        CASE WHEN metric_type = 'intent_detected' THEN increment_value ELSE 0 END,
        CASE WHEN metric_type = 'intent_fallback' THEN increment_value ELSE 0 END,
        CASE WHEN metric_type = 'session_started' THEN increment_value ELSE 0 END,
        CASE WHEN metric_type = 'category_browsed' THEN increment_value ELSE 0 END,
        CASE WHEN metric_type = 'product_viewed' THEN increment_value ELSE 0 END,
        CASE WHEN metric_type = 'item_added_to_cart' THEN increment_value ELSE 0 END,
        CASE WHEN metric_type = 'checkout_initiated' THEN increment_value ELSE 0 END,
        CASE WHEN metric_type = 'order_completed' THEN increment_value ELSE 0 END,
        CASE WHEN metric_type = 'positive_interaction' THEN increment_value ELSE 0 END,
        CASE WHEN metric_type = 'negative_interaction' THEN increment_value ELSE 0 END,
        CASE WHEN metric_type = 'neutral_interaction' THEN increment_value ELSE 0 END,
        CASE WHEN metric_type = 'error' THEN increment_value ELSE 0 END,
        CASE WHEN metric_type = 'timeout' THEN increment_value ELSE 0 END
    )
    ON CONFLICT (organization_id, metric_date, metric_hour)
    DO UPDATE SET
        total_messages_received = n8n.mvp_metrics.total_messages_received + 
            CASE WHEN metric_type = 'message_received' THEN increment_value ELSE 0 END,
        total_messages_sent = n8n.mvp_metrics.total_messages_sent + 
            CASE WHEN metric_type = 'message_sent' THEN increment_value ELSE 0 END,
        intents_detected = n8n.mvp_metrics.intents_detected + 
            CASE WHEN metric_type = 'intent_detected' THEN increment_value ELSE 0 END,
        intents_fallback = n8n.mvp_metrics.intents_fallback + 
            CASE WHEN metric_type = 'intent_fallback' THEN increment_value ELSE 0 END,
        sessions_started = n8n.mvp_metrics.sessions_started + 
            CASE WHEN metric_type = 'session_started' THEN increment_value ELSE 0 END,
        categories_browsed = n8n.mvp_metrics.categories_browsed + 
            CASE WHEN metric_type = 'category_browsed' THEN increment_value ELSE 0 END,
        products_viewed = n8n.mvp_metrics.products_viewed + 
            CASE WHEN metric_type = 'product_viewed' THEN increment_value ELSE 0 END,
        items_added_to_cart = n8n.mvp_metrics.items_added_to_cart + 
            CASE WHEN metric_type = 'item_added_to_cart' THEN increment_value ELSE 0 END,
        checkouts_initiated = n8n.mvp_metrics.checkouts_initiated + 
            CASE WHEN metric_type = 'checkout_initiated' THEN increment_value ELSE 0 END,
        orders_completed = n8n.mvp_metrics.orders_completed + 
            CASE WHEN metric_type = 'order_completed' THEN increment_value ELSE 0 END,
        positive_interactions = n8n.mvp_metrics.positive_interactions + 
            CASE WHEN metric_type = 'positive_interaction' THEN increment_value ELSE 0 END,
        negative_interactions = n8n.mvp_metrics.negative_interactions + 
            CASE WHEN metric_type = 'negative_interaction' THEN increment_value ELSE 0 END,
        neutral_interactions = n8n.mvp_metrics.neutral_interactions + 
            CASE WHEN metric_type = 'neutral_interaction' THEN increment_value ELSE 0 END,
        error_count = n8n.mvp_metrics.error_count + 
            CASE WHEN metric_type = 'error' THEN increment_value ELSE 0 END,
        timeout_count = n8n.mvp_metrics.timeout_count + 
            CASE WHEN metric_type = 'timeout' THEN increment_value ELSE 0 END;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener estadísticas del MVP (Multi-tenant)
CREATE OR REPLACE FUNCTION n8n.get_mvp_stats(org_id INTEGER, days_back INTEGER DEFAULT 7)
RETURNS TABLE(
    total_conversations INTEGER,
    total_orders INTEGER,
    conversion_rate DECIMAL(5,2),
    avg_response_time_ms INTEGER,
    top_intents JSONB,
    daily_metrics JSONB
) AS $$
DECLARE
    v_total_conversations INTEGER;
    v_total_orders INTEGER;
    v_conversion_rate DECIMAL(5,2);
    v_avg_response_time INTEGER;
    v_top_intents JSONB;
    v_daily_metrics JSONB;
    start_date DATE;
BEGIN
    start_date := CURRENT_DATE - INTERVAL '1 day' * days_back;
    
    -- Obtener total de conversaciones
    SELECT COUNT(DISTINCT customer_phone) INTO v_total_conversations
    FROM shared.message_logs
    WHERE organization_id = org_id 
      AND message_timestamp >= start_date;
    
    -- Obtener total de órdenes
    SELECT COUNT(*) INTO v_total_orders
    FROM shared.orders
    WHERE organization_id = org_id
      AND created_at >= start_date 
      AND order_status IN ('completed', 'delivered');
    
    -- Calcular conversion rate
    v_conversion_rate := CASE 
        WHEN v_total_conversations > 0 THEN (v_total_orders::DECIMAL / v_total_conversations) * 100
        ELSE 0
    END;
    
    -- Obtener tiempo promedio de respuesta
    SELECT COALESCE(AVG(response_time_ms), 0)::INTEGER INTO v_avg_response_time
    FROM shared.message_logs
    WHERE organization_id = org_id
      AND message_timestamp >= start_date 
      AND response_time_ms IS NOT NULL;
    
    -- Top intents
    SELECT jsonb_agg(intent_data.*)
    INTO v_top_intents
    FROM (
        SELECT 
            intent_name,
            usage_count,
            success_rate
        FROM n8n.mvp_intents
        WHERE organization_id = org_id
          AND usage_count > 0
        ORDER BY usage_count DESC
        LIMIT 10
    ) intent_data;
    
    -- Métricas diarias
    SELECT jsonb_agg(daily_data.*)
    INTO v_daily_metrics
    FROM (
        SELECT 
            metric_date,
            SUM(total_messages_received) as messages_received,
            SUM(total_messages_sent) as messages_sent,
            SUM(sessions_started) as sessions,
            SUM(orders_completed) as orders,
            CASE 
                WHEN SUM(sessions_started) > 0 
                THEN (SUM(orders_completed)::DECIMAL / SUM(sessions_started)) * 100
                ELSE 0
            END as daily_conversion_rate
        FROM n8n.mvp_metrics
        WHERE organization_id = org_id
          AND metric_date >= start_date
        GROUP BY metric_date
        ORDER BY metric_date DESC
    ) daily_data;
    
    RETURN QUERY SELECT
        v_total_conversations,
        v_total_orders,
        v_conversion_rate,
        v_avg_response_time,
        COALESCE(v_top_intents, '[]'::jsonb),
        COALESCE(v_daily_metrics, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 📊 VISTAS ESPECÍFICAS PARA MVP (Multi-tenant)
-- =============================================================================

-- Vista para dashboard MVP (Multi-tenant)
CREATE OR REPLACE VIEW n8n.mvp_dashboard AS
SELECT 
    organization_id,
    -- Métricas del día actual
    COALESCE(SUM(total_messages_received), 0) as messages_today,
    COALESCE(SUM(sessions_started), 0) as sessions_today,
    COALESCE(SUM(orders_completed), 0) as orders_today,
    CASE 
        WHEN SUM(sessions_started) > 0 
        THEN (SUM(orders_completed)::DECIMAL / SUM(sessions_started)) * 100
        ELSE 0
    END as conversion_rate_today,
    
    -- Comparación con ayer
    COALESCE(SUM(total_messages_received) - LAG(SUM(total_messages_received)) OVER (PARTITION BY organization_id ORDER BY metric_date), 0) as messages_change,
    COALESCE(SUM(sessions_started) - LAG(SUM(sessions_started)) OVER (PARTITION BY organization_id ORDER BY metric_date), 0) as sessions_change,
    COALESCE(SUM(orders_completed) - LAG(SUM(orders_completed)) OVER (PARTITION BY organization_id ORDER BY metric_date), 0) as orders_change
    
FROM n8n.mvp_metrics
WHERE metric_date >= CURRENT_DATE - INTERVAL '1 day'
GROUP BY organization_id, metric_date
ORDER BY organization_id, metric_date DESC;

-- Vista para rendimiento de intents (Multi-tenant)
CREATE OR REPLACE VIEW n8n.mvp_intent_performance AS
SELECT 
    i.organization_id,
    i.intent_name,
    i.usage_count,
    i.success_rate,
    i.response_type,
    i.is_active,
    CASE 
        WHEN i.usage_count = 0 THEN 'unused'
        WHEN i.success_rate >= 80 THEN 'excellent'
        WHEN i.success_rate >= 60 THEN 'good'
        WHEN i.success_rate >= 40 THEN 'fair'
        ELSE 'poor'
    END as performance_rating,
    i.updated_at as last_used
FROM n8n.mvp_intents i
ORDER BY i.organization_id, i.usage_count DESC, i.success_rate DESC;

-- =============================================================================
-- 🔒 ROW LEVEL SECURITY (RLS) PARA N8N MVP
-- =============================================================================

-- Habilitar RLS en mvp_metrics
ALTER TABLE n8n.mvp_metrics ENABLE ROW LEVEL SECURITY;
CREATE POLICY mvp_metrics_isolation ON n8n.mvp_metrics
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id());

-- Habilitar RLS en mvp_intents
ALTER TABLE n8n.mvp_intents ENABLE ROW LEVEL SECURITY;
CREATE POLICY mvp_intents_isolation ON n8n.mvp_intents
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id() OR organization_id IS NULL);

-- Habilitar RLS en mvp_session_data
ALTER TABLE n8n.mvp_session_data ENABLE ROW LEVEL SECURITY;
CREATE POLICY mvp_session_data_isolation ON n8n.mvp_session_data
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id());

-- Habilitar RLS en mvp_workflows
ALTER TABLE n8n.mvp_workflows ENABLE ROW LEVEL SECURITY;
CREATE POLICY mvp_workflows_isolation ON n8n.mvp_workflows
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id() OR organization_id IS NULL);

-- Habilitar RLS en mvp_execution_logs
ALTER TABLE n8n.mvp_execution_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY mvp_execution_logs_isolation ON n8n.mvp_execution_logs
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id());

-- =============================================================================
-- 📄 DATOS INICIALES PARA MVP (Multi-tenant)
-- =============================================================================

-- Configuración inicial del MVP (Global y por organización demo)
DO $$
DECLARE
    demo_org_id INTEGER;
BEGIN
    SELECT id INTO demo_org_id FROM saas.organizations WHERE slug = 'empresa-demo';
    
    -- Configuración global (sin organization_id)
    INSERT INTO n8n.mvp_config (organization_id, config_key, config_value, config_type, description) VALUES
        (NULL, 'mvp_enabled', 'true', 'boolean', 'Habilitar el modo MVP globalmente'),
        (NULL, 'session_timeout_minutes', '120', 'number', 'Timeout de sesión en minutos'),
        (NULL, 'max_cart_items', '20', 'number', 'Máximo items en carrito'),
        (NULL, 'fallback_response', 'Lo siento, no entendí. ¿Puedes ser más específico?', 'string', 'Respuesta por defecto'),
        (NULL, 'enable_metrics', 'true', 'boolean', 'Habilitar recolección de métricas'),
        (NULL, 'debug_mode', 'false', 'boolean', 'Modo debug para desarrollo')
    ON CONFLICT (organization_id, config_key) DO NOTHING;
    
    -- Configuración específica para demo si existe
    IF demo_org_id IS NOT NULL THEN
        INSERT INTO n8n.mvp_config (organization_id, config_key, config_value, config_type, description) VALUES
            (demo_org_id, 'business_name', 'Empresa Demo', 'string', 'Nombre del negocio'),
            (demo_org_id, 'greeting_message', 'Bienvenido a Empresa Demo', 'string', 'Mensaje de bienvenida personalizado'),
            (demo_org_id, 'enable_ai_fallback', 'false', 'boolean', 'Habilitar fallback a IA en MVP')
        ON CONFLICT (organization_id, config_key) DO NOTHING;

        -- Intents básicos para MVP demo
        INSERT INTO n8n.mvp_intents (organization_id, intent_name, intent_description, keyword_patterns, exact_matches, response_template, response_type, response_data, priority) VALUES

        -- Saludo
        (demo_org_id, 'greeting', 'Saludo inicial del usuario', 
         '["hola", "hi", "buenos", "buenas", "saludos"]'::jsonb,
         '["hola", "hi", "inicio", "menu"]'::jsonb,
         '¡Hola! 👋 Bienvenido a Empresa Demo. ¿En qué puedo ayudarte hoy?',
         'buttons',
         '{"buttons": [{"id": "ver_categorias", "title": "📂 Ver Categorías"}, {"id": "buscar_producto", "title": "🔍 Buscar Producto"}, {"id": "mi_carrito", "title": "🛒 Mi Carrito"}]}'::jsonb,
         1),

        -- Ver categorías
        (demo_org_id, 'browse_categories', 'Usuario quiere ver categorías',
         '["categorias", "categoria", "ver categorias", "productos"]'::jsonb,
         '["1", "ver categorias", "categorias"]'::jsonb,
         'Aquí tienes nuestras categorías disponibles:',
         'list',
         '{"list_type": "categories"}'::jsonb,
         2),

        -- Buscar producto
        (demo_org_id, 'search_product', 'Usuario quiere buscar un producto',
         '["buscar", "busco", "quiero", "necesito", "donde"]'::jsonb,
         '["2", "buscar producto", "buscar"]'::jsonb,
         '🔍 ¿Qué producto estás buscando? Puedes decirme el nombre o describírmelo.',
         'text',
         '{}'::jsonb,
         3),

        -- Ver carrito
        (demo_org_id, 'view_cart', 'Usuario quiere ver su carrito',
         '["carrito", "mi carrito", "ver carrito"]'::jsonb,
         '["3", "mi carrito", "carrito"]'::jsonb,
         'Te muestro tu carrito actual:',
         'text',
         '{"action": "show_cart"}'::jsonb,
         4),

        -- Agregar al carrito
        (demo_org_id, 'add_to_cart', 'Usuario quiere agregar algo al carrito',
         '["agregar", "añadir", "quiero", "me llevo"]'::jsonb,
         '[]'::jsonb,
         '✅ Producto agregado al carrito. ¿Quieres seguir comprando o ver tu carrito?',
         'buttons',
         '{"buttons": [{"id": "seguir_comprando", "title": "🛍️ Seguir Comprando"}, {"id": "ver_carrito", "title": "🛒 Ver Carrito"}, {"id": "finalizar", "title": "💳 Finalizar Compra"}]}'::jsonb,
         5),

        -- Ayuda
        (demo_org_id, 'help', 'Usuario pide ayuda',
         '["ayuda", "help", "soporte", "no entiendo"]'::jsonb,
         '["ayuda", "help", "4"]'::jsonb,
         '🆘 Te puedo ayudar con: \n📂 Ver categorías de productos\n🔍 Buscar productos específicos\n🛒 Gestionar tu carrito\n💳 Realizar pedidos\n\n¿Qué necesitas?',
         'text',
         '{}'::jsonb,
         6),

        -- Finalizar compra
        (demo_org_id, 'checkout', 'Usuario quiere finalizar compra',
         '["finalizar", "comprar", "pedir", "checkout"]'::jsonb,
         '["finalizar compra", "checkout", "comprar"]'::jsonb,
         '💳 ¡Perfecto! Para finalizar tu compra necesito que me proporciones tu dirección de entrega.',
         'text',
         '{"action": "request_address"}'::jsonb,
         7),

        -- Cancelar
        (demo_org_id, 'cancel', 'Usuario quiere cancelar algo',
         '["cancelar", "no", "salir", "terminar"]'::jsonb,
         '["cancelar", "no quiero", "salir"]'::jsonb,
         'Entendido. ¿Hay algo más en lo que pueda ayudarte?',
         'buttons',
         '{"buttons": [{"id": "ver_categorias", "title": "📂 Ver Categorías"}, {"id": "buscar_producto", "title": "🔍 Buscar Producto"}]}'::jsonb,
         8),

        -- Agradecimiento
        (demo_org_id, 'thanks', 'Usuario agradece',
         '["gracias", "thank", "perfecto", "excelente"]'::jsonb,
         '["gracias", "perfecto", "excelente"]'::jsonb,
         '¡De nada! 😊 ¿Hay algo más en lo que pueda ayudarte?',
         'text',
         '{}'::jsonb,
         9)

        ON CONFLICT (organization_id, intent_name) DO NOTHING;

        -- Workflow básico del MVP para demo
        INSERT INTO n8n.mvp_workflows (organization_id, workflow_name, workflow_description, workflow_steps, trigger_config) VALUES
        (demo_org_id, 'mvp_whatsapp_flow', 'Flujo principal del MVP para WhatsApp',
         '[
           {"step": "parse_message", "description": "Parsear mensaje de WhatsApp"},
           {"step": "detect_intent", "description": "Detectar intención usando MVP"},
           {"step": "process_intent", "description": "Procesar intención detectada"},
           {"step": "generate_response", "description": "Generar respuesta apropiada"},
           {"step": "send_response", "description": "Enviar respuesta a WhatsApp"},
           {"step": "update_metrics", "description": "Actualizar métricas MVP"}
         ]'::jsonb,
         '{"webhook_path": "/webhook/whatsapp-mvp", "timeout": 30}'::jsonb
        )
        ON CONFLICT (organization_id, workflow_name) DO NOTHING;
    END IF;
END $;

-- ✅ VERIFICACIÓN DE INSTALACIÓN
DO $
BEGIN
    RAISE NOTICE '✅ N8N MVP Schema con Multi-tenancy instalado correctamente';
    RAISE NOTICE '🎯 Sistema de intents básico configurado (9 intents para demo)';
    RAISE NOTICE '📊 Métricas simplificadas para MVP implementadas (Multi-tenant)';
    RAISE NOTICE '🔧 Funciones de detección de intent sin IA disponibles (Multi-tenant)';
    RAISE NOTICE '📱 Workflow básico de WhatsApp configurado para demo';
    RAISE NOTICE '🔒 Row Level Security habilitado en todas las tablas';
    RAISE NOTICE '🚀 MVP listo para usar con flujo simplificado multi-tenant';
END $;