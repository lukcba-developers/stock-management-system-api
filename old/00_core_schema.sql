-- ============================================================================
-- 🏗️ CORE SCHEMA - ESTRUCTURA BASE DEL SISTEMA
-- ============================================================================
-- Archivo: init-scripts/00_core_schema.sql
-- Propósito: Estructura base compartida por todos los componentes
-- Orden de ejecución: PRIMERO (00_)
-- ============================================================================

-- 🔧 EXTENSIONES REQUERIDAS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- Para búsquedas fuzzy

-- 🏢 CREACIÓN DE ESQUEMAS ORGANIZADOS
CREATE SCHEMA IF NOT EXISTS stock;      -- Sistema de Stock Management
CREATE SCHEMA IF NOT EXISTS shared;     -- Datos compartidos (órdenes, sesiones)
CREATE SCHEMA IF NOT EXISTS n8n;        -- Configuración específica N8N
CREATE SCHEMA IF NOT EXISTS analytics;  -- Vistas y reportes

-- 🔐 CONFIGURACIÓN DE PERMISOS
DO $$
BEGIN
    -- Crear usuario si no existe
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'commerce_user') THEN
        CREATE ROLE commerce_user WITH LOGIN PASSWORD 'secure_password_123';
    END IF;
END $$;

-- Otorgar permisos a todos los esquemas
GRANT ALL PRIVILEGES ON SCHEMA stock TO commerce_user;
GRANT ALL PRIVILEGES ON SCHEMA shared TO commerce_user;
GRANT ALL PRIVILEGES ON SCHEMA n8n TO commerce_user;
GRANT ALL PRIVILEGES ON SCHEMA analytics TO commerce_user;
GRANT ALL PRIVILEGES ON SCHEMA public TO commerce_user;

-- ⚙️ FUNCIONES UTILITARIAS GLOBALES
-- Función para timestamps automáticos
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Función para generar números de orden únicos
CREATE OR REPLACE FUNCTION generate_order_number(prefix TEXT DEFAULT 'ORD')
RETURNS TEXT AS $$
DECLARE
    sequence_name TEXT;
    next_val BIGINT;
BEGIN
    sequence_name := lower(prefix) || '_sequence';
    
    -- Crear secuencia si no existe
    EXECUTE format('CREATE SEQUENCE IF NOT EXISTS %I START 1', sequence_name);
    
    -- Obtener siguiente valor
    EXECUTE format('SELECT nextval(%L)', sequence_name) INTO next_val;
    
    -- Retornar número formateado
    RETURN prefix || '-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(next_val::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;

-- Función para generar hash único de mensaje
CREATE OR REPLACE FUNCTION generate_message_hash(
    customer_phone TEXT,
    message_content TEXT,
    timestamp_val TIMESTAMP DEFAULT NOW()
)
RETURNS TEXT AS $$
BEGIN
    RETURN md5(customer_phone || message_content || extract(epoch from timestamp_val)::TEXT);
END;
$$ LANGUAGE plpgsql;

-- 📊 TIPOS DE DATOS CUSTOMIZADOS
-- Enum para estados de orden
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'order_status_enum') THEN
        CREATE TYPE order_status_enum AS ENUM (
            'pending', 'confirmed', 'preparing', 'ready', 
            'dispatched', 'delivered', 'cancelled'
        );
    END IF;
END $$;

-- Enum para estados de pago
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status_enum') THEN
        CREATE TYPE payment_status_enum AS ENUM (
            'pending', 'paid', 'failed', 'refunded', 'partial'
        );
    END IF;
END $$;

-- Enum para tipos de movimiento de stock
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'movement_type_enum') THEN
        CREATE TYPE movement_type_enum AS ENUM (
            'in', 'out', 'adjustment', 'transfer', 'loss', 'found'
        );
    END IF;
END $$;

-- Enum para roles de usuario
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role_enum') THEN
        CREATE TYPE user_role_enum AS ENUM (
            'admin', 'editor', 'viewer', 'api'
        );
    END IF;
END $$;

-- Enum para estados de sesión
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'session_state_enum') THEN
        CREATE TYPE session_state_enum AS ENUM (
            'browsing', 'searching', 'viewing_product', 'adding_to_cart',
            'viewing_cart', 'checkout', 'waiting_address', 'confirming_order',
            'order_completed', 'inactive'
        );
    END IF;
END $$;

-- 🔍 CONFIGURACIÓN DE BÚSQUEDA FULL-TEXT
-- Configuración para español
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_ts_config 
        WHERE cfgname = 'spanish_unaccent' 
        AND cfgnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'pg_catalog')
    ) THEN
        CREATE TEXT SEARCH CONFIGURATION spanish_unaccent (COPY = spanish);
    END IF;
END $$;

