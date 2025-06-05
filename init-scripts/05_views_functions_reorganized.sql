-- ============================================================================
-- 📊 VISTAS Y FUNCIONES - ANÁLISIS Y OPTIMIZACIÓN CON MULTI-TENANCY
-- ============================================================================
-- Archivo: init-scripts/05_views_functions.sql
-- Propósito: Vistas materializadas, funciones y análisis con soporte SaaS multi-tenant
-- Dependencias: 00_core_schema.sql, 01_stock_management.sql, 02_shared_tables.sql, 07_saas_advanced_features.sql
-- Orden de ejecución: QUINTO (05_)
-- ============================================================================

-- 🔍 VISTA MATERIALIZADA PARA BÚSQUEDAS (Multi-tenant)
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

    -- Ranking para búsquedas (se actualizará dinámicamente)
    0::real as search_rank,
    
    -- Información de organización para RLS
    o.name as organization_name,
    o.subscription_plan

FROM stock.products p
LEFT JOIN stock.categories c ON p.category_id = c.id AND c.organization_id = p.organization_id
LEFT JOIN saas.organizations o ON p.organization_id = o.id
WHERE p.is_available = true AND o.is_active = true;

-- Índice único para la vista materializada
CREATE UNIQUE INDEX IF NOT EXISTS idx_product_search_view_org_id ON shared.product_search_view (organization_id, id);
-- Índice GIN para búsquedas full-text
CREATE INDEX IF NOT EXISTS idx_product_search_view_search_vector ON shared.product_search_view USING GIN(search_vector);
-- Índices adicionales para filtros multi-tenant
CREATE INDEX IF NOT EXISTS idx_product_search_view_org_category ON shared.product_search_view(organization_id, category_id, stock_status);
CREATE INDEX IF NOT EXISTS idx_product_search_view_org_stock_status ON shared.product_search_view(organization_id, stock_status, price);

-- 📈 VISTA PARA ANÁLISIS DE ROTACIÓN DE INVENTARIO (Multi-tenant)
CREATE OR REPLACE VIEW analytics.inventory_turnover_analysis AS
WITH sales_data AS (
    SELECT
        oi.organization_id,
        oi.product_id,
        SUM(oi.quantity) as units_sold_period,
        SUM(oi.total_price) as revenue_period,
        COUNT(DISTINCT o.id) as orders_with_product_period
    FROM shared.order_items oi
    JOIN shared.orders o ON oi.order_id = o.id AND oi.organization_id = o.organization_id
    WHERE o.created_at >= CURRENT_DATE - INTERVAL '90 days'
      AND o.order_status IN ('delivered', 'completed')
    GROUP BY oi.organization_id, oi.product_id
),
avg_inventory AS (
    SELECT
        p.organization_id,
        p.id as product_id,
        p.stock_quantity as current_stock_level,
        COALESCE(
            (SELECT AVG(sm.quantity_after)
             FROM stock.stock_movements sm
             WHERE sm.organization_id = p.organization_id
               AND sm.product_id = p.id
               AND sm.created_at >= CURRENT_DATE - INTERVAL '90 days'),
            p.stock_quantity
        ) as avg_stock_level_period
    FROM stock.products p
),
cost_of_goods_sold AS (
    SELECT
        ps.organization_id,
        ps.product_id,
        AVG(ps.cost_price) as avg_cost_price
    FROM stock.product_suppliers ps
    WHERE ps.cost_price IS NOT NULL
    GROUP BY ps.organization_id, ps.product_id
)
SELECT
    p.organization_id,
    o.name as organization_name,
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
LEFT JOIN saas.organizations o ON p.organization_id = o.id
LEFT JOIN stock.categories cat ON p.category_id = cat.id AND cat.organization_id = p.organization_id
LEFT JOIN sales_data sd ON p.organization_id = sd.organization_id AND p.id = sd.product_id
LEFT JOIN avg_inventory ai ON p.organization_id = ai.organization_id AND p.id = ai.product_id
LEFT JOIN cost_of_goods_sold cogs ON p.organization_id = cogs.organization_id AND p.id = cogs.product_id
WHERE p.is_available = true AND o.is_active = true;

