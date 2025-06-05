-- ============================================================================
-- 📊 VISTAS Y FUNCIONES - Elementos de Análisis y Optimización
-- ============================================================================
-- Archivo: init-scripts/05_views_functions.sql
-- Propósito: Vistas materializadas, funciones y análisis faltantes de la migración
-- Dependencias: 00_core_schema.sql, 01_stock_management.sql, 02_shared_tables.sql, 04_missing_critical.sql
-- Orden de ejecución: QUINTO (05_)
-- ============================================================================

-- 🔍 VISTA MATERIALIZADA PARA BÚSQUEDAS (del init-db.sql)
CREATE MATERIALIZED VIEW IF NOT EXISTS shared.product_search_view AS
SELECT
    p.*,
    to_tsvector('spanish_unaccent',
                p.name || ' ' ||
                COALESCE(p.description, '') || ' ' ||
                COALESCE(p.meta_keywords, '') || ' ' ||
                COALESCE(p.brand, '') || ' ' ||
                COALESCE(c.name, '')
    ) as search_vector,
    c.name as category_name,
    c.icon_emoji as category_icon,

    -- Estado del stock mejorado
    CASE
        WHEN p.stock_quantity = 0 THEN 'out_of_stock'
        WHEN p.stock_quantity <= p.min_stock_alert THEN 'low_stock'
        WHEN p.max_stock_limit IS NOT NULL AND p.stock_quantity >= p.max_stock_limit THEN 'overstock'
        ELSE 'normal'
        END as stock_status,

    -- Ranking para búsquedas
    0::real as search_rank -- Se actualizará dinámicamente en consultas

FROM stock.products p
         LEFT JOIN stock.categories c ON p.category_id = c.id
WHERE p.is_available = true;

-- Índice único para la vista materializada
CREATE UNIQUE INDEX IF NOT EXISTS idx_product_search_view_id ON shared.product_search_view (id);
-- Índice GIN para búsquedas full-text
CREATE INDEX IF NOT EXISTS idx_product_search_view_search_vector ON shared.product_search_view USING GIN(search_vector);
-- Índices adicionales para filtros
CREATE INDEX IF NOT EXISTS idx_product_search_view_category ON shared.product_search_view(category_id, stock_status);
CREATE INDEX IF NOT EXISTS idx_product_search_view_stock_status ON shared.product_search_view(stock_status, price);

-- 📈 VISTA PARA ANÁLISIS DE ROTACIÓN DE INVENTARIO (del additional_sql_tables.sql)
CREATE OR REPLACE VIEW analytics.inventory_turnover_analysis AS
WITH sales_data AS (
    SELECT
        oi.product_id,
        SUM(oi.quantity) as units_sold_period,
        SUM(oi.total_price) as revenue_period,
        COUNT(DISTINCT o.id) as orders_with_product_period
    FROM shared.order_items oi
             JOIN shared.orders o ON oi.order_id = o.id
    WHERE o.created_at >= CURRENT_DATE - INTERVAL '90 days'
      AND o.order_status IN ('delivered', 'completed')
    GROUP BY oi.product_id
),
     avg_inventory AS (
         SELECT
             p.id as product_id,
             p.stock_quantity as current_stock_level,
             COALESCE(
                     (SELECT AVG(sm.quantity_after)
                      FROM stock.stock_movements sm
                      WHERE sm.product_id = p.id
                        AND sm.created_at >= CURRENT_DATE - INTERVAL '90 days'),
                     p.stock_quantity
             ) as avg_stock_level_period
         FROM stock.products p
     ),
     cost_of_goods_sold AS (
         SELECT
             ps.product_id,
             AVG(ps.cost_price) as avg_cost_price
         FROM stock.product_suppliers ps
         WHERE ps.cost_price IS NOT NULL
         GROUP BY ps.product_id
     )
