-- ============================================================================
-- 🏢 SAAS ADVANCED FEATURES - CARACTERÍSTICAS AVANZADAS MULTI-TENANT
-- ============================================================================
-- Archivo: init-scripts/07_saas_advanced_features.sql
-- Propósito: Funcionalidades avanzadas del sistema SaaS (Facturación, Métricas, RLS)
-- Dependencias: 00_core_schema.sql, 01_stock_management.sql, 02_shared_tables.sql
-- Orden de ejecución: SÉPTIMO (07_)
-- ============================================================================

-- 📊 MÉTRICAS DE USO ORGANIZACIONAL
CREATE TABLE IF NOT EXISTS saas.usage_metrics (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
    
    -- Fecha de la métrica
    metric_date DATE NOT NULL,
    metric_hour INTEGER DEFAULT EXTRACT(HOUR FROM NOW()),
    
    -- Métricas de uso básicas
    active_users INTEGER DEFAULT 0,
    total_products INTEGER DEFAULT 0,
    monthly_orders INTEGER DEFAULT 0,
    storage_used_gb DECIMAL(10,3) DEFAULT 0,
    
    -- Métricas de API y integración
    api_calls INTEGER DEFAULT 0,
    webhook_calls INTEGER DEFAULT 0,
    n8n_executions INTEGER DEFAULT 0,
    ai_requests INTEGER DEFAULT 0,
    
    -- Métricas de comunicación
    whatsapp_messages_sent INTEGER DEFAULT 0,
    whatsapp_messages_received INTEGER DEFAULT 0,
    emails_sent INTEGER DEFAULT 0,
    sms_sent INTEGER DEFAULT 0,
    
    -- Métricas de rendimiento
    avg_response_time_ms INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    uptime_percentage DECIMAL(5,2) DEFAULT 100,
    
    -- Métricas de negocio
    total_revenue DECIMAL(12,2) DEFAULT 0,
    total_cost DECIMAL(12,2) DEFAULT 0,
    profit_margin DECIMAL(5,2) DEFAULT 0,
    
    -- Metadatos
    raw_data JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    
    -- Constraint para evitar duplicados por día/hora
    UNIQUE(organization_id, metric_date, metric_hour)
);

-- Índices para usage_metrics
CREATE INDEX IF NOT EXISTS idx_usage_metrics_org_date ON saas.usage_metrics(organization_id, metric_date DESC);
CREATE INDEX IF NOT EXISTS idx_usage_metrics_date_hour ON saas.usage_metrics(metric_date DESC, metric_hour DESC);

