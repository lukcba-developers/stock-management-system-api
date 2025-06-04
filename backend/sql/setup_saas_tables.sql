-- =============================================================================
-- Script de Configuración de Tablas SaaS
-- =============================================================================
-- Este script crea las tablas necesarias para el sistema SaaS multi-tenant

-- Crear esquema SaaS si no existe
CREATE SCHEMA IF NOT EXISTS saas;

-- =============================================================================
-- Tabla de organizaciones
-- =============================================================================
CREATE TABLE IF NOT EXISTS saas.organizations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    
    -- Información de suscripción
    subscription_plan VARCHAR(50) DEFAULT 'starter' CHECK (subscription_plan IN ('starter', 'professional', 'enterprise')),
    subscription_status VARCHAR(50) DEFAULT 'active' CHECK (subscription_status IN ('active', 'suspended', 'cancelled', 'trial')),
    subscription_started_at TIMESTAMP DEFAULT NOW(),
    subscription_ends_at TIMESTAMP,
    
    -- Límites del plan
    max_users INTEGER DEFAULT 5,
    max_products INTEGER DEFAULT 100,
    max_monthly_orders INTEGER DEFAULT 500,
    storage_gb INTEGER DEFAULT 1,
    
    -- Configuración adicional
    features JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    
    -- Metadatos
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- =============================================================================
-- Tabla de usuarios autorizados
-- =============================================================================
CREATE TABLE IF NOT EXISTS saas.authorized_users (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES saas.organizations(id) ON DELETE CASCADE,
    
    -- Información del usuario
    email VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    google_id VARCHAR(255),
    picture TEXT,
    
    -- Roles y permisos
    role VARCHAR(50) DEFAULT 'viewer' CHECK (role IN ('viewer', 'editor', 'admin', 'owner')),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'suspended', 'removed')),
    
    -- Sistema de invitaciones
    invitation_token VARCHAR(255),
    invitation_sent_at TIMESTAMP,
    invitation_expires_at TIMESTAMP,
    invitation_accepted_at TIMESTAMP,
    
    -- Actividad del usuario
    last_login TIMESTAMP,
    login_count INTEGER DEFAULT 0,
    
    -- Metadatos
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(organization_id, email)
);

-- =============================================================================
-- Tabla de planes de suscripción (opcional - para configuración dinámica)
-- =============================================================================
CREATE TABLE IF NOT EXISTS saas.subscription_plans (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    
    -- Precios
    monthly_price DECIMAL(10,2) NOT NULL,
    yearly_price DECIMAL(10,2) NOT NULL,
    
    -- Límites
    max_users INTEGER NOT NULL,
    max_products INTEGER NOT NULL,
    max_monthly_orders INTEGER NOT NULL,
    storage_gb INTEGER NOT NULL,
    
    -- Características
    features JSONB DEFAULT '{}',
    
    -- Estado
    is_active BOOLEAN DEFAULT true,
    sort_order INTEGER DEFAULT 0,
    
    -- Metadatos
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- =============================================================================
-- Tabla de facturación e historial de pagos
-- =============================================================================
CREATE TABLE IF NOT EXISTS saas.billing_history (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES saas.organizations(id) ON DELETE CASCADE,
    
    -- Información de la factura
    billing_period_start DATE NOT NULL,
    billing_period_end DATE NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    
    -- Detalles del plan
    plan_name VARCHAR(50) NOT NULL,
    plan_price DECIMAL(10,2) NOT NULL,
    extra_users INTEGER DEFAULT 0,
    extra_users_cost DECIMAL(10,2) DEFAULT 0,
    extra_storage_gb INTEGER DEFAULT 0,
    extra_storage_cost DECIMAL(10,2) DEFAULT 0,
    
    -- Estado del pago
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'failed', 'refunded')),
    payment_method VARCHAR(50),
    payment_date TIMESTAMP,
    payment_reference VARCHAR(255),
    
    -- Metadatos
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- =============================================================================
-- Tabla de métricas de uso
-- =============================================================================
CREATE TABLE IF NOT EXISTS saas.usage_metrics (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES saas.organizations(id) ON DELETE CASCADE,
    
    -- Fecha de la métrica
    metric_date DATE NOT NULL,
    
    -- Métricas de uso
    active_users INTEGER DEFAULT 0,
    total_products INTEGER DEFAULT 0,
    monthly_orders INTEGER DEFAULT 0,
    storage_used_gb DECIMAL(10,3) DEFAULT 0,
    
    -- Métricas adicionales
    api_calls INTEGER DEFAULT 0,
    emails_sent INTEGER DEFAULT 0,
    
    -- Metadatos
    created_at TIMESTAMP DEFAULT NOW(),
    
    -- Constraint para evitar duplicados por día
    UNIQUE(organization_id, metric_date)
);