SELECT
    p.id as product_id,
    p.name as product_name,
    p.barcode,
    p.sku,
    cat.name as category_name,
    COALESCE(ai.current_stock_level, p.stock_quantity) as current_stock,
    p.min_stock_alert,
    COALESCE(sd.units_sold_period, 0) as units_sold_last_90d,
    COALESCE(sd.revenue_period, 0) as revenue_last_90d,
    COALESCE(sd.orders_with_product_period, 0) as orders_with_product_90d,
    COALESCE(cogs.avg_cost_price, p.price * 0.7) as avg_unit_cost,

    -- Cálculos de rotación
    (COALESCE(sd.units_sold_period, 0) * COALESCE(cogs.avg_cost_price, p.price * 0.7)) as cogs_last_90d,
    (COALESCE(sd.revenue_period, 0) - (COALESCE(sd.units_sold_period, 0) * COALESCE(cogs.avg_cost_price, p.price * 0.7))) as gross_profit_last_90d,

    -- Ratio de rotación de inventario
    CASE
        WHEN COALESCE(cogs.avg_cost_price, p.price * 0.7) > 0 AND COALESCE(ai.avg_stock_level_period, p.stock_quantity, 0) > 0
            THEN (COALESCE(sd.units_sold_period, 0) * COALESCE(cogs.avg_cost_price, p.price * 0.7)) /
                 (COALESCE(ai.avg_stock_level_period, p.stock_quantity) * COALESCE(cogs.avg_cost_price, p.price * 0.7))
        ELSE 0
        END as inventory_turnover_ratio_90d,

    -- Días de inventario
    CASE
        WHEN COALESCE(sd.units_sold_period, 0) > 0 AND
             (COALESCE(sd.units_sold_period, 0) * COALESCE(cogs.avg_cost_price, p.price * 0.7)) > 0 AND
             (COALESCE(ai.avg_stock_level_period, p.stock_quantity, 0) * COALESCE(cogs.avg_cost_price, p.price * 0.7)) > 0
            THEN 90.0 / ((COALESCE(sd.units_sold_period, 0) * COALESCE(cogs.avg_cost_price, p.price * 0.7)) /
                         (COALESCE(ai.avg_stock_level_period, p.stock_quantity, 0) * COALESCE(cogs.avg_cost_price, p.price * 0.7)))
        WHEN COALESCE(ai.avg_stock_level_period, p.stock_quantity, 0) > 0 THEN 9999 -- Stock pero sin ventas
        ELSE 0
        END as days_sales_of_inventory_90d,

    -- Valores del stock
    (COALESCE(ai.current_stock_level, p.stock_quantity) * COALESCE(cogs.avg_cost_price, p.price * 0.7)) as current_stock_value_at_cost,
    (COALESCE(ai.current_stock_level, p.stock_quantity) * p.price) as current_stock_value_at_price,

    -- Clasificación de performance
    CASE
        WHEN COALESCE(sd.units_sold_period, 0) = 0 THEN 'no_sales'
        WHEN COALESCE(sd.units_sold_period, 0) >= 50 THEN 'high_demand'
        WHEN COALESCE(sd.units_sold_period, 0) >= 20 THEN 'medium_demand'
        WHEN COALESCE(sd.units_sold_period, 0) >= 5 THEN 'low_demand'
        ELSE 'very_low_demand'
        END as demand_classification,

    p.updated_at as product_last_update

FROM stock.products p
         LEFT JOIN stock.categories cat ON p.category_id = cat.id
         LEFT JOIN sales_data sd ON p.id = sd.product_id
         LEFT JOIN avg_inventory ai ON p.id = ai.product_id
         LEFT JOIN cost_of_goods_sold cogs ON p.id = cogs.product_id
WHERE p.is_available = true;

