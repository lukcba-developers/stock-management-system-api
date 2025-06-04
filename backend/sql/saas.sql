-- Nuevo schema para SaaS
CREATE SCHEMA IF NOT EXISTS saas;

-- Tabla de organizaciones/empresas
CREATE TABLE saas.organizations
(
    id                      SERIAL PRIMARY KEY,
    name                    VARCHAR(255)        NOT NULL,
    slug                    VARCHAR(100) UNIQUE NOT NULL, -- URL: app.com/org/slug
    logo_url                VARCHAR(500),

    -- Información de la empresa
    business_name           VARCHAR(255),
    tax_id                  VARCHAR(50),
    address                 TEXT,
    phone                   VARCHAR(50),
    email                   VARCHAR(255),

    -- Plan y suscripción
    subscription_plan       VARCHAR(50) DEFAULT 'free',   -- 'free', 'basic', 'pro', 'enterprise'
    subscription_status     VARCHAR(30) DEFAULT 'active', -- 'active', 'suspended', 'cancelled'
    subscription_expires_at TIMESTAMP,

    -- Límites del plan
    max_users               INTEGER     DEFAULT 5,
    max_products            INTEGER     DEFAULT 100,
    max_monthly_orders      INTEGER     DEFAULT 1000,
    features                JSONB       DEFAULT '{}',     -- {"reports": true, "api_access": false, etc}

    -- Configuración
    settings                JSONB       DEFAULT '{}',
    allowed_domains         JSONB       DEFAULT '[]',     -- ["@empresa.com", "@otrodominio.com"]

    -- Auditoría
    created_by              INTEGER,
    created_at              TIMESTAMP   DEFAULT NOW(),
    updated_at              TIMESTAMP   DEFAULT NOW()
);

-- Tabla de usuarios autorizados
CREATE TABLE saas.authorized_users
(
    id                     SERIAL PRIMARY KEY,
    organization_id        INTEGER      NOT NULL REFERENCES saas.organizations (id) ON DELETE CASCADE,
    email                  VARCHAR(255) NOT NULL,

    -- Información del usuario
    name                   VARCHAR(255),
    google_id              VARCHAR(255),
    picture                VARCHAR(500),

    -- Permisos
    role                   VARCHAR(50) DEFAULT 'viewer',  -- 'owner', 'admin', 'editor', 'viewer'
    permissions            JSONB       DEFAULT '{}',      -- Permisos específicos

    -- Estado
    status                 VARCHAR(30) DEFAULT 'pending', -- 'pending', 'active', 'suspended', 'removed'
    invitation_token       VARCHAR(255) UNIQUE,
    invitation_sent_at     TIMESTAMP,
    invitation_accepted_at TIMESTAMP,

    -- Acceso
    last_login             TIMESTAMP,
    login_count            INTEGER     DEFAULT 0,

    created_at             TIMESTAMP   DEFAULT NOW(),
    updated_at             TIMESTAMP   DEFAULT NOW(),

    UNIQUE (organization_id, email)
);

-- Índices para búsquedas rápidas
CREATE INDEX idx_authorized_users_email ON saas.authorized_users (email);
CREATE INDEX idx_authorized_users_org_status ON saas.authorized_users (organization_id, status);
CREATE INDEX idx_organizations_slug ON saas.organizations (slug);

-- Tabla de planes de suscripción
CREATE TABLE saas.subscription_plans
(
    id                 SERIAL PRIMARY KEY,
    name               VARCHAR(50) UNIQUE NOT NULL,
    display_name       VARCHAR(100)       NOT NULL,
    description        TEXT,

    -- Precios
    monthly_price      DECIMAL(10, 2),
    yearly_price       DECIMAL(10, 2),
    currency           VARCHAR(3)                  DEFAULT 'USD',

    -- Límites
    max_users          INTEGER,
    max_products       INTEGER,
    max_monthly_orders INTEGER,
    max_categories     INTEGER,
    storage_gb         INTEGER,

    -- Features
    features           JSONB              NOT NULL DEFAULT '{}',

    -- Configuración
    is_active          BOOLEAN                     DEFAULT true,
    is_featured        BOOLEAN                     DEFAULT false,
    sort_order         INTEGER                     DEFAULT 0,

    created_at         TIMESTAMP                   DEFAULT NOW()
);

-- Insertar planes predefinidos
INSERT INTO saas.subscription_plans (name, display_name, monthly_price, yearly_price, max_users, max_products,
                                     max_monthly_orders, features)
VALUES ('free', 'Plan Gratuito', 0, 0, 2, 50, 100, '{
  "basic_reports": true,
  "email_support": true
}'),
       ('starter', 'Starter', 29, 299, 5, 500, 1000, '{
         "basic_reports": true,
         "advanced_reports": true,
         "email_support": true,
         "api_access": false
       }'),
       ('professional', 'Profesional', 99, 999, 20, 5000, 10000, '{
         "basic_reports": true,
         "advanced_reports": true,
         "email_support": true,
         "phone_support": true,
         "api_access": true,
         "custom_branding": true
       }'),
       ('enterprise', 'Enterprise', 299, 2999, 999, 99999, 99999, '{
         "all_features": true,
         "priority_support": true,
         "custom_development": true
       }');


-- Agregar organization_id a las tablas principales
ALTER TABLE stock.products ADD COLUMN organization_id INTEGER REFERENCES saas.organizations(id);
ALTER TABLE stock.categories ADD COLUMN organization_id INTEGER REFERENCES saas.organizations(id);
ALTER TABLE shared.orders ADD COLUMN organization_id INTEGER REFERENCES saas.organizations(id);
ALTER TABLE shared.customers ADD COLUMN organization_id INTEGER REFERENCES saas.organizations(id);

-- Crear índices para mejorar performance
CREATE INDEX idx_products_org ON stock.products(organization_id);
CREATE INDEX idx_categories_org ON stock.categories(organization_id);
CREATE INDEX idx_orders_org ON shared.orders(organization_id);
CREATE INDEX idx_customers_org ON shared.customers(organization_id);

-- Row Level Security (opcional pero recomendado) - Continuación
CREATE POLICY products_isolation ON stock.products
   FOR ALL
   TO PUBLIC
   USING (organization_id = current_setting('app.current_organization_id')::INTEGER);

ALTER TABLE stock.categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY categories_isolation ON stock.categories
   FOR ALL
   TO PUBLIC
   USING (organization_id = current_setting('app.current_organization_id')::INTEGER);

ALTER TABLE shared.orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY orders_isolation ON shared.orders
   FOR ALL
   TO PUBLIC
   USING (organization_id = current_setting('app.current_organization_id')::INTEGER);

-- Script de migración para convertir sistema existente a multi-tenant

-- 1. Crear organización por defecto
INSERT INTO saas.organizations (
    name,
    slug,
    subscription_plan,
    max_users,
    max_products,
    max_monthly_orders
) VALUES (
             'Mi Supermercado',
             'mi-supermercado',
             'professional',
             20,
             5000,
             10000
         ) RETURNING id;

-- Guardar el ID retornado (ej: 1)

-- 2. Asignar todos los productos existentes a la organización
UPDATE stock.products SET organization_id = 1;
UPDATE stock.categories SET organization_id = 1;
UPDATE shared.orders SET organization_id = 1;
UPDATE shared.customers SET organization_id = 1;

-- 3. Migrar usuarios existentes
INSERT INTO saas.authorized_users (organization_id, email, name, google_id, role, status)
SELECT
    1,
    email,
    name,
    google_id,
    role,
    'active'
FROM stock.admin_users;

