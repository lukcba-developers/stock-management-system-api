import { pool } from '../config/database.js';

export const createOrderFromWhatsApp = async ({ customerPhone, items, deliveryAddress }) => {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');
    
    // Crear la orden
    const orderResult = await client.query(
      `INSERT INTO orders (
        customer_phone,
        order_status,
        delivery_address,
        source
      ) VALUES ($1, $2, $3, $4)
      RETURNING id`,
      [
        customerPhone,
        'pending',
        deliveryAddress,
        'whatsapp'
      ]
    );
    
    const orderId = orderResult.rows[0].id;
    
    // Crear los items de la orden y actualizar stock
    for (const item of items) {
      // Insertar item de la orden
      await client.query(
        `INSERT INTO order_items (
          order_id,
          product_id,
          quantity,
          unit_price
        ) VALUES ($1, $2, $3, (
          SELECT price FROM products WHERE id = $2
        ))`,
        [orderId, item.productId, item.quantity]
      );
      
      // Actualizar stock
      await client.query(
        `UPDATE products 
         SET stock_quantity = stock_quantity - $1
         WHERE id = $2`,
        [item.quantity, item.productId]
      );
    }
    
    // Registrar la actividad
    await client.query(
      `INSERT INTO activity_logs (
        action,
        entity_type,
        entity_id,
        details
      ) VALUES ($1, $2, $3, $4)`,
      [
        'create_order',
        'order',
        orderId,
        {
          source: 'whatsapp',
          customerPhone,
          itemsCount: items.length
        }
      ]
    );
    
    await client.query('COMMIT');
    
    return { id: orderId };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

export const getOrderDetails = async (orderId) => {
  const result = await pool.query(
    `SELECT 
      o.*,
      json_agg(
        json_build_object(
          'id', oi.id,
          'product_id', oi.product_id,
          'product_name', p.name,
          'quantity', oi.quantity,
          'unit_price', oi.unit_price,
          'subtotal', oi.quantity * oi.unit_price
        )
      ) as items
    FROM orders o
    JOIN order_items oi ON o.id = oi.order_id
    JOIN products p ON oi.product_id = p.id
    WHERE o.id = $1
    GROUP BY o.id`,
    [orderId]
  );
  
  if (result.rows.length === 0) {
    throw new Error('Orden no encontrada');
  }
  
  return result.rows[0];
};

export const updateOrderStatus = async (orderId, status) => {
  const validStatuses = ['pending', 'processing', 'completed', 'cancelled'];
  
  if (!validStatuses.includes(status)) {
    throw new Error('Estado de orden inválido');
  }
  
  const result = await pool.query(
    `UPDATE orders 
     SET order_status = $1,
         updated_at = NOW()
     WHERE id = $2
     RETURNING *`,
    [status, orderId]
  );
  
  if (result.rows.length === 0) {
    throw new Error('Orden no encontrada');
  }
  
  // Registrar el cambio de estado
  await pool.query(
    `INSERT INTO activity_logs (
      action,
      entity_type,
      entity_id,
      details
    ) VALUES ($1, $2, $3, $4)`,
    [
      'update_order_status',
      'order',
      orderId,
      { newStatus: status }
    ]
  );
  
  return result.rows[0];
}; 