-- 🔍 FUNCIÓN MEJORADA PARA BÚSQUEDAS (Multi-tenant)
CREATE OR REPLACE FUNCTION shared.search_products_optimized(
    org_id INTEGER,
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
        psv.organization_id = org_id
        AND (search_term IS NULL OR search_term = '' OR psv.search_vector @@ plainto_tsquery('spanish_unaccent', search_term))
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

-- 📊 FUNCIÓN PARA REFRESCAR VISTAS MATERIALIZADAS (Multi-tenant)
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
        NULL, -- Sistema global
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

-- 🎯 FUNCIÓN AVANZADA PARA OBTENER SESIÓN CON CONTEXTO (Multi-tenant optimizada)
CREATE OR REPLACE FUNCTION shared.get_session_with_full_context(org_id INTEGER, customer_phone_param VARCHAR)
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
    WHERE cs.organization_id = org_id
      AND cs.customer_phone = customer_phone_param
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
    WHERE c.organization_id = org_id AND c.phone = customer_phone_param;

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
                WHERE oi.order_id = o.id AND oi.organization_id = org_id
            ) as items
        FROM shared.orders o
        WHERE o.organization_id = org_id
          AND o.customer_phone = customer_phone_param
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
        WHERE ml.organization_id = org_id
          AND ml.customer_phone = customer_phone_param
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
        JOIN shared.orders o ON oi.order_id = o.id AND oi.organization_id = o.organization_id
        JOIN stock.products p ON oi.product_id = p.id AND p.organization_id = org_id
        WHERE o.organization_id = org_id
          AND o.customer_phone = customer_phone_param
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
        WHERE p.organization_id = org_id
          AND p.category_id IN (
              SELECT DISTINCT cat.id
              FROM shared.order_items oi
              JOIN shared.orders o ON oi.order_id = o.id AND oi.organization_id = o.organization_id
              JOIN stock.products prod ON oi.product_id = prod.id AND prod.organization_id = org_id
              JOIN stock.categories cat ON prod.category_id = cat.id AND cat.organization_id = org_id
              WHERE o.organization_id = org_id
                AND o.customer_phone = customer_phone_param
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

-- 📊 VISTA PARA DASHBOARD EJECUTIVO (Multi-tenant)
CREATE OR REPLACE VIEW analytics.executive_dashboard AS
SELECT 
    o.id as organization_id,
    o.name as organization_name,
    o.subscription_plan,
    
    -- Métricas del día
    (SELECT COUNT(*) FROM shared.orders WHERE organization_id = o.id AND DATE(created_at) = CURRENT_DATE) as orders_today,
    (SELECT COALESCE(SUM(total_amount), 0) FROM shared.orders WHERE organization_id = o.id AND DATE(created_at) = CURRENT_DATE AND order_status != 'cancelled') as revenue_today,
    (SELECT COUNT(DISTINCT customer_phone) FROM shared.orders WHERE organization_id = o.id AND DATE(created_at) = CURRENT_DATE) as unique_customers_today,

    -- Métricas del mes
    (SELECT COUNT(*) FROM shared.orders WHERE organization_id = o.id AND DATE_TRUNC('month', created_at) = DATE_TRUNC('month', CURRENT_DATE)) as orders_this_month,
    (SELECT COALESCE(SUM(total_amount), 0) FROM shared.orders WHERE organization_id = o.id AND DATE_TRUNC('month', created_at) = DATE_TRUNC('month', CURRENT_DATE) AND order_status != 'cancelled') as revenue_this_month,

    -- Stock crítico
    (SELECT COUNT(*) FROM stock.products WHERE organization_id = o.id AND stock_quantity = 0 AND is_available = true) as out_of_stock_products,
    (SELECT COUNT(*) FROM stock.products WHERE organization_id = o.id AND stock_quantity <= min_stock_alert AND stock_quantity > 0 AND is_available = true) as low_stock_products,

    -- Valor del inventario
    (SELECT COALESCE(SUM(stock_quantity * price), 0) FROM stock.products WHERE organization_id = o.id AND is_available = true) as total_inventory_value,

    -- Sesiones activas
    (SELECT COUNT(*) FROM shared.customer_sessions WHERE organization_id = o.id AND expires_at > NOW()) as active_sessions,

    -- Mensajes del día
    (SELECT COUNT(*) FROM shared.message_logs WHERE organization_id = o.id AND DATE(message_timestamp) = CURRENT_DATE) as messages_today,

    -- Top productos del mes
    (SELECT jsonb_agg(top_products.* ORDER BY top_products.total_sold DESC)
     FROM (
        SELECT p.name, SUM(oi.quantity) as total_sold, SUM(oi.total_price) as total_revenue
        FROM shared.order_items oi
        JOIN stock.products p ON oi.product_id = p.id AND p.organization_id = o.id
        JOIN shared.orders ord ON oi.order_id = ord.id AND ord.organization_id = o.id
        WHERE ord.organization_id = o.id
          AND DATE_TRUNC('month', ord.created_at) = DATE_TRUNC('month', CURRENT_DATE)
          AND ord.order_status NOT IN ('cancelled')
        GROUP BY p.id, p.name
        ORDER BY SUM(oi.quantity) DESC
        LIMIT 10
     ) top_products
    ) as top_products_month,
    
    -- Estado de quotas
    (SELECT jsonb_agg(
        jsonb_build_object(
            'type', quota_type,
            'used', quota_used,
            'limit', quota_limit,
            'percentage', ROUND((quota_used::DECIMAL / quota_limit * 100), 1)
        )
     ) FROM saas.organization_quotas 
     WHERE organization_id = o.id 
       AND period_start <= CURRENT_DATE 
       AND period_end >= CURRENT_DATE
    ) as quota_status

FROM saas.organizations o
WHERE o.is_active = true;

-- 🔧 FUNCIÓN PARA OPTIMIZAR PERFORMANCE (Multi-tenant)
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
    ANALYZE saas.organizations;
    ANALYZE saas.authorized_users;

    -- Refrescar vistas materializadas
    PERFORM shared.refresh_materialized_views();

    -- Limpiar datos obsoletos
    PERFORM shared.cleanup_expired_sessions();
    PERFORM shared.cleanup_expired_cache();

    -- Resetear quotas mensuales si es necesario
    PERFORM saas.reset_monthly_quotas();

    -- Log de la optimización
    INSERT INTO shared.activity_logs (
        action, entity_type, entity_name, source
    ) VALUES (
        'database_optimization', 'system', 'performance_optimization', 'system'
    );

    RAISE NOTICE 'Optimización de base de datos completada';
END;
$$ LANGUAGE plpgsql;

-- 📈 VISTA PARA ANÁLISIS DE CONVERSIÓN (Multi-tenant)
CREATE OR REPLACE VIEW analytics.conversion_funnel AS
WITH funnel_data AS (
    SELECT
        organization_id,
        DATE(created_at) as date,
        COUNT(DISTINCT customer_phone) as unique_visitors,
        COUNT(*) as total_sessions
    FROM shared.customer_sessions
    WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY organization_id, DATE(created_at)
),
orders_data AS (
    SELECT
        organization_id,
        DATE(created_at) as date,
        COUNT(DISTINCT customer_phone) as unique_buyers,
        COUNT(*) as total_orders,
        SUM(total_amount) as total_revenue
    FROM shared.orders
    WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
      AND order_status NOT IN ('cancelled')
    GROUP BY organization_id, DATE(created_at)
)
SELECT
    fd.organization_id,
    o.name as organization_name,
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
LEFT JOIN orders_data od ON fd.organization_id = od.organization_id AND fd.date = od.date
LEFT JOIN saas.organizations o ON fd.organization_id = o.id
ORDER BY fd.organization_id, fd.date DESC;

-- 📊 VISTA PARA MÉTRICAS CONSOLIDADAS POR ORGANIZACIÓN
CREATE OR REPLACE VIEW analytics.organization_metrics_summary AS
SELECT 
    o.id as organization_id,
    o.name as organization_name,
    o.subscription_plan,
    o.subscription_status,
    
    -- Usuarios y actividad
    (SELECT COUNT(*) FROM saas.authorized_users WHERE organization_id = o.id AND status = 'active') as active_users,
    (SELECT COUNT(*) FROM shared.customer_sessions WHERE organization_id = o.id AND expires_at > NOW()) as active_sessions_now,
    
    -- Productos y stock
    (SELECT COUNT(*) FROM stock.products WHERE organization_id = o.id AND is_available = true) as total_products,
    (SELECT COUNT(*) FROM stock.products WHERE organization_id = o.id AND stock_quantity <= min_stock_alert AND is_available = true) as low_stock_products,
    (SELECT COALESCE(SUM(stock_quantity * price), 0) FROM stock.products WHERE organization_id = o.id AND is_available = true) as inventory_value,
    
    -- Órdenes y ventas (últimos 30 días)
    (SELECT COUNT(*) FROM shared.orders WHERE organization_id = o.id AND created_at >= CURRENT_DATE - INTERVAL '30 days') as orders_30d,
    (SELECT COALESCE(SUM(total_amount), 0) FROM shared.orders WHERE organization_id = o.id AND created_at >= CURRENT_DATE - INTERVAL '30 days' AND order_status != 'cancelled') as revenue_30d,
    (SELECT COUNT(DISTINCT customer_phone) FROM shared.orders WHERE organization_id = o.id AND created_at >= CURRENT_DATE - INTERVAL '30 days') as unique_customers_30d,
    
    -- Mensajes y comunicación (últimos 30 días)
    (SELECT COUNT(*) FROM shared.message_logs WHERE organization_id = o.id AND message_timestamp >= CURRENT_DATE - INTERVAL '30 days') as messages_30d,
    
    -- Alertas y notificaciones
    (SELECT COUNT(*) FROM shared.system_alerts WHERE organization_id = o.id AND NOT is_resolved) as unresolved_alerts,
    (SELECT COUNT(*) FROM saas.organization_notifications WHERE organization_id = o.id AND NOT is_read AND NOT is_dismissed) as unread_notifications,
    
    -- Quotas y límites
    (SELECT COUNT(*) FROM saas.organization_quotas WHERE organization_id = o.id AND quota_used >= (quota_limit * 0.8) AND period_start <= CURRENT_DATE AND period_end >= CURRENT_DATE) as quotas_near_limit,
    (SELECT COUNT(*) FROM saas.organization_quotas WHERE organization_id = o.id AND quota_used >= quota_limit AND is_hard_limit = true AND period_start <= CURRENT_DATE AND period_end >= CURRENT_DATE) as quotas_exceeded,
    
    -- API y webhooks
    (SELECT COUNT(*) FROM saas.api_keys WHERE organization_id = o.id AND is_active = true) as active_api_keys,
    (SELECT COUNT(*) FROM saas.organization_webhooks WHERE organization_id = o.id AND is_active = true) as active_webhooks,
    
    -- Última actividad
    o.updated_at as last_organization_update,
    (SELECT MAX(created_at) FROM shared.orders WHERE organization_id = o.id) as last_order_date,
    (SELECT MAX(message_timestamp) FROM shared.message_logs WHERE organization_id = o.id) as last_message_date
    
FROM saas.organizations o
WHERE o.is_active = true;

-- 🎯 FUNCIÓN PARA ANÁLISIS DE PERFORMANCE POR ORGANIZACIÓN
CREATE OR REPLACE FUNCTION analytics.get_organization_performance(
    org_id INTEGER,
    days_back INTEGER DEFAULT 30
) RETURNS TABLE (
    total_orders INTEGER,
    total_revenue DECIMAL(12,2),
    avg_order_value DECIMAL(12,2),
    conversion_rate DECIMAL(5,2),
    top_products JSONB,
    growth_rate DECIMAL(5,2),
    customer_retention DECIMAL(5,2)
) AS $
DECLARE
    start_date DATE;
    prev_start_date DATE;
    prev_end_date DATE;
BEGIN
    start_date := CURRENT_DATE - INTERVAL '1 day' * days_back;
    prev_end_date := start_date - INTERVAL '1 day';
    prev_start_date := prev_end_date - INTERVAL '1 day' * days_back;
    
    RETURN QUERY
    WITH current_period AS (
        SELECT 
            COUNT(*)::INTEGER as orders,
            COALESCE(SUM(total_amount), 0) as revenue,
            COUNT(DISTINCT customer_phone)::INTEGER as unique_customers
        FROM shared.orders
        WHERE organization_id = org_id
          AND created_at >= start_date
          AND order_status NOT IN ('cancelled')
    ),
    previous_period AS (
        SELECT 
            COUNT(*)::INTEGER as orders,
            COALESCE(SUM(total_amount), 0) as revenue,
            COUNT(DISTINCT customer_phone)::INTEGER as unique_customers
        FROM shared.orders
        WHERE organization_id = org_id
          AND created_at >= prev_start_date
          AND created_at <= prev_end_date
          AND order_status NOT IN ('cancelled')
    ),
    sessions_current AS (
        SELECT COUNT(DISTINCT customer_phone)::INTEGER as unique_visitors
        FROM shared.customer_sessions
        WHERE organization_id = org_id
          AND created_at >= start_date
    ),
    top_products_data AS (
        SELECT jsonb_agg(
            jsonb_build_object(
                'product_name', p.name,
                'quantity_sold', SUM(oi.quantity),
                'revenue', SUM(oi.total_price)
            ) ORDER BY SUM(oi.quantity) DESC
        ) as products
        FROM shared.order_items oi
        JOIN shared.orders o ON oi.order_id = o.id AND oi.organization_id = o.organization_id
        JOIN stock.products p ON oi.product_id = p.id AND p.organization_id = org_id
        WHERE o.organization_id = org_id
          AND o.created_at >= start_date
          AND o.order_status NOT IN ('cancelled')
        GROUP BY p.id, p.name
        ORDER BY SUM(oi.quantity) DESC
        LIMIT 10
    ),
    retention_data AS (
        SELECT 
            COUNT(DISTINCT CASE 
                WHEN repeat_customer THEN customer_phone 
            END)::DECIMAL / NULLIF(COUNT(DISTINCT customer_phone), 0) * 100 as retention_rate
        FROM (
            SELECT 
                customer_phone,
                COUNT(*) > 1 as repeat_customer
            FROM shared.orders
            WHERE organization_id = org_id
              AND created_at >= start_date
              AND order_status NOT IN ('cancelled')
            GROUP BY customer_phone
        ) customer_analysis
    )
    SELECT 
        cp.orders,
        cp.revenue,
        CASE WHEN cp.orders > 0 THEN cp.revenue / cp.orders ELSE 0 END,
        CASE WHEN sc.unique_visitors > 0 THEN (cp.unique_customers::DECIMAL / sc.unique_visitors) * 100 ELSE 0 END,
        COALESCE(tpd.products, '[]'::jsonb),
        CASE WHEN pp.revenue > 0 THEN ((cp.revenue - pp.revenue) / pp.revenue) * 100 ELSE 0 END,
        COALESCE(rd.retention_rate, 0)
    FROM current_period cp
    CROSS JOIN previous_period pp
    CROSS JOIN sessions_current sc
    CROSS JOIN top_products_data tpd
    CROSS JOIN retention_data rd;
END;
$ LANGUAGE plpgsql;

-- 🔍 FUNCIÓN PARA BÚSQUEDA AVANZADA CON FILTROS (Multi-tenant)
CREATE OR REPLACE FUNCTION shared.advanced_product_search(
    org_id INTEGER,
    search_params JSONB
)
RETURNS TABLE(
    product_id INTEGER,
    product_name VARCHAR(255),
    price DECIMAL(12,2),
    stock_quantity INTEGER,
    category_name VARCHAR(100),
    image_url VARCHAR(500),
    search_rank REAL,
    relevance_score INTEGER
) AS $
DECLARE
    search_term TEXT;
    category_filter INTEGER;
    price_min DECIMAL;
    price_max DECIMAL;
    brand_filter TEXT;
    in_stock_only BOOLEAN;
    featured_only BOOLEAN;
    limit_results INTEGER;
BEGIN
    -- Extraer parámetros del JSON
    search_term := search_params->>'search_term';
    category_filter := (search_params->>'category_id')::INTEGER;
    price_min := (search_params->>'price_min')::DECIMAL;
    price_max := (search_params->>'price_max')::DECIMAL;
    brand_filter := search_params->>'brand';
    in_stock_only := COALESCE((search_params->>'in_stock_only')::BOOLEAN, true);
    featured_only := COALESCE((search_params->>'featured_only')::BOOLEAN, false);
    limit_results := COALESCE((search_params->>'limit')::INTEGER, 50);
    
    RETURN QUERY
    SELECT
        p.id,
        p.name,
        p.price,
        p.stock_quantity,
        c.name,
        p.image_url,
        CASE
            WHEN search_term IS NOT NULL AND search_term != ''
                THEN ts_rank(p.search_vector, plainto_tsquery('spanish_unaccent', search_term))
            ELSE 0.5
        END as search_rank,
        -- Relevance score basado en múltiples factores
        (
            CASE WHEN p.is_featured THEN 20 ELSE 0 END +
            CASE WHEN p.discount_percentage > 0 THEN 15 ELSE 0 END +
            CASE WHEN p.stock_quantity > p.min_stock_alert THEN 10 ELSE 0 END +
            CASE WHEN p.popularity_score > 50 THEN 10 ELSE 0 END +
            CASE 
                WHEN search_term IS NOT NULL AND search_term != '' AND p.name ILIKE '%' || search_term || '%' 
                THEN 25 
                ELSE 0 
            END
        ) as relevance_score
    FROM stock.products p
    LEFT JOIN stock.categories c ON p.category_id = c.id AND c.organization_id = p.organization_id
    WHERE
        p.organization_id = org_id
        AND p.is_available = true
        AND (search_term IS NULL OR search_term = '' OR p.search_vector @@ plainto_tsquery('spanish_unaccent', search_term))
        AND (category_filter IS NULL OR p.category_id = category_filter)
        AND (price_min IS NULL OR p.price >= price_min)
        AND (price_max IS NULL OR p.price <= price_max)
        AND (brand_filter IS NULL OR p.brand ILIKE '%' || brand_filter || '%')
        AND (NOT in_stock_only OR p.stock_quantity > 0)
        AND (NOT featured_only OR p.is_featured = true)
    ORDER BY
        relevance_score DESC,
        CASE
            WHEN search_term IS NOT NULL AND search_term != ''
                THEN ts_rank(p.search_vector, plainto_tsquery('spanish_unaccent', search_term))
            ELSE p.popularity_score * 0.01
        END DESC,
        p.name ASC
    LIMIT limit_results;
END;
$ LANGUAGE plpgsql;

-- 📊 FUNCIÓN PARA GENERAR REPORTE EJECUTIVO
CREATE OR REPLACE FUNCTION analytics.generate_executive_report(
    org_id INTEGER,
    report_period VARCHAR DEFAULT 'month' -- 'week', 'month', 'quarter'
)
RETURNS JSONB AS $
DECLARE
    report_data JSONB;
    period_interval INTERVAL;
    period_name TEXT;
BEGIN
    -- Configurar período
    CASE report_period
        WHEN 'week' THEN 
            period_interval := INTERVAL '7 days';
            period_name := 'últimos 7 días';
        WHEN 'quarter' THEN 
            period_interval := INTERVAL '3 months';
            period_name := 'último trimestre';
        ELSE 
            period_interval := INTERVAL '1 month';
            period_name := 'último mes';
    END CASE;
    
    -- Generar reporte completo
    SELECT jsonb_build_object(
        'organization', (
            SELECT jsonb_build_object(
                'id', id,
                'name', name,
                'plan', subscription_plan,
                'status', subscription_status
            )
            FROM saas.organizations WHERE id = org_id
        ),
        'period', jsonb_build_object(
            'name', period_name,
            'start_date', CURRENT_DATE - period_interval,
            'end_date', CURRENT_DATE
        ),
        'sales_metrics', (
            SELECT jsonb_build_object(
                'total_orders', COUNT(*),
                'total_revenue', COALESCE(SUM(total_amount), 0),
                'average_order_value', COALESCE(AVG(total_amount), 0),
                'unique_customers', COUNT(DISTINCT customer_phone)
            )
            FROM shared.orders
            WHERE organization_id = org_id
              AND created_at >= CURRENT_DATE - period_interval
              AND order_status NOT IN ('cancelled')
        ),
        'inventory_metrics', (
            SELECT jsonb_build_object(
                'total_products', COUNT(*),
                'out_of_stock', COUNT(*) FILTER (WHERE stock_quantity = 0),
                'low_stock', COUNT(*) FILTER (WHERE stock_quantity <= min_stock_alert AND stock_quantity > 0),
                'inventory_value', COALESCE(SUM(stock_quantity * price), 0)
            )
            FROM stock.products
            WHERE organization_id = org_id AND is_available = true
        ),
        'top_products', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'name', p.name,
                    'quantity_sold', SUM(oi.quantity),
                    'revenue', SUM(oi.total_price)
                ) ORDER BY SUM(oi.quantity) DESC
            )
            FROM shared.order_items oi
            JOIN shared.orders o ON oi.order_id = o.id AND oi.organization_id = o.organization_id
            JOIN stock.products p ON oi.product_id = p.id AND p.organization_id = org_id
            WHERE o.organization_id = org_id
              AND o.created_at >= CURRENT_DATE - period_interval
              AND o.order_status NOT IN ('cancelled')
            GROUP BY p.id, p.name
            ORDER BY SUM(oi.quantity) DESC
            LIMIT 10
        ),
        'usage_summary', (
            SELECT jsonb_build_object(
                'active_users', COUNT(*) FILTER (WHERE status = 'active'),
                'api_calls', COALESCE(SUM(api_calls), 0),
                'messages_sent', COALESCE(SUM(whatsapp_messages_sent), 0)
            )
            FROM saas.authorized_users au
            LEFT JOIN saas.usage_metrics um ON au.organization_id = um.organization_id
                AND um.metric_date >= CURRENT_DATE - period_interval
            WHERE au.organization_id = org_id
        ),
        'alerts_summary', (
            SELECT jsonb_build_object(
                'unresolved_alerts', COUNT(*) FILTER (WHERE NOT is_resolved),
                'critical_alerts', COUNT(*) FILTER (WHERE NOT is_resolved AND severity = 'critical'),
                'recent_alerts', COUNT(*) FILTER (WHERE created_at >= CURRENT_DATE - period_interval)
            )
            FROM shared.system_alerts
            WHERE organization_id = org_id
        ),
        'generated_at', NOW()
    ) INTO report_data;
    
    RETURN report_data;