-- ⚙️ CONFIGURACIÓN DEL SISTEMA
CREATE TABLE IF NOT EXISTS shared.system_config (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value TEXT,
    config_type VARCHAR(20) DEFAULT 'string' CHECK (config_type IN ('string', 'number', 'boolean', 'json')),
    description TEXT,
    is_public BOOLEAN DEFAULT false,
    updated_by INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en system_config
CREATE TRIGGER update_system_config_updated_at
    BEFORE UPDATE ON shared.system_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 📝 TABLA DE LOGS GLOBAL
CREATE TABLE IF NOT EXISTS shared.activity_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    action VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id INTEGER,
    entity_name VARCHAR(255),
    changes JSONB,
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(100),
    source VARCHAR(20) DEFAULT 'web' CHECK (source IN ('web', 'api', 'n8n', 'system')),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Índices para activity_logs
CREATE INDEX IF NOT EXISTS idx_activity_logs_user_date ON shared.activity_logs(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_entity ON shared.activity_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_action_date ON shared.activity_logs(action, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_logs_source ON shared.activity_logs(source, created_at DESC);

-- 🚨 TABLA DE ALERTAS GLOBAL
CREATE TABLE IF NOT EXISTS shared.system_alerts (
    id SERIAL PRIMARY KEY,
    alert_type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    severity VARCHAR(20) DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'error', 'critical')),
    entity_type VARCHAR(50),
    entity_id INTEGER,
    metadata JSONB,
    is_read BOOLEAN DEFAULT false,
    is_resolved BOOLEAN DEFAULT false,
    resolved_at TIMESTAMP,
    resolved_by INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Trigger para updated_at en system_alerts
CREATE TRIGGER update_system_alerts_updated_at
    BEFORE UPDATE ON shared.system_alerts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Índices para system_alerts
CREATE INDEX IF NOT EXISTS idx_system_alerts_type_severity ON shared.system_alerts(alert_type, severity);
CREATE INDEX IF NOT EXISTS idx_system_alerts_unresolved ON shared.system_alerts(created_at DESC) WHERE NOT is_resolved;
CREATE INDEX IF NOT EXISTS idx_system_alerts_entity ON shared.system_alerts(entity_type, entity_id);

-- 📊 CONFIGURACIONES INICIALES DEL SISTEMA
INSERT INTO shared.system_config (config_key, config_value, config_type, description, is_public) VALUES
    -- Configuración general
    ('app_name', 'Sistema de Gestión de Stock', 'string', 'Nombre de la aplicación', true),
    ('app_version', '1.0.0', 'string', 'Versión de la aplicación', true),
    ('currency_symbol', '$', 'string', 'Símbolo de moneda', true),
    ('currency_code', 'ARS', 'string', 'Código de moneda (ISO 4217)', true),
    ('timezone', 'America/Argentina/Buenos_Aires', 'string', 'Zona horaria del sistema', false),
    
    -- Configuración de stock
    ('low_stock_threshold_percentage', '20', 'number', 'Porcentaje de stock mínimo para alertas', false),
    ('auto_reorder_enabled', 'false', 'boolean', 'Habilitar reorden automático', false),
    ('default_tax_rate', '21', 'number', 'Tasa de IVA por defecto (%)', true),
    
    -- Configuración de N8N
    ('n8n_webhook_timeout', '30', 'number', 'Timeout para webhooks N8N (segundos)', false),
    ('n8n_rate_limit_per_minute', '100', 'number', 'Límite de requests por minuto', false),
    ('n8n_enable_analytics', 'true', 'boolean', 'Habilitar analytics en N8N', false),
    
    -- Configuración de WhatsApp
    ('whatsapp_session_timeout', '7200', 'number', 'Timeout de sesión WhatsApp (segundos)', false),
    ('whatsapp_max_cart_items', '20', 'number', 'Máximo items en carrito', false),
    ('whatsapp_enable_ai', 'true', 'boolean', 'Habilitar IA en respuestas', false),
    
    -- Configuración de negocio
    ('business_name', 'Supermercado Digital', 'string', 'Nombre del negocio', true),
    ('business_phone', '', 'string', 'Teléfono del negocio', true),
    ('business_email', '', 'string', 'Email del negocio', true),
    ('business_address', '', 'string', 'Dirección del negocio', true),
    ('delivery_fee', '300', 'number', 'Costo de envío por defecto', true),
    ('free_delivery_minimum', '5000', 'number', 'Monto mínimo para envío gratis', true)
ON CONFLICT (config_key) DO UPDATE SET
    config_value = EXCLUDED.config_value,
    description = EXCLUDED.description,
    is_public = EXCLUDED.is_public,
    updated_at = NOW();

-- 🎯 FUNCIÓN PARA OBTENER CONFIGURACIÓN
CREATE OR REPLACE FUNCTION get_config(key_name TEXT, default_value TEXT DEFAULT NULL)
RETURNS TEXT AS $$
DECLARE
    config_val TEXT;
BEGIN
    SELECT config_value INTO config_val 
    FROM shared.system_config 
    WHERE config_key = key_name;
    
    RETURN COALESCE(config_val, default_value);
END;
$$ LANGUAGE plpgsql;

-- 🎯 FUNCIÓN PARA ESTABLECER CONFIGURACIÓN
CREATE OR REPLACE FUNCTION set_config(key_name TEXT, value_text TEXT, user_id_param INTEGER DEFAULT NULL)
RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO shared.system_config (config_key, config_value, updated_by)
    VALUES (key_name, value_text, user_id_param)
    ON CONFLICT (config_key) 
    DO UPDATE SET 
        config_value = EXCLUDED.config_value,
        updated_by = EXCLUDED.updated_by,
        updated_at = NOW();
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- ✅ VERIFICACIÓN DE INSTALACIÓN
DO $$
BEGIN
    RAISE NOTICE '✅ Core Schema instalado correctamente';
    RAISE NOTICE '📊 Esquemas creados: stock, shared, n8n, analytics';
    RAISE NOTICE '⚙️ Funciones utilitarias disponibles';
    RAISE NOTICE '🔐 Permisos configurados para commerce_user';
END $$;