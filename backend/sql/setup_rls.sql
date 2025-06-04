-- =============================================================================
-- Script de Row Level Security (RLS) para Multi-tenancy
-- =============================================================================
-- Este script configura políticas de seguridad a nivel de fila para asegurar
-- que los datos estén completamente aislados entre organizaciones.

-- Primero, asegurar que existe la función para obtener la organización actual
CREATE OR REPLACE FUNCTION current_organization_id() RETURNS INTEGER AS $$
BEGIN
  RETURN NULLIF(current_setting('app.current_organization_id', true), '')::INTEGER;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE;

-- =============================================================================
-- CONFIGURACIÓN RLS PARA TABLA products
-- =============================================================================

-- Habilitar RLS en la tabla products
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Política para SELECT: Solo ver productos de la organización actual
CREATE POLICY products_select_policy ON products
  FOR SELECT
  USING (organization_id = current_organization_id());

-- Política para INSERT: Solo crear productos en la organización actual
CREATE POLICY products_insert_policy ON products
  FOR INSERT
  WITH CHECK (organization_id = current_organization_id());

-- Política para UPDATE: Solo actualizar productos de la organización actual
CREATE POLICY products_update_policy ON products
  FOR UPDATE
  USING (organization_id = current_organization_id())
  WITH CHECK (organization_id = current_organization_id());

-- Política para DELETE: Solo eliminar productos de la organización actual
CREATE POLICY products_delete_policy ON products
  FOR DELETE
  USING (organization_id = current_organization_id());

-- =============================================================================
-- CONFIGURACIÓN RLS PARA TABLA categories
-- =============================================================================

-- Habilitar RLS en la tabla categories
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

-- Políticas para categories (similar a products)
CREATE POLICY categories_select_policy ON categories
  FOR SELECT
  USING (organization_id = current_organization_id());

CREATE POLICY categories_insert_policy ON categories
  FOR INSERT
  WITH CHECK (organization_id = current_organization_id());

CREATE POLICY categories_update_policy ON categories
  FOR UPDATE
  USING (organization_id = current_organization_id())
  WITH CHECK (organization_id = current_organization_id());

CREATE POLICY categories_delete_policy ON categories
  FOR DELETE
  USING (organization_id = current_organization_id());

-- =============================================================================
-- CONFIGURACIÓN RLS PARA TABLA orders (si existe)
-- =============================================================================

-- Verificar si la tabla orders existe antes de crear políticas
DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'orders') THEN
    -- Habilitar RLS
    EXECUTE 'ALTER TABLE orders ENABLE ROW LEVEL SECURITY';
    
    -- Crear políticas
    EXECUTE 'CREATE POLICY orders_select_policy ON orders
      FOR SELECT
      USING (organization_id = current_organization_id())';
    
    EXECUTE 'CREATE POLICY orders_insert_policy ON orders
      FOR INSERT
      WITH CHECK (organization_id = current_organization_id())';
    
    EXECUTE 'CREATE POLICY orders_update_policy ON orders
      FOR UPDATE
      USING (organization_id = current_organization_id())
      WITH CHECK (organization_id = current_organization_id())';
    
    EXECUTE 'CREATE POLICY orders_delete_policy ON orders
      FOR DELETE
      USING (organization_id = current_organization_id())';
      
    RAISE NOTICE 'RLS configurado para tabla orders';
  ELSE
    RAISE NOTICE 'Tabla orders no existe, omitiendo configuración RLS';
  END IF;
END$$;

-- =============================================================================
-- CONFIGURACIÓN RLS PARA TABLA order_items (si existe)
-- =============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'order_items') THEN
    -- Habilitar RLS
    EXECUTE 'ALTER TABLE order_items ENABLE ROW LEVEL SECURITY';
    
    -- Para order_items, filtrar por la organización de la orden asociada
    EXECUTE 'CREATE POLICY order_items_select_policy ON order_items
      FOR SELECT
      USING (EXISTS (
        SELECT 1 FROM orders o 
        WHERE o.id = order_items.order_id 
        AND o.organization_id = current_organization_id()
      ))';
    
    EXECUTE 'CREATE POLICY order_items_insert_policy ON order_items
      FOR INSERT
      WITH CHECK (EXISTS (
        SELECT 1 FROM orders o 
        WHERE o.id = order_items.order_id 
        AND o.organization_id = current_organization_id()
      ))';
    
    EXECUTE 'CREATE POLICY order_items_update_policy ON order_items
      FOR UPDATE
      USING (EXISTS (
        SELECT 1 FROM orders o 
        WHERE o.id = order_items.order_id 
        AND o.organization_id = current_organization_id()
      ))
      WITH CHECK (EXISTS (
        SELECT 1 FROM orders o 
        WHERE o.id = order_items.order_id 
        AND o.organization_id = current_organization_id()
      ))';
    
    EXECUTE 'CREATE POLICY order_items_delete_policy ON order_items
      FOR DELETE
      USING (EXISTS (
        SELECT 1 FROM orders o 
        WHERE o.id = order_items.order_id 
        AND o.organization_id = current_organization_id()
      ))';
      
    RAISE NOTICE 'RLS configurado para tabla order_items';
  ELSE
    RAISE NOTICE 'Tabla order_items no existe, omitiendo configuración RLS';
  END IF;