-- 🔍 FUNCIÓN MEJORADA PARA BÚSQUEDAS (del init-db.sql)
CREATE OR REPLACE FUNCTION shared.search_products_optimized(
    search_term TEXT,
    category_filter INTEGER DEFAULT NULL,
    price_min DECIMAL DEFAULT NULL,
    price_max DECIMAL DEFAULT NULL,
    in_stock_only BOOLEAN DEFAULT true,
    limit_results INTEGER DEFAULT 50
)
RETURNS TABLE(
    product_id INTEGER,
    product_name VARCHAR(255),
    description TEXT,
    price DECIMAL(12,2),
    stock_quantity INTEGER,
    category_name VARCHAR(100),
    category_icon VARCHAR(10),
    image_url VARCHAR(500),
    brand VARCHAR(100),
    search_rank REAL,
    stock_status TEXT
) AS $$
BEGIN
RETURN QUERY
SELECT
    psv.id,
    psv.name,
    psv.description,
    psv.price,
    psv.stock_quantity,
    psv.category_name,
    psv.category_icon,
    psv.image_url,
    psv.brand,
    CASE
        WHEN search_term IS NOT NULL AND search_term != ''
            THEN ts_rank(psv.search_vector, plainto_tsquery('spanish_unaccent', search_term))
        ELSE 0.5
        END as search_rank,
    psv.stock_status
FROM shared.product_search_view psv
WHERE
    (search_term IS NULL OR search_term = '' OR psv.search_vector @@ plainto_tsquery('spanish_unaccent', search_term))
  AND (category_filter IS NULL OR psv.category_id = category_filter)
  AND (price_min IS NULL OR psv.price >= price_min)
  AND (price_max IS NULL OR psv.price <= price_max)
  AND (NOT in_stock_only OR psv.stock_quantity > 0)
ORDER BY
    CASE
        WHEN search_term IS NOT NULL AND search_term != ''
            THEN ts_rank(psv.search_vector, plainto_tsquery('spanish_unaccent', search_term))
        ELSE psv.popularity_score * 0.01
        END DESC,
    psv.name ASC
    LIMIT limit_results;
END;
$$ LANGUAGE plpgsql;

-- 📊 FUNCIÓN PARA REFRESCAR VISTAS MATERIALIZADAS (del init-db.sql)
CREATE OR REPLACE FUNCTION shared.refresh_materialized_views()
RETURNS VOID AS $$
BEGIN
    -- Refrescar vista de búsqueda de productos
    REFRESH MATERIALIZED VIEW CONCURRENTLY shared.product_search_view;

    -- Refrescar vista de productos con detalles (si existe)
    IF EXISTS (
        SELECT 1 FROM pg_matviews
        WHERE schemaname = 'stock' AND matviewname = 'products_with_details'
    ) THEN
        REFRESH MATERIALIZED VIEW CONCURRENTLY stock.products_with_details;
END IF;

    -- Log de la actualización
INSERT INTO shared.activity_logs (
    action, entity_type, entity_name, source
) VALUES (
             'refresh_materialized_views',
             'system',
             'shared.product_search_view,stock.products_with_details',
             'system'
         );

-- Registrar evento
PERFORM shared.log_system_event(
        'materialized_views_refreshed',
        'system',
        'views',
        jsonb_build_object(
            'views_refreshed', ARRAY['shared.product_search_view', 'stock.products_with_details'],
            'timestamp', NOW()
        ),
        NULL,
        NULL,
        'system'
    );
END;
$$ LANGUAGE plpgsql;

-- 🎯 FUNCIÓN AVANZADA PARA OBTENER SESIÓN CON CONTEXTO (del init-db.sql optimizada)
CREATE OR REPLACE FUNCTION shared.get_session_with_full_context(customer_phone_param VARCHAR)
RETURNS TABLE (
    session_data JSONB,
    customer_data JSONB,
    recent_orders JSONB,
    conversation_history JSONB,
    recommendations JSONB,
    cart_summary JSONB
) AS $$
DECLARE
v_session_data JSONB;
    v_customer_data JSONB;
    v_recent_orders JSONB;
    v_conversation_history JSONB;
    v_recommendations JSONB;
    v_cart_summary JSONB;
    v_customer_id INTEGER;
BEGIN
    -- Obtener sesión activa con más contexto
