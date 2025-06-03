-- Crear extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Crear esquema para n8n
CREATE SCHEMA IF NOT EXISTS n8n;

-- Crear esquema para stock management
CREATE SCHEMA IF NOT EXISTS stock_management;

-- Configurar búsqueda de esquemas
ALTER DATABASE stock_management SET search_path TO stock_management, n8n, public;

-- Crear usuario n8n si no existe
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'n8n') THEN
    CREATE USER n8n WITH PASSWORD 'n8n_password';
  END IF;
END
$$;

-- Otorgar privilegios
GRANT ALL PRIVILEGES ON SCHEMA n8n TO n8n;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA n8n TO n8n;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA n8n TO n8n;

-- Configurar parámetros de rendimiento
ALTER SYSTEM SET max_connections = '200';
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = '0.9';
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = '100';
ALTER SYSTEM SET random_page_cost = '1.1';
ALTER SYSTEM SET effective_io_concurrency = '200';
ALTER SYSTEM SET work_mem = '4MB';
ALTER SYSTEM SET min_wal_size = '1GB';
ALTER SYSTEM SET max_wal_size = '4GB'; 