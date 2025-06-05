-- ============================================================================
-- 🔧 MISSING CRITICAL TABLES - ELEMENTOS CRÍTICOS ADICIONALES
-- ============================================================================
-- Archivo: init-scripts/04_missing_critical.sql
-- Propósito: Elementos críticos adicionales que no están en otros archivos
-- Dependencias: 00_core_schema.sql, 01_stock_management.sql, 02_shared_tables.sql
-- Orden de ejecución: CUARTO (04_)
-- ============================================================================

-- NOTA: La mayoría del contenido original se ha integrado en archivos anteriores
-- Este archivo ahora contiene solo elementos adicionales únicos

-- 🔄 SECUENCIAS ADICIONALES PARA NÚMEROS ÚNICOS
-- Secuencia para números de lote
CREATE SEQUENCE IF NOT EXISTS stock.batch_number_seq START 1;

-- Función para generar números de lote únicos
CREATE OR REPLACE FUNCTION stock.generate_batch_number(org_id INTEGER, product_prefix TEXT DEFAULT 'BATCH')
RETURNS TEXT AS $$
DECLARE
    next_val BIGINT;
    org_prefix TEXT;
BEGIN
    SELECT nextval('stock.batch_number_seq') INTO next_val;
    
    -- Obtener prefijo de la organización
    SELECT COALESCE(slug, 'ORG') INTO org_prefix 
    FROM saas.organizations 
    WHERE id = org_id;
    
    RETURN upper(org_prefix) || '-' || product_prefix || '-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(next_val::TEXT, 4, '0');
END;
$$ LANGUAGE plpgsql;

-- 📊 CONFIGURACIÓN DE BACKUP Y MANTENIMIENTO
CREATE TABLE IF NOT EXISTS shared.maintenance_tasks (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES saas.organizations(id) ON DELETE CASCADE,
    
    -- Información de la tarea
    task_name VARCHAR(100) NOT NULL,
    task_type VARCHAR(50) NOT NULL CHECK (task_type IN ('backup', 'cleanup', 'optimization', 'analytics', 'reports')),
    task_description TEXT,
    
    -- Configuración de ejecución
    is_enabled BOOLEAN DEFAULT true,
    schedule_cron VARCHAR(50), -- Formato cron
    last_run TIMESTAMP,
    next_run TIMESTAMP,
    
    -- Configuración específica
    task_config JSONB DEFAULT '{}',
    timeout_minutes INTEGER DEFAULT 60,
    
    -- Resultados de ejecución
    last_status VARCHAR(20) DEFAULT 'pending' CHECK (last_status IN ('pending', 'running', 'completed', 'failed', 'timeout')),
    last_duration_seconds INTEGER,
    last_error_message TEXT,
    execution_count INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    
    -- Metadatos
    created_by INTEGER REFERENCES saas.authorized_users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(organization_id, task_name)
);

-- Trigger para updated_at en maintenance_tasks
CREATE TRIGGER update_maintenance_tasks_updated_at
    BEFORE UPDATE ON shared.maintenance_tasks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 📊 LOG DE EJECUCIÓN DE TAREAS
CREATE TABLE IF NOT EXISTS shared.maintenance_task_logs (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES shared.maintenance_tasks(id) ON DELETE CASCADE,
    organization_id INTEGER REFERENCES saas.organizations(id) ON DELETE CASCADE,
    
    -- Información de la ejecución
    execution_id UUID DEFAULT uuid_generate_v4(),
    status VARCHAR(20) NOT NULL CHECK (status IN ('started', 'completed', 'failed', 'timeout')),
    
    -- Datos de ejecución
    started_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    duration_seconds INTEGER,
    
    -- Resultados
    records_processed INTEGER DEFAULT 0,
    records_success INTEGER DEFAULT 0,
    records_failed INTEGER DEFAULT 0,
    
    -- Logs y errores
    output_log TEXT,
    error_message TEXT,
    metadata JSONB DEFAULT '{}'
);