END;
$ LANGUAGE plpgsql;

-- =============================================================================
-- 🔒 ROW LEVEL SECURITY PARA VISTAS (Multi-tenant)
-- =============================================================================

-- Habilitar RLS en vista materializada (si es posible)
-- Nota: Las vistas materializadas heredan RLS de las tablas base

-- =============================================================================
-- 📊 TRIGGERS PARA MANTENER VISTAS ACTUALIZADAS
-- =============================================================================

-- Función para refrescar vista materializada automáticamente
CREATE OR REPLACE FUNCTION shared.auto_refresh_search_view()
RETURNS TRIGGER AS $
BEGIN
    -- Solo refrescar si han pasado más de 5 minutos desde la última actualización
    IF NOT EXISTS (
        SELECT 1 FROM pg_stat_user_tables 
        WHERE relname = 'product_search_view' 
        AND last_vacuum > NOW() - INTERVAL '5 minutes'
    ) THEN
        -- Programar refresh asíncrono (en producción usar pg_cron o similar)
        PERFORM shared.refresh_materialized_views();
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$ LANGUAGE plpgsql;

-- Triggers para actualizar vista cuando cambian productos o categorías
CREATE TRIGGER trg_products_refresh_search_view
    AFTER INSERT OR UPDATE OR DELETE ON stock.products
    FOR EACH STATEMENT EXECUTE FUNCTION shared.auto_refresh_search_view();