-- =============================================================================
-- Tabla de actividad de la organización
-- =============================================================================
CREATE TABLE IF NOT EXISTS saas.organization_activity (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES saas.organizations(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES saas.authorized_users(id) ON DELETE SET NULL,
    
    -- Información de la actividad
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id INTEGER,
    details JSONB,
    
    -- Metadatos de la sesión
    ip_address INET,
    user_agent TEXT,
    
    -- Timestamp
    created_at TIMESTAMP DEFAULT NOW()
);

-- =============================================================================
-- Índices para optimización
-- =============================================================================

-- Índices para authorized_users
CREATE INDEX IF NOT EXISTS idx_authorized_users_email ON saas.authorized_users(email);
CREATE INDEX IF NOT EXISTS idx_authorized_users_org_id ON saas.authorized_users(organization_id);
CREATE INDEX IF NOT EXISTS idx_authorized_users_invitation_token ON saas.authorized_users(invitation_token);
CREATE INDEX IF NOT EXISTS idx_authorized_users_status ON saas.authorized_users(status);

-- Índices para organizations
CREATE INDEX IF NOT EXISTS idx_organizations_slug ON saas.organizations(slug);
CREATE INDEX IF NOT EXISTS idx_organizations_subscription_status ON saas.organizations(subscription_status);

-- Índices para billing_history
CREATE INDEX IF NOT EXISTS idx_billing_history_org_id ON saas.billing_history(organization_id);
CREATE INDEX IF NOT EXISTS idx_billing_history_period ON saas.billing_history(billing_period_start, billing_period_end);
CREATE INDEX IF NOT EXISTS idx_billing_history_status ON saas.billing_history(status);

-- Índices para usage_metrics
CREATE INDEX IF NOT EXISTS idx_usage_metrics_org_date ON saas.usage_metrics(organization_id, metric_date);
CREATE INDEX IF NOT EXISTS idx_usage_metrics_date ON saas.usage_metrics(metric_date);

-- Índices para organization_activity
CREATE INDEX IF NOT EXISTS idx_organization_activity_org_id ON saas.organization_activity(organization_id);
CREATE INDEX IF NOT EXISTS idx_organization_activity_user_id ON saas.organization_activity(user_id);
CREATE INDEX IF NOT EXISTS idx_organization_activity_created_at ON saas.organization_activity(created_at);

-- =============================================================================
-- Insertar planes de suscripción por defecto
-- =============================================================================
INSERT INTO saas.subscription_plans (name, display_name, monthly_price, yearly_price, max_users, max_products, max_monthly_orders, storage_gb, features) 
VALUES 
  (
    'starter', 
    'Plan Starter', 
    29.00, 
    290.00, 
    5, 
    100, 
    500, 
    1,
    '{"api_access": false, "priority_support": false, "custom_branding": false}'
  ),
  (
    'professional', 
    'Plan Professional', 
    99.00, 
    990.00, 
    20, 
    1000, 
    2000, 
    10,
    '{"api_access": true, "priority_support": false, "custom_branding": true, "advanced_analytics": true}'
  ),
  (
    'enterprise', 
    'Plan Enterprise', 
    299.00, 
    2990.00, 
    100, 
    10000, 
    10000, 
    100,
    '{"api_access": true, "priority_support": true, "custom_branding": true, "advanced_analytics": true, "dedicated_support": true}'
  )
ON CONFLICT (name) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  monthly_price = EXCLUDED.monthly_price,
  yearly_price = EXCLUDED.yearly_price,
  max_users = EXCLUDED.max_users,
  max_products = EXCLUDED.max_products,
  max_monthly_orders = EXCLUDED.max_monthly_orders,
  storage_gb = EXCLUDED.storage_gb,
  features = EXCLUDED.features,
  updated_at = NOW();

-- =============================================================================
-- Crear organización de ejemplo (solo para desarrollo)
-- =============================================================================
INSERT INTO saas.organizations (name, slug, subscription_plan, max_users, max_products, max_monthly_orders, storage_gb)
VALUES ('Empresa Demo', 'empresa-demo', 'professional', 20, 1000, 2000, 10)
ON CONFLICT (slug) DO NOTHING;

-- Crear usuario owner de ejemplo
INSERT INTO saas.authorized_users (organization_id, email, name, role, status)
SELECT 
  o.id,
  'admin@empresa-demo.com',
  'Administrador Demo',
  'owner',
  'active'
FROM saas.organizations o 
WHERE o.slug = 'empresa-demo'
ON CONFLICT (organization_id, email) DO NOTHING;

-- =============================================================================
-- Funciones auxiliares
-- =============================================================================

-- Función para calcular el uso actual de una organización
CREATE OR REPLACE FUNCTION saas.get_organization_usage(org_id INTEGER)
RETURNS TABLE (
  current_users INTEGER,
  current_products INTEGER,
  monthly_orders INTEGER,
  storage_used_gb DECIMAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    (SELECT COUNT(*)::INTEGER FROM saas.authorized_users WHERE organization_id = org_id AND status = 'active'),
    COALESCE((SELECT COUNT(*)::INTEGER FROM products WHERE organization_id = org_id AND is_available = true), 0),
    COALESCE((SELECT COUNT(*)::INTEGER FROM orders WHERE organization_id = org_id AND DATE(created_at) >= DATE_TRUNC('month', CURRENT_DATE)), 0),
    0.5::DECIMAL; -- Placeholder para almacenamiento
END;
$$ LANGUAGE plpgsql;

-- Función para registrar actividad de la organización
CREATE OR REPLACE FUNCTION saas.log_organization_activity(
  org_id INTEGER,
  user_id INTEGER,
  action_name VARCHAR,
  resource_type VARCHAR DEFAULT NULL,
  resource_id INTEGER DEFAULT NULL,
  details JSONB DEFAULT NULL,
  ip_addr INET DEFAULT NULL,
  user_agent_str TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
  INSERT INTO saas.organization_activity 
  (organization_id, user_id, action, resource_type, resource_id, details, ip_address, user_agent)
  VALUES 
  (org_id, user_id, action_name, resource_type, resource_id, details, ip_addr, user_agent_str);
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- Triggers para actualizar updated_at automáticamente
-- =============================================================================

-- Función trigger para updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers para las tablas
CREATE TRIGGER update_organizations_updated_at 
  BEFORE UPDATE ON saas.organizations 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_authorized_users_updated_at 
  BEFORE UPDATE ON saas.authorized_users 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subscription_plans_updated_at 
  BEFORE UPDATE ON saas.subscription_plans 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_billing_history_updated_at 
  BEFORE UPDATE ON saas.billing_history 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- Verificación de la configuración
-- =============================================================================

-- Mostrar resumen de tablas creadas
SELECT 
  schemaname,
  tablename,
  hasindexes,
  hasrules,
  hastriggers
FROM pg_tables 
WHERE schemaname = 'saas'
ORDER BY tablename;

-- Mostrar planes de suscripción configurados
SELECT 
  name,
  display_name,
  monthly_price,
  yearly_price,
  max_users,
  max_products
FROM saas.subscription_plans
ORDER BY monthly_price;

RAISE NOTICE 'Configuración de tablas SaaS completada exitosamente'; 