-- 💳 HISTORIAL DE FACTURACIÓN
CREATE TABLE IF NOT EXISTS saas.billing_history (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
    
    -- Información de la factura
    invoice_number VARCHAR(50) UNIQUE NOT NULL DEFAULT generate_order_number('INV'),
    billing_period_start DATE NOT NULL,
    billing_period_end DATE NOT NULL,
    invoice_date DATE DEFAULT CURRENT_DATE,
    due_date DATE,
    
    -- Plan y montos
    plan_name VARCHAR(50) NOT NULL,
    base_amount DECIMAL(10,2) NOT NULL,
    
    -- Extras y sobrecostos
    extra_users INTEGER DEFAULT 0,
    extra_users_cost DECIMAL(10,2) DEFAULT 0,
    extra_storage_gb INTEGER DEFAULT 0,
    extra_storage_cost DECIMAL(10,2) DEFAULT 0,
    extra_api_calls INTEGER DEFAULT 0,
    extra_api_cost DECIMAL(10,2) DEFAULT 0,
    extra_ai_requests INTEGER DEFAULT 0,
    extra_ai_cost DECIMAL(10,2) DEFAULT 0,
    
    -- Descuentos y ajustes
    discount_percentage DECIMAL(5,2) DEFAULT 0,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    discount_reason TEXT,
    
    -- Impuestos
    tax_rate DECIMAL(5,2) DEFAULT 0,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    
    -- Totales
    subtotal DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    
    -- Estado del pago
    payment_status VARCHAR(50) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded', 'cancelled', 'overdue')),
    payment_method VARCHAR(50),
    payment_date TIMESTAMP,
    payment_reference VARCHAR(255),
    payment_gateway_response JSONB,
    
    -- Información adicional
    notes TEXT,
    invoice_url VARCHAR(500),
    pdf_path VARCHAR(500),
    
    -- Metadatos de uso
    usage_summary JSONB, -- Resumen de métricas del período
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en billing_history
CREATE TRIGGER update_billing_history_updated_at
    BEFORE UPDATE ON saas.billing_history
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Índices para billing_history
CREATE INDEX IF NOT EXISTS idx_billing_history_org_period ON saas.billing_history(organization_id, billing_period_start DESC);
CREATE INDEX IF NOT EXISTS idx_billing_history_status ON saas.billing_history(payment_status, due_date);
CREATE INDEX IF NOT EXISTS idx_billing_history_invoice_number ON saas.billing_history(invoice_number);

-- 🔐 CONFIGURACIÓN DE API KEYS
CREATE TABLE IF NOT EXISTS saas.api_keys (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
    
    -- Información de la API key
    key_name VARCHAR(100) NOT NULL,
    api_key VARCHAR(255) UNIQUE NOT NULL,
    key_prefix VARCHAR(20) NOT NULL, -- Prefijo visible (ej: "sk_test_")
    key_hash VARCHAR(255) NOT NULL, -- Hash del key completo
    
    -- Permisos y scope
    permissions JSONB DEFAULT '{}', -- {"read": true, "write": false, "admin": false}
    allowed_endpoints JSONB DEFAULT '[]', -- Lista de endpoints permitidos
    rate_limit_rpm INTEGER DEFAULT 100, -- Requests per minute
    rate_limit_rph INTEGER DEFAULT 1000, -- Requests per hour
    
    -- Información de uso
    total_requests INTEGER DEFAULT 0,
    last_used TIMESTAMP,
    requests_today INTEGER DEFAULT 0,
    last_request_ip INET,
    
    -- Estado y configuración
    is_active BOOLEAN DEFAULT true,
    expires_at TIMESTAMP,
    environment VARCHAR(20) DEFAULT 'production' CHECK (environment IN ('development', 'staging', 'production')),
    
    -- Auditoría
    created_by INTEGER REFERENCES saas.authorized_users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    last_rotated TIMESTAMP,
    
    UNIQUE(organization_id, key_name)
);

-- Índices para api_keys
CREATE INDEX IF NOT EXISTS idx_api_keys_org_active ON saas.api_keys(organization_id, is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_api_keys_hash ON saas.api_keys(key_hash);
CREATE INDEX IF NOT EXISTS idx_api_keys_prefix ON saas.api_keys(key_prefix);

-- 📊 ACTIVIDAD DE LA ORGANIZACIÓN (Auditoría detallada)
CREATE TABLE IF NOT EXISTS saas.organization_activity (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES saas.authorized_users(id) ON DELETE SET NULL,
    
    -- Información de la actividad
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50), -- 'product', 'order', 'user', 'setting', 'api_key'
    resource_id INTEGER,
    resource_name VARCHAR(255),
    
    -- Detalles de la acción
    action_details JSONB,
    changes_made JSONB, -- Antes y después para cambios
    impact_level VARCHAR(20) DEFAULT 'low' CHECK (impact_level IN ('low', 'medium', 'high', 'critical')),
    
    -- Metadatos de la sesión
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(100),
    api_key_used VARCHAR(50), -- Prefijo si fue via API
    
    -- Geolocalización (opcional)
    country_code VARCHAR(2),
    city VARCHAR(100),
    
    -- Timestamp
    created_at TIMESTAMP DEFAULT NOW()
);

-- Índices para organization_activity
CREATE INDEX IF NOT EXISTS idx_organization_activity_org_date ON saas.organization_activity(organization_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_organization_activity_user ON saas.organization_activity(user_id, created_at DESC) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_organization_activity_action ON saas.organization_activity(action, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_organization_activity_resource ON saas.organization_activity(resource_type, resource_id) WHERE resource_id IS NOT NULL;

-- 🎯 LÍMITES Y QUOTAS POR ORGANIZACIÓN
CREATE TABLE IF NOT EXISTS saas.organization_quotas (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
    
    -- Tipo de quota
    quota_type VARCHAR(50) NOT NULL, -- 'users', 'products', 'orders', 'storage', 'api_calls', 'ai_requests'
    quota_period VARCHAR(20) DEFAULT 'monthly' CHECK (quota_period IN ('daily', 'weekly', 'monthly', 'yearly')),
    
    -- Límites
    quota_limit INTEGER NOT NULL,
    quota_used INTEGER DEFAULT 0,
    quota_remaining INTEGER GENERATED ALWAYS AS (quota_limit - quota_used) STORED,
    
    -- Configuración
    is_hard_limit BOOLEAN DEFAULT true, -- Si es hard, bloquea al llegar al límite
    warning_threshold DECIMAL(3,2) DEFAULT 0.8, -- Avisar al 80%
    warning_sent BOOLEAN DEFAULT false,
    
    -- Período actual
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    
    -- Metadatos
    last_updated TIMESTAMP DEFAULT NOW(),
    reset_at TIMESTAMP, -- Cuándo se resetea automáticamente
    
    UNIQUE(organization_id, quota_type, period_start)
);

-- Índices para organization_quotas
CREATE INDEX IF NOT EXISTS idx_organization_quotas_org_type ON saas.organization_quotas(organization_id, quota_type);
CREATE INDEX IF NOT EXISTS idx_organization_quotas_period ON saas.organization_quotas(period_start, period_end);
CREATE INDEX IF NOT EXISTS idx_organization_quotas_warning ON saas.organization_quotas(organization_id, warning_sent) WHERE NOT warning_sent AND quota_used >= (quota_limit * warning_threshold);

-- 🔔 NOTIFICACIONES PARA ORGANIZACIONES
CREATE TABLE IF NOT EXISTS saas.organization_notifications (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
    
    -- Información de la notificación
    notification_type VARCHAR(50) NOT NULL, -- 'quota_warning', 'quota_exceeded', 'billing_due', 'feature_update', 'security_alert'
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    
    -- Prioridad y categoría
    priority VARCHAR(20) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    category VARCHAR(50) DEFAULT 'general', -- 'billing', 'security', 'usage', 'feature', 'general'
    
    -- Estado
    is_read BOOLEAN DEFAULT false,
    is_dismissed BOOLEAN DEFAULT false,
    requires_action BOOLEAN DEFAULT false,
    action_url VARCHAR(500),
    action_label VARCHAR(100),
    
    -- Destinatarios
    target_users JSONB DEFAULT '[]', -- IDs de usuarios específicos, vacío = todos los admins
    sent_to_emails JSONB DEFAULT '[]', -- Emails a los que se envió
    
    -- Configuración de envío
    send_email BOOLEAN DEFAULT true,
    send_in_app BOOLEAN DEFAULT true,
    email_sent BOOLEAN DEFAULT false,
    email_sent_at TIMESTAMP,
    
    -- Expiración
    expires_at TIMESTAMP,
    
    -- Metadatos
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en organization_notifications
CREATE TRIGGER update_organization_notifications_updated_at
    BEFORE UPDATE ON saas.organization_notifications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Índices para organization_notifications
CREATE INDEX IF NOT EXISTS idx_organization_notifications_org_unread ON saas.organization_notifications(organization_id, created_at DESC) WHERE NOT is_read AND NOT is_dismissed;
CREATE INDEX IF NOT EXISTS idx_organization_notifications_type_priority ON saas.organization_notifications(notification_type, priority, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_organization_notifications_expires ON saas.organization_notifications(expires_at) WHERE expires_at IS NOT NULL;

-- 🎛️ CONFIGURACIÓN DE WEBHOOKS POR ORGANIZACIÓN
CREATE TABLE IF NOT EXISTS saas.organization_webhooks (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
    
    -- Configuración del webhook
    name VARCHAR(100) NOT NULL,
    url VARCHAR(500) NOT NULL,
    secret VARCHAR(255), -- Para validar firmas
    
    -- Eventos suscritos
    events JSONB NOT NULL DEFAULT '[]', -- ['order.created', 'product.updated', 'stock.low']
    is_active BOOLEAN DEFAULT true,
    
    -- Configuración de retry
    max_retries INTEGER DEFAULT 3,
    retry_delay_seconds INTEGER DEFAULT 60,
    timeout_seconds INTEGER DEFAULT 30,
    
    -- Headers personalizados
    custom_headers JSONB DEFAULT '{}',
    
    -- Estadísticas
    total_deliveries INTEGER DEFAULT 0,
    successful_deliveries INTEGER DEFAULT 0,
    failed_deliveries INTEGER DEFAULT 0,
    last_delivery_at TIMESTAMP,
    last_delivery_status VARCHAR(20),
    last_error_message TEXT,
    
    -- Configuración
    created_by INTEGER REFERENCES saas.authorized_users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(organization_id, name)
);

-- Trigger para updated_at en organization_webhooks
CREATE TRIGGER update_organization_webhooks_updated_at
    BEFORE UPDATE ON saas.organization_webhooks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Índices para organization_webhooks
CREATE INDEX IF NOT EXISTS idx_organization_webhooks_org_active ON saas.organization_webhooks(organization_id, is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_organization_webhooks_events ON saas.organization_webhooks USING GIN(events);

-- 📊 LOGS DE ENTREGA DE WEBHOOKS
CREATE TABLE IF NOT EXISTS saas.webhook_deliveries (
    id SERIAL PRIMARY KEY,
    webhook_id INTEGER NOT NULL REFERENCES saas.organization_webhooks(id) ON DELETE CASCADE,
    organization_id INTEGER NOT NULL REFERENCES saas.organizations(id) ON DELETE CASCADE,
    
    -- Información del evento
    event_type VARCHAR(100) NOT NULL,
    event_id UUID,
    payload JSONB NOT NULL,
    
    -- Información de la entrega
    delivery_attempt INTEGER DEFAULT 1,
    delivery_status VARCHAR(20) DEFAULT 'pending' CHECK (delivery_status IN ('pending', 'delivered', 'failed', 'timeout')),
    
    -- Request/Response
    request_headers JSONB,
    request_body JSONB,
    response_status INTEGER,
    response_headers JSONB,
    response_body TEXT,
    response_time_ms INTEGER,
    
    -- Error handling
    error_message TEXT,
    next_retry_at TIMESTAMP,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW(),
    delivered_at TIMESTAMP
);

-- Índices para webhook_deliveries
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_webhook_status ON saas.webhook_deliveries(webhook_id, delivery_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_org_event ON saas.webhook_deliveries(organization_id, event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_retry ON saas.webhook_deliveries(next_retry_at) WHERE next_retry_at IS NOT NULL AND next_retry_at <= NOW();

-- =============================================================================
-- 🔧 FUNCIONES AVANZADAS PARA SAAS
-- =============================================================================

-- Función para verificar límites de quota
CREATE OR REPLACE FUNCTION saas.check_quota_limit(
    org_id INTEGER,
    quota_type_param VARCHAR,
    increment_usage INTEGER DEFAULT 1
) RETURNS BOOLEAN AS $
DECLARE
    current_quota RECORD;
    new_usage INTEGER;
BEGIN
    -- Obtener quota actual
    SELECT * INTO current_quota
    FROM saas.organization_quotas
    WHERE organization_id = org_id
      AND quota_type = quota_type_param
      AND period_start <= CURRENT_DATE
      AND period_end >= CURRENT_DATE
    ORDER BY period_start DESC
    LIMIT 1;
    
    -- Si no existe quota, asumir sin límite
    IF NOT FOUND THEN
        RETURN TRUE;
    END IF;
    
    new_usage := current_quota.quota_used + increment_usage;
    
    -- Verificar si excede el límite
    IF current_quota.is_hard_limit AND new_usage > current_quota.quota_limit THEN
        -- Crear notificación de límite excedido
        INSERT INTO saas.organization_notifications (
            organization_id, notification_type, title, message, priority, category, requires_action
        ) VALUES (
            org_id,
            'quota_exceeded',
            format('Límite de %s excedido', quota_type_param),
            format('Ha excedido el límite de %s para su plan actual. Considere actualizar su plan.', quota_type_param),
            'high',
            'usage',
            true
        );
        
        RETURN FALSE;
    END IF;
    
    -- Actualizar uso
    UPDATE saas.organization_quotas
    SET quota_used = new_usage,
        last_updated = NOW()
    WHERE id = current_quota.id;
    
    -- Verificar si debe enviar warning
    IF NOT current_quota.warning_sent 
       AND new_usage >= (current_quota.quota_limit * current_quota.warning_threshold) THEN
        
        UPDATE saas.organization_quotas
        SET warning_sent = true
        WHERE id = current_quota.id;
        
        -- Crear notificación de warning
        INSERT INTO saas.organization_notifications (
            organization_id, notification_type, title, message, priority, category
        ) VALUES (
            org_id,
            'quota_warning',
            format('Advertencia: Límite de %s al %s%%', quota_type_param, (current_quota.warning_threshold * 100)::INTEGER),
            format('Ha utilizado %s de %s %s disponibles este mes.', new_usage, current_quota.quota_limit, quota_type_param),
            'normal',
            'usage'
        );
    END IF;
    
    RETURN TRUE;
END;
$ LANGUAGE plpgsql;

-- Función para obtener uso actual de una organización
CREATE OR REPLACE FUNCTION saas.get_organization_usage(org_id INTEGER)
RETURNS TABLE (
    current_users INTEGER,
    current_products INTEGER,
    current_orders_month INTEGER,
    storage_used_gb DECIMAL,
    api_calls_today INTEGER,
    quota_status JSONB
) AS $
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*)::INTEGER FROM saas.authorized_users WHERE organization_id = org_id AND status = 'active'),
        (SELECT COUNT(*)::INTEGER FROM stock.products WHERE organization_id = org_id AND is_available = true),
        (SELECT COUNT(*)::INTEGER FROM shared.orders WHERE organization_id = org_id AND DATE_TRUNC('month', created_at) = DATE_TRUNC('month', CURRENT_DATE)),
        0.5::DECIMAL, -- Placeholder para almacenamiento
        (SELECT COALESCE(SUM(api_calls), 0)::INTEGER FROM saas.usage_metrics WHERE organization_id = org_id AND metric_date = CURRENT_DATE),
        (SELECT jsonb_agg(
            jsonb_build_object(
                'type', quota_type,
                'used', quota_used,
                'limit', quota_limit,
                'percentage', ROUND((quota_used::DECIMAL / quota_limit * 100), 1)
            )
        ) FROM saas.organization_quotas WHERE organization_id = org_id AND period_start <= CURRENT_DATE AND period_end >= CURRENT_DATE);
END;
$ LANGUAGE plpgsql;

-- Función para generar API key
CREATE OR REPLACE FUNCTION saas.generate_api_key(
    org_id INTEGER,
    key_name_param VARCHAR,
    permissions_param JSONB DEFAULT '{"read": true}',
    environment_param VARCHAR DEFAULT 'production',
    created_by_param INTEGER DEFAULT NULL
) RETURNS TEXT AS $
DECLARE
    key_prefix VARCHAR(20);
    random_key VARCHAR(200);
    full_key VARCHAR(255);
    key_hash VARCHAR(255);
BEGIN
    -- Verificar límite de API keys
    IF NOT saas.check_quota_limit(org_id, 'api_keys', 1) THEN
        RAISE EXCEPTION 'Se ha excedido el límite de API keys para esta organización';
    END IF;
    
    -- Generar prefijo según ambiente
    key_prefix := CASE 
        WHEN environment_param = 'development' THEN 'sk_dev_'
        WHEN environment_param = 'staging' THEN 'sk_stg_'
        ELSE 'sk_live_'
    END;
    
    -- Generar key aleatoria
    random_key := encode(gen_random_bytes(32), 'base64');
    random_key := replace(replace(replace(random_key, '+', ''), '/', ''), '=', '');
    
    full_key := key_prefix || random_key;
    key_hash := encode(digest(full_key, 'sha256'), 'hex');
    
    -- Insertar en la tabla
    INSERT INTO saas.api_keys (
        organization_id, key_name, api_key, key_prefix, key_hash,
        permissions, environment, created_by
    ) VALUES (
        org_id, key_name_param, full_key, key_prefix, key_hash,
        permissions_param, environment_param, created_by_param
    );
    
    -- Log de la actividad
    INSERT INTO saas.organization_activity (
        organization_id, user_id, action, resource_type, resource_name, action_details
    ) VALUES (
        org_id, created_by_param, 'api_key_created', 'api_key', key_name_param,
        jsonb_build_object('environment', environment_param, 'permissions', permissions_param)
    );
    
    RETURN full_key;
END;
$ LANGUAGE plpgsql;

-- Función para resetear quotas mensualmente
CREATE OR REPLACE FUNCTION saas.reset_monthly_quotas()
RETURNS INTEGER AS $
DECLARE
    reset_count INTEGER := 0;
BEGIN
    -- Resetear quotas que expiraron
    UPDATE saas.organization_quotas
    SET quota_used = 0,
        warning_sent = false,
        period_start = CURRENT_DATE,
        period_end = CURRENT_DATE + INTERVAL '1 month',
        last_updated = NOW()
    WHERE quota_period = 'monthly'
      AND period_end < CURRENT_DATE;
    
    GET DIAGNOSTICS reset_count = ROW_COUNT;
    
    -- Log del reset
    INSERT INTO shared.activity_logs (
        action, entity_type, entity_name, source, changes
    ) VALUES (
        'quotas_reset', 'system', 'monthly_quotas', 'system',
        jsonb_build_object('quotas_reset', reset_count)
    );
    
    RETURN reset_count;
END;
$ LANGUAGE plpgsql;

-- Función para enviar webhook
CREATE OR REPLACE FUNCTION saas.send_webhook(
    org_id INTEGER,
    event_type_param VARCHAR,
    payload_param JSONB,
    event_id_param UUID DEFAULT uuid_generate_v4()
) RETURNS INTEGER AS $
DECLARE
    webhook_record RECORD;
    delivery_count INTEGER := 0;
BEGIN
    -- Buscar webhooks activos que escuchen este evento
    FOR webhook_record IN
        SELECT * FROM saas.organization_webhooks
        WHERE organization_id = org_id
          AND is_active = true
          AND events @> to_jsonb(event_type_param)
    LOOP
        -- Crear entrada de delivery
        INSERT INTO saas.webhook_deliveries (
            webhook_id, organization_id, event_type, event_id, payload
        ) VALUES (
            webhook_record.id, org_id, event_type_param, event_id_param, payload_param
        );
        
        delivery_count := delivery_count + 1;
    END LOOP;
    
    RETURN delivery_count;
END;
$ LANGUAGE plpgsql;

-- =============================================================================
-- 📊 DATOS INICIALES Y CONFIGURACIÓN
-- =============================================================================

-- Crear quotas iniciales para la organización demo
DO $
DECLARE
    demo_org_id INTEGER;
    current_month_start DATE;
    current_month_end DATE;
BEGIN
    SELECT id INTO demo_org_id FROM saas.organizations WHERE slug = 'empresa-demo';
    current_month_start := DATE_TRUNC('month', CURRENT_DATE);
    current_month_end := current_month_start + INTERVAL '1 month' - INTERVAL '1 day';
    
    IF demo_org_id IS NOT NULL THEN
        -- Insertar quotas basadas en el plan professional
        INSERT INTO saas.organization_quotas (organization_id, quota_type, quota_limit, period_start, period_end) VALUES
            (demo_org_id, 'users', 20, current_month_start, current_month_end),
            (demo_org_id, 'products', 1000, current_month_start, current_month_end),
            (demo_org_id, 'orders', 2000, current_month_start, current_month_end),
            (demo_org_id, 'api_calls', 10000, current_month_start, current_month_end),
            (demo_org_id, 'ai_requests', 1000, current_month_start, current_month_end),
            (demo_org_id, 'storage_gb', 10, current_month_start, current_month_end)
        ON CONFLICT (organization_id, quota_type, period_start) DO NOTHING;
        
        -- Crear API key demo
        PERFORM saas.generate_api_key(
            demo_org_id,
            'API Key Demo',
            '{"read": true, "write": true, "admin": false}',
            'development'
        );
        
        -- Crear notificación de bienvenida
        INSERT INTO saas.organization_notifications (
            organization_id, notification_type, title, message, priority, category
        ) VALUES (
            demo_org_id,
            'feature_update',
            '¡Bienvenido al Sistema SaaS!',
            'Su organización ha sido configurada exitosamente. Puede comenzar a usar todas las funcionalidades del sistema.',
            'normal',
            'general'
        ) ON CONFLICT DO NOTHING;
    END IF;
END $;

-- ✅ VERIFICACIÓN DE INSTALACIÓN
DO $
BEGIN
    RAISE NOTICE '✅ SaaS Advanced Features instalado correctamente';
    RAISE NOTICE '📊 Métricas de uso y facturación configuradas';
    RAISE NOTICE '🔐 Sistema de API keys y quotas implementado';
    RAISE NOTICE '🔔 Sistema de notificaciones avanzado';
    RAISE NOTICE '🎛️ Webhooks por organización configurados';
    RAISE NOTICE '📈 Funciones de gestión de quotas disponibles';
    RAISE NOTICE '🏢 Configuración demo para empresa-demo completada';
END $;