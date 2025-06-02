import express from 'express';
import { pool } from '../config/database.js';
import { authenticateToken } from '../middleware/auth.js';
import { validateOrder } from '../middleware/validation.js';
import { createOrderFromWhatsApp } from '../services/orderService.js';
import { sendStockAlert } from '../websocket/stockNotifications.js';
import {
  validateN8NApiKey,
  webhookLimiter,
  stockLimiter,
  validateSyncData,
  sanitizeInput
} from '../middleware/security.js';

const router = express.Router();

// Webhook para recibir pedidos de WhatsApp
router.post('/webhook/order',
  validateN8NApiKey,
  webhookLimiter,
  sanitizeInput,
  validateOrder,
  async (req, res) => {
    try {
      const { customerPhone, items, deliveryAddress } = req.body;
      
      // Validar stock disponible
      const stockValidation = await validateStockAvailability(items);
      if (!stockValidation.valid) {
        return res.status(400).json({
          error: 'Stock insuficiente',
          details: stockValidation.details
        });
      }
      
      // Crear orden y reducir stock
      const order = await createOrderFromWhatsApp({
        customerPhone,
        items,
        deliveryAddress
      });
      
      // Notificar cambios de stock
      for (const item of items) {
        const product = await pool.query(
          'SELECT * FROM products WHERE id = $1',
          [item.productId]
        );
        
        if (product.rows[0].stock_quantity <= product.rows[0].min_stock_alert) {
          sendStockAlert({
            productId: item.productId,
            productName: product.rows[0].name,
            currentStock: product.rows[0].stock_quantity,
            minStock: product.rows[0].min_stock_alert
          });
        }
      }
      
      res.json({ 
        success: true, 
        orderId: order.id,
        message: 'Orden creada exitosamente'
      });
    } catch (error) {
      console.error('Error en webhook de orden:', error);
      res.status(500).json({ 
        error: 'Error al procesar la orden',
        details: error.message 
      });
    }
});

// Endpoint para consultar stock en tiempo real
router.get('/stock/:productId',
  validateN8NApiKey,
  stockLimiter,
  async (req, res) => {
    try {
      const { productId } = req.params;
      const result = await pool.query(
        `SELECT 
          p.id,
          p.name,
          p.stock_quantity,
          p.min_stock_alert,
          p.price,
          c.name as category_name,
          CASE
            WHEN p.stock_quantity = 0 THEN 'out_of_stock'
            WHEN p.stock_quantity <= p.min_stock_alert THEN 'low_stock'
            ELSE 'available'
          END as status
        FROM products p
        LEFT JOIN categories c ON p.category_id = c.id
        WHERE p.id = $1`,
        [productId]
      );
      
      if (result.rows.length === 0) {
        return res.status(404).json({ error: 'Producto no encontrado' });
      }
      
      res.json(result.rows[0]);
    } catch (error) {
      console.error('Error al consultar stock:', error);
      res.status(500).json({ error: error.message });
    }
});

// Endpoint para sincronización de inventario
router.post('/sync/inventory',
  validateN8NApiKey,
  sanitizeInput,
  validateSyncData,
  async (req, res) => {
    try {
      const { items } = req.body;
      
      const results = [];
      for (const item of items) {
        const { productId, quantity, operation } = item;
        
        try {
          let query;
          let params;
          
          switch (operation) {
            case 'add':
              query = 'UPDATE products SET stock_quantity = stock_quantity + $1 WHERE id = $2 RETURNING *';
              params = [quantity, productId];
              break;
            case 'subtract':
              query = 'UPDATE products SET stock_quantity = GREATEST(0, stock_quantity - $1) WHERE id = $2 RETURNING *';
              params = [quantity, productId];
              break;
            case 'set':
              query = 'UPDATE products SET stock_quantity = $1 WHERE id = $2 RETURNING *';
              params = [quantity, productId];
              break;
          }
          
          const result = await pool.query(query, params);
          
          if (result.rows.length === 0) {
            results.push({
              productId,
              success: false,
              error: 'Producto no encontrado'
            });
          } else {
            const product = result.rows[0];
            
            // Verificar si se debe enviar alerta de stock bajo
            if (product.stock_quantity <= product.min_stock_alert) {
              sendStockAlert({
                productId: product.id,
                productName: product.name,
                currentStock: product.stock_quantity,
                minStock: product.min_stock_alert
              });
            }
            
            results.push({
              productId,
              success: true,
              newStock: product.stock_quantity
            });
          }
        } catch (error) {
          results.push({
            productId,
            success: false,
            error: error.message
          });
        }
      }
      
      res.json({
        success: true,
        results
      });
    } catch (error) {
      console.error('Error en sincronización de inventario:', error);
      res.status(500).json({ error: error.message });
    }
});

// Función auxiliar para validar stock
async function validateStockAvailability(items) {
  const details = [];
  let valid = true;
  
  for (const item of items) {
    const result = await pool.query(
      'SELECT name, stock_quantity FROM products WHERE id = $1',
      [item.productId]
    );
    
    if (result.rows.length === 0) {
      details.push({
        productId: item.productId,
        error: 'Producto no encontrado'
      });
      valid = false;
      continue;
    }
    
    const product = result.rows[0];
    if (product.stock_quantity < item.quantity) {
      details.push({
        productId: item.productId,
        productName: product.name,
        requested: item.quantity,
        available: product.stock_quantity
      });
      valid = false;
    }
  }
  
  return { valid, details };
}

export default router; 