-- Índices para maintenance_task_logs
CREATE INDEX IF NOT EXISTS idx_maintenance_task_logs_task_date ON shared.maintenance_task_logs(task_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_maintenance_task_logs_org_status ON shared.maintenance_task_logs(organization_id, status);
CREATE INDEX IF NOT EXISTS idx_maintenance_task_logs_execution_id ON shared.maintenance_task_logs(execution_id);

-- 🔐 TOKENS DE ACCESO TEMPORAL
CREATE TABLE IF NOT EXISTS shared.access_tokens (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES saas.organizations(id) ON DELETE CASCADE,
    
    -- Información del token
    token_value VARCHAR(255) UNIQUE NOT NULL,
    token_type VARCHAR(50) NOT NULL CHECK (token_type IN ('password_reset', 'email_verification', 'api_temp', 'webhook_auth', 'invitation')),
    
    -- Asociaciones
    user_id INTEGER REFERENCES saas.authorized_users(id) ON DELETE CASCADE,
    email VARCHAR(255),
    
    -- Configuración
    expires_at TIMESTAMP NOT NULL,
    is_single_use BOOLEAN DEFAULT true,
    is_used BOOLEAN DEFAULT false,
    used_at TIMESTAMP,
    used_by_ip INET,
    
    -- Metadatos
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

-- Índices para access_tokens
CREATE INDEX IF NOT EXISTS idx_access_tokens_value ON shared.access_tokens(token_value) WHERE NOT is_used;
CREATE INDEX IF NOT EXISTS idx_access_tokens_org_type ON shared.access_tokens(organization_id, token_type) WHERE NOT is_used;
CREATE INDEX IF NOT EXISTS idx_access_tokens_expires ON shared.access_tokens(expires_at) WHERE NOT is_used;
CREATE INDEX IF NOT EXISTS idx_access_tokens_user ON shared.access_tokens(user_id) WHERE NOT is_used;

-- 📱 CONFIGURACIÓN DE DISPOSITIVOS/APPS
CREATE TABLE IF NOT EXISTS shared.device_registrations (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES saas.organizations(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES saas.authorized_users(id) ON DELETE CASCADE,
    
    -- Información del dispositivo
    device_id VARCHAR(255) UNIQUE NOT NULL,
    device_name VARCHAR(255),
    device_type VARCHAR(50) CHECK (device_type IN ('mobile', 'tablet', 'desktop', 'browser')),
    platform VARCHAR(50), -- 'ios', 'android', 'web', 'windows', 'mac'
    app_version VARCHAR(50),
    
    -- Push notifications
    push_token VARCHAR(500),
    push_enabled BOOLEAN DEFAULT true,
    
    -- Configuración
    is_active BOOLEAN DEFAULT true,
    last_activity TIMESTAMP DEFAULT NOW(),
    
    -- Metadatos de sesión
    user_agent TEXT,
    ip_address INET,
    timezone VARCHAR(50),
    language VARCHAR(10),
    
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en device_registrations
CREATE TRIGGER update_device_registrations_updated_at
    BEFORE UPDATE ON shared.device_registrations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Índices para device_registrations
CREATE INDEX IF NOT EXISTS idx_device_registrations_org_user ON shared.device_registrations(organization_id, user_id);
CREATE INDEX IF NOT EXISTS idx_device_registrations_device_id ON shared.device_registrations(device_id);
CREATE INDEX IF NOT EXISTS idx_device_registrations_active ON shared.device_registrations(is_active, last_activity DESC) WHERE is_active = true;

-- =============================================================================
-- 🔧 FUNCIONES ADICIONALES CRÍTICAS
-- =============================================================================

-- Función para generar token seguro
CREATE OR REPLACE FUNCTION shared.generate_secure_token(
    org_id INTEGER,
    token_type_param VARCHAR,
    user_id_param INTEGER DEFAULT NULL,
    email_param VARCHAR DEFAULT NULL,
    expires_in_minutes INTEGER DEFAULT 60
) RETURNS TEXT AS $$
DECLARE
    token_value TEXT;
    expires_at_val TIMESTAMP;
BEGIN
    -- Generar token seguro
    token_value := encode(gen_random_bytes(32), 'base64');
    token_value := replace(replace(replace(token_value, '+', ''), '/', ''), '=', '');
    token_value := substring(token_value, 1, 32);
    
    expires_at_val := NOW() + (expires_in_minutes || ' minutes')::INTERVAL;
    
    -- Insertar token
    INSERT INTO shared.access_tokens (
        organization_id, token_value, token_type, user_id, email, expires_at
    ) VALUES (
        org_id, token_value, token_type_param, user_id_param, email_param, expires_at_val
    );
    
    RETURN token_value;
END;
$$ LANGUAGE plpgsql;

-- Función para validar token
CREATE OR REPLACE FUNCTION shared.validate_access_token(
    token_param VARCHAR,
    token_type_param VARCHAR DEFAULT NULL
) RETURNS TABLE (
    is_valid BOOLEAN,
    organization_id INTEGER,
    user_id INTEGER,
    email VARCHAR,
    metadata JSONB
) AS $$
DECLARE
    token_record RECORD;
BEGIN
    -- Buscar token
    SELECT * INTO token_record
    FROM shared.access_tokens
    WHERE token_value = token_param
      AND (token_type_param IS NULL OR token_type = token_type_param)
      AND NOT is_used
      AND expires_at > NOW();
    
    IF FOUND THEN
        -- Marcar como usado si es single use
        IF token_record.is_single_use THEN
            UPDATE shared.access_tokens
            SET is_used = true, used_at = NOW()
            WHERE id = token_record.id;
        END IF;
        
        RETURN QUERY SELECT
            true,
            token_record.organization_id,
            token_record.user_id,
            token_record.email,
            token_record.metadata;
    ELSE
        RETURN QUERY SELECT
            false,
            NULL::INTEGER,
            NULL::INTEGER,
            NULL::VARCHAR,
            '{}'::JSONB;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Función para limpiar tokens expirados
CREATE OR REPLACE FUNCTION shared.cleanup_expired_tokens()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM shared.access_tokens
    WHERE expires_at < NOW() OR (is_used = true AND used_at < NOW() - INTERVAL '7 days');
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Log del cleanup
    INSERT INTO shared.activity_logs (
        action, entity_type, entity_name, source, changes
    ) VALUES (
        'cleanup_expired_tokens', 'system', 'access_tokens', 'system',
        jsonb_build_object('deleted_tokens', deleted_count)
    );
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Función para registrar dispositivo
CREATE OR REPLACE FUNCTION shared.register_device(
    org_id INTEGER,
    user_id_param INTEGER,
    device_id_param VARCHAR,
    device_info JSONB
) RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO shared.device_registrations (
        organization_id, user_id, device_id, device_name, device_type, 
        platform, app_version, push_token, user_agent, ip_address
    ) VALUES (
        org_id, user_id_param, device_id_param,
        device_info->>'device_name',
        device_info->>'device_type',
        device_info->>'platform',
        device_info->>'app_version',
        device_info->>'push_token',
        device_info->>'user_agent',
        (device_info->>'ip_address')::INET
    )
    ON CONFLICT (device_id) 
    DO UPDATE SET
        user_id = EXCLUDED.user_id,
        device_name = EXCLUDED.device_name,
        is_active = true,
        last_activity = NOW(),
        updated_at = NOW();
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 🔒 ROW LEVEL SECURITY PARA TABLAS ADICIONALES
-- =============================================================================

-- Habilitar RLS en maintenance_tasks
ALTER TABLE shared.maintenance_tasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY maintenance_tasks_isolation ON shared.maintenance_tasks
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id() OR organization_id IS NULL);

-- Habilitar RLS en maintenance_task_logs
ALTER TABLE shared.maintenance_task_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY maintenance_task_logs_isolation ON shared.maintenance_task_logs
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id() OR organization_id IS NULL);

-- Habilitar RLS en access_tokens
ALTER TABLE shared.access_tokens ENABLE ROW LEVEL SECURITY;
CREATE POLICY access_tokens_isolation ON shared.access_tokens
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id() OR organization_id IS NULL);

-- Habilitar RLS en device_registrations
ALTER TABLE shared.device_registrations ENABLE ROW LEVEL SECURITY;
CREATE POLICY device_registrations_isolation ON shared.device_registrations
    FOR ALL TO PUBLIC
    USING (organization_id = current_organization_id());

-- =============================================================================
-- 📊 DATOS INICIALES
-- =============================================================================

-- Tareas de mantenimiento por defecto para la organización demo
DO $$
DECLARE
    demo_org_id INTEGER;
BEGIN
    SELECT id INTO demo_org_id FROM saas.organizations WHERE slug = 'empresa-demo';
    
    IF demo_org_id IS NOT NULL THEN
        INSERT INTO shared.maintenance_tasks (organization_id, task_name, task_type, task_description, schedule_cron) VALUES
            (demo_org_id, 'cleanup_expired_sessions', 'cleanup', 'Limpiar sesiones expiradas', '0 2 * * *'),
            (demo_org_id, 'cleanup_old_logs', 'cleanup', 'Limpiar logs antiguos', '0 3 * * 0'),
            (demo_org_id, 'refresh_materialized_views', 'optimization', 'Refrescar vistas materializadas', '0 1 * * *'),
            (demo_org_id, 'calculate_metrics', 'analytics', 'Calcular métricas diarias', '0 0 * * *'),
            (demo_org_id, 'backup_critical_data', 'backup', 'Backup de datos críticos', '0 4 * * *')
        ON CONFLICT (organization_id, task_name) DO NOTHING;
    END IF;
    
    -- Tareas globales (sin organization_id)
    INSERT INTO shared.maintenance_tasks (organization_id, task_name, task_type, task_description, schedule_cron) VALUES
        (NULL, 'cleanup_expired_tokens', 'cleanup', 'Limpiar tokens expirados globalmente', '0 */6 * * *'),
        (NULL, 'system_health_check', 'optimization', 'Verificación de salud del sistema', '*/30 * * * *'),
        (NULL, 'reset_monthly_quotas', 'analytics', 'Reset de quotas mensuales', '0 0 1 * *')
    ON CONFLICT (organization_id, task_name) DO NOTHING;
END $$;

-- ✅ VERIFICACIÓN DE INSTALACIÓN
DO $$
BEGIN
    RAISE NOTICE '✅ Missing Critical Elements instalados correctamente';
    RAISE NOTICE '🔄 Funciones adicionales de generación de tokens y lotes';
    RAISE NOTICE '📊 Sistema de tareas de mantenimiento configurado';
    RAISE NOTICE '🔐 Tokens de acceso temporal implementados';
    RAISE NOTICE '📱 Registro de dispositivos disponible';
    RAISE NOTICE '🔒 Row Level Security habilitado en todas las tablas nuevas';
    RAISE NOTICE '⚙️ Tareas de mantenimiento iniciales creadas';
END $$;