-- CREAR ESTRUCTURA COMPLETA DE BD
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Función para updated_at automático
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
RETURN NEW;
END;
$$ language 'plpgsql';

-- Crear vista materializada para búsquedas frecuentes (Mejora Propuesta)
CREATE MATERIALIZED VIEW product_search_view AS
SELECT
    p.*,
    to_tsvector('spanish', p.name || ' ' || COALESCE(p.description, '') || ' ' || COALESCE(p.meta_keywords, '')) as search_vector,
    ts_rank(to_tsvector('spanish', p.name), plainto_tsquery('spanish', 'query')) as rank -- 'query' is a placeholder, actual query term will be supplied at runtime
FROM products p
WHERE p.is_available = true;

-- Índice GIN para búsquedas full-text en la vista materializada (Mejora Propuesta)
CREATE INDEX idx_product_search_vector ON product_search_view USING GIN(search_vector);

-- Función para actualizar la vista materializada (Mejora Propuesta)
CREATE OR REPLACE FUNCTION refresh_product_search_view()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY product_search_view;
END;
$$ LANGUAGE plpgsql;
-- Consider scheduling this function using pg_cron or an N8N workflow.

-- Función PL/pgSQL optimizada para obtener sesión (Mejora Propuesta / Fragmento 11)
CREATE OR REPLACE FUNCTION get_session_with_context(p_customer_phone VARCHAR)
RETURNS TABLE (
    session_data JSONB,
    customer_data JSONB,
    recent_orders JSONB,
    conversation_history JSONB -- Considerar si esto viene de message_logs o context_data
) AS $$
DECLARE
v_session_data JSONB;
    v_customer_data JSONB;
    v_recent_orders JSONB;
    v_conversation_history JSONB;
BEGIN
    -- Obtener sesión activa
SELECT to_jsonb(s.*) INTO v_session_data
FROM customer_sessions s
WHERE s.customer_phone = p_customer_phone
  AND s.expires_at > NOW()
ORDER BY s.updated_at DESC
    LIMIT 1;

-- Obtener datos del cliente
SELECT jsonb_build_object(
               'name', c.name,
               'email', c.email,
               'default_address', c.default_address,
               'total_orders', c.total_orders,
               'loyalty_points', c.loyalty_points,
               'customer_tier', CASE
                                    WHEN c.total_orders = 0 THEN 'new'
                                    WHEN c.total_orders <= 3 THEN 'occasional'
                                    WHEN c.total_orders <= 10 THEN 'regular'
                                    ELSE 'vip'
                   END,
               'preferences_history', c.preferences_history,
               'purchase_patterns', c.purchase_patterns,
               'customer_profile', c.customer_profile
       ) INTO v_customer_data
FROM customers c
WHERE c.phone = p_customer_phone;

-- Obtener pedidos recientes
SELECT jsonb_agg(o_agg.*) INTO v_recent_orders
FROM (
         SELECT o.id as order_id, o.order_number, o.total_amount, o.order_status, o.created_at,
                (SELECT jsonb_agg(oi_agg.*) FROM (
                                                     SELECT oi.product_name, oi.quantity, oi.unit_price
                                                     FROM order_items oi WHERE oi.order_id = o.id
                                                 ) oi_agg) as items
         FROM orders o
         WHERE o.customer_phone = p_customer_phone
           AND o.created_at > NOW() - INTERVAL '30 days'
         ORDER BY o.created_at DESC
             LIMIT 3
     ) o_agg;

-- Obtener historial de conversación (de message_logs)
SELECT jsonb_agg(ml_agg.* ORDER BY ml_agg.message_timestamp DESC) INTO v_conversation_history
FROM (
         SELECT ml.message_timestamp, ml.message_type, ml.message_content
         FROM message_logs ml
         WHERE ml.customer_phone = p_customer_phone
           AND ml.message_timestamp > NOW() - INTERVAL '2 hours' -- O el TTL de la sesión
           AND ml.rate_limit_exceeded = false
             LIMIT 20 -- O un límite configurable
     ) ml_agg;

