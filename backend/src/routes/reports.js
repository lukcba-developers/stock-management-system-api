import express from 'express';
import { pool } from '../db/db.js';
import { authenticateToken } from '../middleware/auth.js';

const router = express.Router();

// Rotación de Inventario
router.get('/inventory-turnover', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        p.id,
        p.name,
        p.stock_quantity,
        COUNT(o.id) as total_orders,
        SUM(oi.quantity) as total_quantity_sold,
        CASE 
          WHEN p.stock_quantity > 0 THEN 
            ROUND(SUM(oi.quantity)::numeric / p.stock_quantity, 2)
          ELSE 0 
        END as turnover_ratio
      FROM products p
      LEFT JOIN order_items oi ON p.id = oi.product_id
      LEFT JOIN orders o ON oi.order_id = o.id
      WHERE o.created_at >= NOW() - INTERVAL '30 days'
      GROUP BY p.id, p.name, p.stock_quantity
      ORDER BY turnover_ratio DESC;
    `);
    res.json(result.rows);
  } catch (error) {
    console.error('Error al obtener rotación de inventario:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// Productos Más Vendidos
router.get('/top-selling', authenticateToken, async (req, res) => {
  const { period = 30, limit = 10 } = req.query;
  try {
    const result = await pool.query(`
      SELECT 
        p.id,
        p.name,
        p.stock_quantity,
        SUM(oi.quantity) as total_quantity_sold,
        SUM(oi.quantity * oi.price) as total_revenue
      FROM products p
      JOIN order_items oi ON p.id = oi.product_id
      JOIN orders o ON oi.order_id = o.id
      WHERE o.created_at >= NOW() - INTERVAL '${period} days'
      GROUP BY p.id, p.name, p.stock_quantity
      ORDER BY total_quantity_sold DESC
      LIMIT $1;
    `, [limit]);
    res.json(result.rows);
  } catch (error) {
    console.error('Error al obtener productos más vendidos:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// Valor de Inventario por Categoría
router.get('/inventory-value-by-category', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        c.name as category,
        COUNT(p.id) as total_products,
        SUM(p.stock_quantity) as total_quantity,
        SUM(p.stock_quantity * p.price) as total_value
      FROM categories c
      LEFT JOIN products p ON c.id = p.category_id
      GROUP BY c.id, c.name
      ORDER BY total_value DESC;
    `);
    res.json(result.rows);
  } catch (error) {
    console.error('Error al obtener valor de inventario por categoría:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// Movimientos de Inventario
router.get('/inventory-movements', authenticateToken, async (req, res) => {
  const { startDate, endDate, type } = req.query;
  try {
    let query = `
      SELECT 
        ia.id,
        ia.product_id,
        p.name as product_name,
        ia.adjustment_type,
        ia.quantity_change,
        ia.reason,
        ia.created_at,
        u.username as adjusted_by
      FROM inventory_adjustments ia
      JOIN products p ON ia.product_id = p.id
      JOIN users u ON ia.user_id = u.id
      WHERE 1=1
    `;
    const params = [];
    let paramCount = 1;

    if (startDate) {
      query += ` AND ia.created_at >= $${paramCount}`;
      params.push(startDate);
      paramCount++;
    }
    if (endDate) {
      query += ` AND ia.created_at <= $${paramCount}`;
      params.push(endDate);
      paramCount++;
    }
    if (type) {
      query += ` AND ia.adjustment_type = $${paramCount}`;
      params.push(type);
      paramCount++;
    }

    query += ` ORDER BY ia.created_at DESC`;

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('Error al obtener movimientos de inventario:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// Rendimiento de Proveedores
router.get('/supplier-performance', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        s.id,
        s.name,
        s.contact_name,
        s.email,
        COUNT(p.id) as total_products,
        AVG(p.stock_quantity) as avg_stock,
        MIN(p.stock_quantity) as min_stock,
        MAX(p.stock_quantity) as max_stock,
        SUM(p.stock_quantity * p.price) as total_inventory_value
      FROM suppliers s
      LEFT JOIN products p ON s.id = p.supplier_id
      GROUP BY s.id, s.name, s.contact_name, s.email
      ORDER BY total_inventory_value DESC;
    `);
    res.json(result.rows);
  } catch (error) {
    console.error('Error al obtener rendimiento de proveedores:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// Tendencias de Ventas
router.get('/sales-trends', authenticateToken, async (req, res) => {
  const { period = 30 } = req.query;
  try {
    const result = await pool.query(`
      SELECT 
        DATE(o.created_at) as date,
        COUNT(DISTINCT o.id) as total_orders,
        SUM(oi.quantity) as total_items_sold,
        SUM(oi.quantity * oi.price) as total_revenue
      FROM orders o
      JOIN order_items oi ON o.id = oi.order_id
      WHERE o.created_at >= NOW() - INTERVAL '${period} days'
      GROUP BY DATE(o.created_at)
      ORDER BY date DESC;
    `);
    res.json(result.rows);
  } catch (error) {
    console.error('Error al obtener tendencias de ventas:', error);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

export default router; 