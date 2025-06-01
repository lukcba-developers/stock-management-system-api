-- backend/sql/init-db.sql
-- Script para crear usuario y base de datos solo si no existen

DO
$do$
BEGIN
   IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles
      WHERE  rolname = 'stock_user') THEN
      CREATE ROLE stock_user LOGIN PASSWORD 'yoursecurepassword';
   END IF;
END
$do$;

DO
$do$
BEGIN
   IF NOT EXISTS (
      SELECT FROM pg_database
      WHERE datname = 'stock_management_db') THEN
      CREATE DATABASE stock_management_db
             WITH OWNER = stock_user
             ENCODING = 'UTF8'
             LC_COLLATE = 'en_US.UTF-8'
             LC_CTYPE = 'en_US.UTF-8'
             TABLESPACE = pg_default
             CONNECTION LIMIT = -1;
   END IF;
END
$do$;

-- GRANT ALL PRIVILEGES ON DATABASE stock_management_db TO stock_user;
-- ALTER DATABASE stock_management_db OWNER TO stock_user; 