SELECT to_jsonb(cs.*) INTO v_session_data
FROM shared.customer_sessions cs
WHERE cs.customer_phone = customer_phone_param
  AND cs.expires_at > NOW()
ORDER BY cs.updated_at DESC
    LIMIT 1;

-- Obtener datos completos del cliente
SELECT
    c.id,
    jsonb_build_object(
            'id', c.id,
            'name', c.name,
            'email', c.email,
            'phone', c.phone,
            'addresses', c.addresses,
            'loyalty_tier', c.loyalty_tier,
            'loyalty_points', c.loyalty_points,
            'total_orders', c.total_orders,
            'total_spent', c.total_spent,
            'average_order_value', c.average_order_value,
            'last_order_date', c.last_order_date,
            'favorite_categories', c.favorite_categories,
            'purchase_patterns', c.purchase_patterns,
            'dietary_restrictions', c.dietary_restrictions,
            'customer_tier', CASE
                                 WHEN c.total_orders = 0 THEN 'new'
                                 WHEN c.total_orders <= 3 THEN 'occasional'
                                 WHEN c.total_orders <= 10 THEN 'regular'
                                 ELSE 'vip'
                END,
            'last_activity', c.last_activity
    )
INTO v_customer_id, v_customer_data
FROM shared.customers c
WHERE c.phone = customer_phone_param;

-- Obtener órdenes recientes con más detalle
SELECT jsonb_agg(order_data.* ORDER BY order_data.created_at DESC)
INTO v_recent_orders
FROM (
         SELECT
             o.id, o.order_number, o.total_amount, o.order_status,
             o.created_at, o.estimated_delivery_time, o.delivery_address,
             o.payment_method, o.payment_status,
             (
                 SELECT jsonb_agg(
                                jsonb_build_object(
                                        'product_id', oi.product_id,
                                        'product_name', oi.product_name,
                                        'quantity', oi.quantity,
                                        'unit_price', oi.unit_price,
                                        'total_price', oi.total_price,
                                        'item_status', oi.item_status
                                )
                        )
                 FROM shared.order_items oi
                 WHERE oi.order_id = o.id
             ) as items
         FROM shared.orders o
         WHERE o.customer_phone = customer_phone_param
         ORDER BY o.created_at DESC
             LIMIT 5
     ) order_data;

-- Obtener historial de conversación reciente
SELECT jsonb_agg(msg_data.* ORDER BY msg_data.message_timestamp DESC)
INTO v_conversation_history
FROM (
         SELECT
             ml.message_type,
             ml.message_content,
             ml.intent_detected,
             ml.intent_confidence,
             ml.sentiment_score,
             ml.message_timestamp,
             ml.direction,
             ml.entities_extracted
         FROM shared.message_logs ml
         WHERE ml.customer_phone = customer_phone_param
           AND ml.message_timestamp > NOW() - INTERVAL '24 hours'
         ORDER BY ml.message_timestamp DESC
             LIMIT 30
     ) msg_data;

-- Generar recomendaciones basadas en historial
SELECT jsonb_agg(rec_data.*)
INTO v_recommendations
FROM (
         SELECT
             p.id,
             p.name,
             p.price,
             p.image_url,
             'frequently_bought' as recommendation_type,
             COUNT(*) as purchase_frequency
         FROM shared.order_items oi
                  JOIN shared.orders o ON oi.order_id = o.id
                  JOIN stock.products p ON oi.product_id = p.id
         WHERE o.customer_phone = customer_phone_param
           AND p.is_available = true
           AND p.stock_quantity > 0
         GROUP BY p.id, p.name, p.price, p.image_url
         ORDER BY COUNT(*) DESC
             LIMIT 5

         UNION ALL

         SELECT
             p.id,
             p.name,
             p.price,
             p.image_url,
             'category_popular' as recommendation_type,
             p.popularity_score
         FROM stock.products p
         WHERE p.category_id IN (
             SELECT DISTINCT oi.product_id
             FROM shared.order_items oi
             JOIN shared.orders o ON oi.order_id = o.id
             WHERE o.customer_phone = customer_phone_param
             )
           AND p.is_available = true
           AND p.stock_quantity > 0
         ORDER BY p.popularity_score DESC
             LIMIT 3
     ) rec_data;

