import express from 'express';
import { authenticateToken } from '../middleware/auth.js';
import pool from '../config/database.js';
import { subDays, startOfDay, endOfDay, format } from 'date-fns';

const router = express.Router();

// Estadísticas principales con caché
let statsCache = {
  data: null,
  timestamp: null,
  ttl: 5 * 60 * 1000 // 5 minutos
};

router.get('/stats', authenticateToken, async (req, res) => {
  try {
    // Verificar caché
    if (statsCache.data && statsCache.timestamp && (Date.now() - statsCache.timestamp < statsCache.ttl)) {
      return res.json({ success: true, data: statsCache.data, cached: true });
    }

    const { startDate, endDate } = req.query;
    const start = startDate ? new Date(startDate) : startOfDay(subDays(new Date(), 30));
    const end = endDate ? new Date(endDate) : endOfDay(new Date());

    const statsQuery = `
      WITH product_stats AS (
        SELECT
          COUNT(*) as total_products,
          COUNT(*) FILTER (WHERE is_available = true AND stock_quantity <= min_stock_alert AND stock_quantity > 0) as low_stock_products,
          COUNT(*) FILTER (WHERE is_available = true AND stock_quantity = 0) as out_of_stock,
          SUM(CASE WHEN is_available = true THEN stock_quantity * price ELSE 0 END) as total_value
        FROM products
      ),
      sales_stats AS (
        SELECT
          COUNT(DISTINCT o.id) as orders_today,
          COALESCE(SUM(o.total_amount), 0) as revenue_today
        FROM orders o
        WHERE DATE(o.created_at) = CURRENT_DATE
        AND o.order_status IN ('delivered', 'completed', 'paid')
      ),
      top_selling AS (
        SELECT 
          p.id,
          p.name,
          p.image_url,
          COALESCE(SUM(oi.quantity), 0) as total_sold
        FROM products p
        LEFT JOIN order_items oi ON p.id = oi.product_id
        LEFT JOIN orders o ON oi.order_id = o.id
        WHERE o.created_at >= $1 
          AND o.created_at <= $2
          AND o.order_status IN ('delivered', 'completed', 'paid')
        GROUP BY p.id, p.name, p.image_url
        ORDER BY total_sold DESC
        LIMIT 5
      ),
      stock_alerts AS (
        SELECT 
          p.id,
          p.name as product_name,
          p.stock_quantity as current_stock,
          p.min_stock_alert as minimum_stock,
          c.name as category_name,
          p.image_url
        FROM products p
        JOIN categories c ON p.category_id = c.id
        WHERE p.stock_quantity <= p.min_stock_alert
        AND p.is_available = true
        ORDER BY (p.stock_quantity::float / NULLIF(p.min_stock_alert, 0))
        LIMIT 10
      ),
      recent_movements AS (
        SELECT 
          COUNT(*) as total_movements,
          COUNT(*) FILTER (WHERE movement_type = 'in') as movements_in,
          COUNT(*) FILTER (WHERE movement_type = 'out') as movements_out
        FROM stock_movements
        WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
      )
      SELECT 
        ps.total_products,
        ps.low_stock_products,
        ps.out_of_stock as outOfStockProducts,
        ps.total_value as totalInventoryValue,
        ss.orders_today as ordersToday,
        ss.revenue_today as revenueToday,
        (SELECT JSON_AGG(row_to_json(ts)) FROM top_selling ts) as topSellingProducts,
        (SELECT JSON_AGG(row_to_json(sa)) FROM stock_alerts sa) as stockAlerts,
        rm.total_movements as weeklyMovements,
        rm.movements_in as weeklyMovementsIn,
        rm.movements_out as weeklyMovementsOut
      FROM product_stats ps, sales_stats ss, recent_movements rm
    `;

    const result = await pool.query(statsQuery, [start, end]);
    const data = result.rows[0];
    
    // Actualizar caché
    statsCache.data = data;
    statsCache.timestamp = Date.now();
    
    res.json({ success: true, data, cached: false });
    
  } catch (error) {
    console.error('Error obteniendo estadísticas:', error);
    // Si falla la BD, usar datos mock como fallback
    const mockStats = {
      totalProducts: 0,
      lowStockProducts: 0,
      outOfStockProducts: 0,
      totalInventoryValue: 0,
      ordersToday: 0,
      revenueToday: 0,
      topSellingProducts: [],
      stockAlerts: [],
      weeklyMovements: 0,
      weeklyMovementsIn: 0,
      weeklyMovementsOut: 0
    };
    res.json({ success: true, data: mockStats, error: true });
  }
});

// Gráficos de tendencias
router.get('/charts/stock-evolution', authenticateToken, async (req, res) => {
  try {
    const { days = 30 } = req.query;
    const startDate = subDays(new Date(), parseInt(days));
    
    const query = `
      WITH date_series AS (
        SELECT generate_series(
          DATE($1),
          CURRENT_DATE,
          '1 day'::interval
        )::date as date
      ),
      daily_movements AS (
        SELECT 
          DATE(created_at) as date,
          SUM(CASE WHEN movement_type = 'in' THEN quantity_change ELSE 0 END) as quantity_in,
          SUM(CASE WHEN movement_type = 'out' THEN quantity_change ELSE 0 END) as quantity_out
        FROM stock_movements
        WHERE created_at >= $1
        GROUP BY DATE(created_at)
      )
      SELECT 
        ds.date,
        COALESCE(dm.quantity_in, 0) as in_quantity,
        COALESCE(dm.quantity_out, 0) as out_quantity,
        COALESCE(dm.quantity_in, 0) - COALESCE(dm.quantity_out, 0) as net_change
      FROM date_series ds
      LEFT JOIN daily_movements dm ON ds.date = dm.date
      ORDER BY ds.date
    `;
    
    const result = await pool.query(query, [startDate]);
    
    res.json({
      success: true,
      data: result.rows.map(row => ({
        date: format(row.date, 'yyyy-MM-dd'),
        in: parseInt(row.in_quantity),
        out: parseInt(row.out_quantity),
        net: parseInt(row.net_change)
      }))
    });
    
  } catch (error) {
    console.error('Error obteniendo evolución de stock:', error);
    res.status(500).json({ error: 'Error al obtener datos del gráfico' });
  }
});

// Análisis de rotación
router.get('/inventory-turnover', authenticateToken, async (req, res) => {
  try {
    const query = `
      SELECT 
        category_name,
        COUNT(*) as product_count,
        AVG(annual_turnover_rate) as avg_turnover_rate,
        SUM(current_stock_value) as total_stock_value,
        AVG(days_of_stock) as avg_days_of_stock
      FROM inventory_turnover_analysis
      GROUP BY category_name
      ORDER BY avg_turnover_rate DESC NULLS LAST
    `;
    
    const result = await pool.query(query);
    
    res.json({
      success: true,
      data: result.rows
    });
    
  } catch (error) {
    console.error('Error obteniendo análisis de rotación:', error);
    res.status(500).json({ error: 'Error al obtener análisis de rotación' });
  }
});

export default router; 