END$$;

-- =============================================================================
-- CONFIGURACIÓN RLS PARA TABLA stock_movements (si existe)
-- =============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'stock_movements') THEN
    -- Habilitar RLS
    EXECUTE 'ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY';
    
    -- Para stock_movements, filtrar por la organización del producto asociado
    EXECUTE 'CREATE POLICY stock_movements_select_policy ON stock_movements
      FOR SELECT
      USING (EXISTS (
        SELECT 1 FROM products p 
        WHERE p.id = stock_movements.product_id 
        AND p.organization_id = current_organization_id()
      ))';
    
    EXECUTE 'CREATE POLICY stock_movements_insert_policy ON stock_movements
      FOR INSERT
      WITH CHECK (EXISTS (
        SELECT 1 FROM products p 
        WHERE p.id = stock_movements.product_id 
        AND p.organization_id = current_organization_id()
      ))';
    
    EXECUTE 'CREATE POLICY stock_movements_update_policy ON stock_movements
      FOR UPDATE
      USING (EXISTS (
        SELECT 1 FROM products p 
        WHERE p.id = stock_movements.product_id 
        AND p.organization_id = current_organization_id()
      ))
      WITH CHECK (EXISTS (
        SELECT 1 FROM products p 
        WHERE p.id = stock_movements.product_id 
        AND p.organization_id = current_organization_id()
      ))';
    
    EXECUTE 'CREATE POLICY stock_movements_delete_policy ON stock_movements
      FOR DELETE
      USING (EXISTS (
        SELECT 1 FROM products p 
        WHERE p.id = stock_movements.product_id 
        AND p.organization_id = current_organization_id()
      ))';
      
    RAISE NOTICE 'RLS configurado para tabla stock_movements';
  ELSE
    RAISE NOTICE 'Tabla stock_movements no existe, omitiendo configuración RLS';
  END IF;
END$$;

-- =============================================================================
-- FUNCIÓN PARA DESHABILITAR RLS (SOLO PARA SUPERADMIN)
-- =============================================================================

-- Función para deshabilitar temporalmente RLS (solo para operaciones de superadmin)
CREATE OR REPLACE FUNCTION disable_rls_for_superadmin()
RETURNS VOID AS $$
BEGIN
  -- Solo permitir si es superusuario
  IF NOT EXISTS (
    SELECT 1 FROM pg_roles 
    WHERE rolname = current_user AND rolsuper = true
  ) THEN
    RAISE EXCEPTION 'Solo los superusuarios pueden deshabilitar RLS';
  END IF;
  
  -- Deshabilitar RLS temporalmente
  SET row_security = OFF;
  
  RAISE NOTICE 'RLS deshabilitado temporalmente para operaciones de superadmin';
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- FUNCIÓN PARA VOLVER A HABILITAR RLS
-- =============================================================================

CREATE OR REPLACE FUNCTION enable_rls()
RETURNS VOID AS $$
BEGIN
  SET row_security = ON;
  RAISE NOTICE 'RLS habilitado nuevamente';
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- VERIFICACIÓN DE CONFIGURACIÓN
-- =============================================================================

-- Verificar que las políticas se crearon correctamente
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('products', 'categories', 'orders', 'order_items', 'stock_movements')
ORDER BY tablename, policyname;

-- Mostrar información de RLS habilitado
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('products', 'categories', 'orders', 'order_items', 'stock_movements')
ORDER BY tablename;

-- =============================================================================
-- NOTAS DE USO
-- =============================================================================

/*
Para usar RLS correctamente:

1. ANTES de cualquier query, establecer la organización actual:
   SET LOCAL app.current_organization_id = 123;

2. Esto se hace automáticamente en el middleware de multitenancy:
   await pool.query('SET LOCAL app.current_organization_id = $1', [req.organizationId]);

3. Para operaciones de superadmin (migraciones, etc.):
   SELECT disable_rls_for_superadmin();
   -- hacer operaciones
   SELECT enable_rls();

4. Las políticas RLS se aplican a TODOS los usuarios, incluso superusuarios,
   a menos que se deshabilite explícitamente.

5. RLS proporciona una capa adicional de seguridad junto con el middleware,
   asegurando que incluso queries directas respeten los límites organizacionales.
*/ 