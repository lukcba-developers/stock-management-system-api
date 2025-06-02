import { pool } from '../config/database.js';
import { checkAndCreateStockAlerts } from './inventoryAlertService.js';

export const createInventoryAdjustment = async ({
  productId,
  adjustmentType,
  quantityChange,
  reason,
  costImpact,
  createdBy
}) => {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');

    // 1. Crear el registro de ajuste
    const adjustmentQuery = `
      INSERT INTO inventory_adjustments (
        product_id, adjustment_type, quantity_change, 
        reason, cost_impact, created_by
      )
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING id
    `;
    
    const adjustmentResult = await client.query(adjustmentQuery, [
      productId,
      adjustmentType,
      quantityChange,
      reason,
      costImpact,
      createdBy
    ]);

    // 2. Actualizar el stock del producto
    const updateStockQuery = `
      UPDATE products 
      SET stock_quantity = stock_quantity + $1
      WHERE id = $2
      RETURNING stock_quantity, min_stock_alert
    `;
    
    const stockResult = await client.query(updateStockQuery, [quantityChange, productId]);
    
    // 3. Verificar y crear alertas si es necesario
    await checkAndCreateStockAlerts(
      productId,
      stockResult.rows[0].stock_quantity,
      stockResult.rows[0].min_stock_alert
    );

    await client.query('COMMIT');
    
    return {
      adjustmentId: adjustmentResult.rows[0].id,
      newStockQuantity: stockResult.rows[0].stock_quantity
    };
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error al crear ajuste de inventario:', error);
    throw error;
  } finally {
    client.release();
  }
};

export const getInventoryAdjustments = async (filters = {}) => {
  try {
    let query = `
      SELECT 
        ia.*,
        p.name as product_name,
        au.name as created_by_name
      FROM inventory_adjustments ia
      JOIN products p ON ia.product_id = p.id
      LEFT JOIN admin_users au ON ia.created_by = au.id
      WHERE 1=1
    `;
    
    const queryParams = [];
    let paramCount = 0;

    if (filters.productId) {
      paramCount++;
      query += ` AND ia.product_id = $${paramCount}`;
      queryParams.push(filters.productId);
    }

    if (filters.adjustmentType) {
      paramCount++;
      query += ` AND ia.adjustment_type = $${paramCount}`;
      queryParams.push(filters.adjustmentType);
    }

    if (filters.startDate) {
      paramCount++;
      query += ` AND ia.created_at >= $${paramCount}`;
      queryParams.push(filters.startDate);
    }

    if (filters.endDate) {
      paramCount++;
      query += ` AND ia.created_at <= $${paramCount}`;
      queryParams.push(filters.endDate);
    }

    query += ` ORDER BY ia.created_at DESC`;

    const result = await pool.query(query, queryParams);
    return result.rows;
  } catch (error) {
    console.error('Error al obtener ajustes de inventario:', error);
    throw error;
  }
}; 