-- Obtener resumen del carrito actual
IF v_session_data IS NOT NULL THEN
SELECT jsonb_build_object(
               'items_count', jsonb_array_length(COALESCE((v_session_data->>'cart_data')::jsonb, '[]'::jsonb)),
               'estimated_total', (
                   SELECT SUM((item->>'quantity')::integer * (item->>'price')::decimal)
                   FROM jsonb_array_elements(COALESCE((v_session_data->>'cart_data')::jsonb, '[]'::jsonb)) AS item
               ),
               'cart_items', COALESCE((v_session_data->>'cart_data')::jsonb, '[]'::jsonb)
       ) INTO v_cart_summary;
ELSE
        v_cart_summary := jsonb_build_object('items_count', 0, 'estimated_total', 0, 'cart_items', '[]'::jsonb);
END IF;

RETURN QUERY SELECT
        COALESCE(v_session_data, '{}'::jsonb),
        COALESCE(v_customer_data, '{}'::jsonb),
        COALESCE(v_recent_orders, '[]'::jsonb),
        COALESCE(v_conversation_history, '[]'::jsonb),
        COALESCE(v_recommendations, '[]'::jsonb),
        COALESCE(v_cart_summary, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql;

-- 📊 VISTA PARA DASHBOARD EJECUTIVO
CREATE OR REPLACE VIEW analytics.executive_dashboard AS
SELECT
    -- Métricas del día
    (SELECT COUNT(*) FROM shared.orders WHERE DATE(created_at) = CURRENT_DATE) as orders_today,
    (SELECT COALESCE(SUM(total_amount), 0) FROM shared.orders WHERE DATE(created_at) = CURRENT_DATE AND order_status != 'cancelled') as revenue_today,
                                                                  (SELECT COUNT(DISTINCT customer_phone) FROM shared.orders WHERE DATE(created_at) = CURRENT_DATE) as unique_customers_today,

                                                                                                                            -- Métricas del mes
                                                                                                                                (SELECT COUNT(*) FROM shared.orders WHERE DATE_TRUNC('month', created_at) = DATE_TRUNC('month', CURRENT_DATE)) as orders_this_month,
                                                                                                                                                                        (SELECT COALESCE(SUM(total_amount), 0) FROM shared.orders WHERE DATE_TRUNC('month', created_at) = DATE_TRUNC('month', CURRENT_DATE) AND order_status != 'cancelled') as revenue_this_month,

                                                                                                                                                                                                                                  -- Stock crítico
                                                                                                                                                                                                                                      (SELECT COUNT(*) FROM stock.products WHERE stock_quantity = 0 AND is_available = true) as out_of_stock_products,
                                                                                                                                                                                                                                                                               (SELECT COUNT(*) FROM stock.products WHERE stock_quantity <= min_stock_alert AND stock_quantity > 0 AND is_available = true) as low_stock_products,

                                                                                                                                                                                                                                                                                                                    -- Valor del inventario
                                                                                                                                                                                                                                                                                                                        (SELECT COALESCE(SUM(stock_quantity * price), 0) FROM stock.products WHERE is_available = true) as total_inventory_value,

                                                                                                                                                                                                                                                                                                                                                                                             -- Sesiones activas
                                                                                                                                                                                                                                                                                                                                                                                                 (SELECT COUNT(*) FROM shared.customer_sessions WHERE expires_at > NOW()) as active_sessions,

                                                                                                                                                                                                                                                                                                                                                                                                                                                -- Mensajes del día
                                                                                                                                                                                                                                                                                                                                                                                                                                                    (SELECT COUNT(*) FROM shared.message_logs WHERE DATE(message_timestamp) = CURRENT_DATE) as messages_today,

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              -- Top productos del mes
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  (SELECT jsonb_agg(top_products.* ORDER BY top_products.total_sold DESC)
FROM (
    SELECT p.name, SUM(oi.quantity) as total_sold, SUM(oi.total_price) as total_revenue
    FROM shared.order_items oi
    JOIN stock.products p ON oi.product_id = p.id
    JOIN shared.orders o ON oi.order_id = o.id
    WHERE DATE_TRUNC('month', o.created_at) = DATE_TRUNC('month', CURRENT_DATE)
    AND o.order_status NOT IN ('cancelled')
    GROUP BY p.id, p.name
    ORDER BY SUM(oi.quantity) DESC
    LIMIT 10
    ) top_products
    ) as top_products_month;

-- 🔧 FUNCIÓN PARA OPTIMIZAR PERFORMANCE
CREATE OR REPLACE FUNCTION shared.optimize_database_performance()
RETURNS VOID AS $$
BEGIN
    -- Actualizar estadísticas de todas las tablas importantes
    ANALYZE shared.customers;
    ANALYZE shared.orders;
    ANALYZE shared.order_items;
    ANALYZE shared.customer_sessions;
    ANALYZE shared.message_logs;
    ANALYZE stock.products;
    ANALYZE stock.categories;
    ANALYZE stock.stock_movements;

    -- Refrescar vistas materializadas
    PERFORM shared.refresh_materialized_views();

    -- Limpiar datos obsoletos
    PERFORM shared.cleanup_expired_sessions();
    PERFORM shared.cleanup_expired_cache();

    -- Log de la optimización
INSERT INTO shared.activity_logs (
    action, entity_type, entity_name, source
) VALUES (
             'database_optimization', 'system', 'performance_optimization', 'system'
         );

RAISE NOTICE 'Optimización de base de datos completada';
END;
$$ LANGUAGE plpgsql;

-- 📈 VISTA PARA ANÁLISIS DE CONVERSIÓN
CREATE OR REPLACE VIEW analytics.conversion_funnel AS
WITH funnel_data AS (
    SELECT
        DATE(created_at) as date,
        COUNT(DISTINCT customer_phone) as unique_visitors,
        COUNT(*) as total_sessions
    FROM shared.customer_sessions
    WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY DATE(created_at)
),
     orders_data AS (
         SELECT
             DATE(created_at) as date,
             COUNT(DISTINCT customer_phone) as unique_buyers,
             COUNT(*) as total_orders,
             SUM(total_amount) as total_revenue
         FROM shared.orders
         WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
           AND order_status NOT IN ('cancelled')
         GROUP BY DATE(created_at)
     )
SELECT
    fd.date,
    fd.unique_visitors,
    fd.total_sessions,
    COALESCE(od.unique_buyers, 0) as unique_buyers,
    COALESCE(od.total_orders, 0) as total_orders,
    COALESCE(od.total_revenue, 0) as total_revenue,
    CASE
        WHEN fd.unique_visitors > 0
            THEN (COALESCE(od.unique_buyers, 0)::DECIMAL / fd.unique_visitors) * 100
        ELSE 0
        END as conversion_rate_percentage,
    CASE
        WHEN COALESCE(od.unique_buyers, 0) > 0
            THEN od.total_revenue / od.unique_buyers
        ELSE 0
        END as average_order_value
FROM funnel_data fd
         LEFT JOIN orders_data od ON fd.date = od.date
ORDER BY fd.date DESC;

-- ✅ VERIFICACIÓN DE INSTALACIÓN
DO $$
BEGIN
    RAISE NOTICE '✅ Views and Functions instaladas correctamente';
    RAISE NOTICE '🔍 Vista materializada de búsqueda: shared.product_search_view';
    RAISE NOTICE '📈 Análisis de rotación: analytics.inventory_turnover_analysis';
    RAISE NOTICE '📊 Dashboard ejecutivo: analytics.executive_dashboard';
    RAISE NOTICE '🎯 Funciones optimizadas de búsqueda y contexto disponibles';
    RAISE NOTICE '🔧 Función de optimización: shared.optimize_database_performance()';
END $$;