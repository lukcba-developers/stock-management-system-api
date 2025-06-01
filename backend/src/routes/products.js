import express from 'express';
import { authenticateToken, requireAdmin, requireEditorOrAdmin } from '../middleware/auth.js';
import * as productController from '../controllers/productController.js';
import upload from '../config/multer.js';

const router = express.Router();

// Rutas públicas (requieren autenticación pero no rol específico)
router.get('/', authenticateToken, productController.getProducts);
router.get('/:id', authenticateToken, productController.getProductById);

// Rutas de editor o admin
router.post('/', authenticateToken, requireEditorOrAdmin, upload.single('image'), productController.createProduct);
router.put('/:id', authenticateToken, requireEditorOrAdmin, upload.single('image'), productController.updateProduct);
router.patch('/:id/stock', authenticateToken, requireEditorOrAdmin, productController.updateStock);

// Rutas solo admin
router.delete('/:id', authenticateToken, requireAdmin, productController.deleteProduct);

// Nueva ruta para historial de movimientos
router.get('/:id/movements', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { limit = 20, offset = 0 } = req.query;
    
    const query = `
      SELECT 
        sm.*,
        u.name as user_name,
        u.email as user_email
      FROM stock_movements sm
      LEFT JOIN admin_users u ON sm.user_id = u.id
      WHERE sm.product_id = $1
      ORDER BY sm.created_at DESC
      LIMIT $2 OFFSET $3
    `;
    
    const result = await pool.query(query, [id, limit, offset]);
    
    res.json({
      success: true,
      data: result.rows
    });
  } catch (error) {
    console.error('Error obteniendo movimientos:', error);
    res.status(500).json({ error: 'Error al obtener movimientos de stock' });
  }
});

export default router; 