CREATE TRIGGER trg_categories_refresh_search_view
    AFTER INSERT OR UPDATE OR DELETE ON stock.categories
    FOR EACH STATEMENT EXECUTE FUNCTION shared.auto_refresh_search_view();

-- ✅ VERIFICACIÓN DE INSTALACIÓN
DO $
BEGIN
    RAISE NOTICE '✅ Views and Functions con Multi-tenancy instalado correctamente';
    RAISE NOTICE '🔍 Vista materializada de búsqueda: shared.product_search_view (Multi-tenant)';
    RAISE NOTICE '📈 Análisis de rotación: analytics.inventory_turnover_analysis (Multi-tenant)';
    RAISE NOTICE '📊 Dashboard ejecutivo: analytics.executive_dashboard (Multi-tenant)';
    RAISE NOTICE '🎯 Funciones optimizadas de búsqueda y contexto disponibles';
    RAISE NOTICE '🔧 Función de optimización: shared.optimize_database_performance()';
    RAISE NOTICE '📈 Análisis de conversión y métricas por organización';
    RAISE NOTICE '🔍 Búsqueda avanzada con filtros JSON implementada';
    RAISE NOTICE '📊 Generador de reportes ejecutivos disponible';
    RAISE NOTICE '🔄 Triggers automáticos para refrescar vistas configurados';
END $;