RETURN QUERY SELECT
        COALESCE(v_session_data, '{}'::jsonb),
        COALESCE(v_customer_data, '{}'::jsonb),
        COALESCE(v_recent_orders, '[]'::jsonb),
        COALESCE(v_conversation_history, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql;

-- Crear función optimizada para sesiones
CREATE OR REPLACE FUNCTION get_session_optimized(customer_phone_param TEXT)
RETURNS TABLE(
    session_id INTEGER,
    customer_phone TEXT,
    session_state TEXT,
    cart_data JSONB,
    context_data JSONB,
    customer_name TEXT,
    total_orders BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        cs.id as session_id,
        cs.customer_phone,
        cs.session_state,
        cs.cart_data,
        cs.context_data,
        cust.name as customer_name,
        COALESCE(order_stats.total_orders_count, 0::BIGINT) as total_orders
    FROM customer_sessions cs
    LEFT JOIN customers cust ON cs.customer_phone = cust.phone
    LEFT JOIN (
        SELECT o.customer_phone, COUNT(*) as total_orders_count
        FROM orders o
        WHERE o.customer_phone = customer_phone_param
        GROUP BY o.customer_phone
    ) order_stats ON cs.customer_phone = order_stats.customer_phone
    WHERE cs.customer_phone = customer_phone_param
    AND cs.expires_at > NOW()
    ORDER BY cs.updated_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Crear materialized view para productos
CREATE MATERIALIZED VIEW IF NOT EXISTS products_search_mv AS
SELECT p.*, c.name as category_name
FROM products p
JOIN categories c ON p.category_id = c.id
WHERE p.is_available = true;

CREATE UNIQUE INDEX IF NOT EXISTS idx_products_search_mv_id ON products_search_mv (id);
-- Considerar añadir una función para refrescar esta vista materializada también,
-- similar a refresh_product_search_view, o extender la existente.
-- Ejemplo:
-- CREATE OR REPLACE FUNCTION refresh_products_search_mv()
-- RETURNS void AS $$
-- BEGIN
--     REFRESH MATERIALIZED VIEW CONCURRENTLY products_search_mv;
-- END;
-- $$ LANGUAGE plpgsql;

-- Datos de ejemplo
INSERT INTO categories (name, description, icon_emoji, sort_order) VALUES
                                                                       ('Frutas y Verduras', 'Productos frescos', '🥬', 1),
                                                                       ('Lácteos', 'Leche, quesos, yogures', '🥛', 2),
                                                                       ('Panadería', 'Pan fresco', '🍞', 3),
                                                                       ('Carnes', 'Carnes frescas', '🥩', 4),
                                                                       ('Bebidas', 'Refrescos y aguas', '🥤', 5)
ON CONFLICT (name) DO NOTHING;

INSERT INTO products (name, description, price, stock_quantity, category_id, brand, weight_unit, weight_value, meta_keywords) VALUES
                                                                                                                                  ('Manzana Roja', 'Manzanas frescas y jugosas, ideales para comer solas o en ensaladas.', 150.00, 100, 1, 'Del Campo', 'kg', 1.0, 'fruta, roja, fresca, gala, fuji'),
                                                                                                                                  ('Leche Entera Sachet', 'Leche fresca pasteurizada, fuente de calcio y vitaminas.', 280.00, 50, 2, 'La Serenísima', 'l', 1.0, 'lacteo, entera, fresca, sachet'),
                                                                                                                                  ('Pan Francés Artesanal', 'Pan recién horneado con corteza crujiente y miga suave.', 120.00, 30, 3, 'Panadería Local', 'unidad', 1.0, 'panaderia, baguette, artesanal, fresco'),
                                                                                                                                  ('Pollo Entero Fresco', 'Pollo entero, ideal para asar o trozar.', 890.00, 25, 4, 'Granja Verde', 'kg', 1.5, 'ave, carne blanca, fresco, entero'),
                                                                                                                                  ('Coca Cola Original 500ml', 'Gaseosa sabor cola, refrescante y clásica.', 180.00, 200, 5, 'Coca Cola', 'ml', 500, 'bebida, gaseosa, cola, refresco')
ON CONFLICT (name) DO NOTHING;

-- Insertar un cliente de ejemplo
INSERT INTO customers (phone, name, email, default_address, total_orders, total_spent, loyalty_points, customer_profile) VALUES
    ('5491122334455', 'Juan Perez', 'juan.perez@example.com', 'Av. Siempre Viva 742, Springfield', 5, 7500.00, 150,
     '{"preferred_categories": ["Carnes", "Bebidas"], "last_interaction_mood": "positive"}'::jsonb
    )
ON CONFLICT (phone) DO NOTHING;
