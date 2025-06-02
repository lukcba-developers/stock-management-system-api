import { pool } from '../config/database.js';
import { sendStockAlert } from '../websocket/stockNotifications.js';

export const checkAndCreateStockAlerts = async (productId, currentStock, minStock) => {
  try {
    // Determinar el nivel de alerta
    let alertLevel = 'normal';
    if (currentStock === 0) {
      alertLevel = 'out_of_stock';
    } else if (currentStock <= minStock * 0.5) {
      alertLevel = 'critical';
    } else if (currentStock <= minStock) {
      alertLevel = 'warning';
    }

    // Si hay una alerta, crear el registro
    if (alertLevel !== 'normal') {
      const query = `
        INSERT INTO low_stock_alerts (product_id, alert_level, notification_sent)
        VALUES ($1, $2, false)
        RETURNING id
      `;
      const result = await pool.query(query, [productId, alertLevel]);
      
      // Enviar notificación WebSocket
      sendStockAlert(productId, currentStock, minStock);
      
      // Marcar la alerta como notificada
      await pool.query(
        'UPDATE low_stock_alerts SET notification_sent = true WHERE id = $1',
        [result.rows[0].id]
      );
    }

    return alertLevel;
  } catch (error) {
    console.error('Error al crear alerta de stock:', error);
    throw error;
  }
};

export const resolveStockAlert = async (alertId) => {
  try {
    const query = `
      UPDATE low_stock_alerts 
      SET resolved_at = NOW() 
      WHERE id = $1
      RETURNING *
    `;
    const result = await pool.query(query, [alertId]);
    return result.rows[0];
  } catch (error) {
    console.error('Error al resolver alerta de stock:', error);
    throw error;
  }
};

export const getActiveAlerts = async () => {
  try {
    const query = `
      SELECT 
        la.*,
        p.name as product_name,
        p.stock_quantity,
        p.min_stock_alert
      FROM low_stock_alerts la
      JOIN products p ON la.product_id = p.id
      WHERE la.resolved_at IS NULL
      ORDER BY la.created_at DESC
    `;
    const result = await pool.query(query);
    return result.rows;
  } catch (error) {
    console.error('Error al obtener alertas activas:', error);
    throw error;
  }
}; 