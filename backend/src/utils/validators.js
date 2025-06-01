import { body, param, query, validationResult } from 'express-validator';

export const handleValidationErrors = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ 
      error: 'Datos de entrada inválidos',
      details: errors.array() 
    });
  }
  next();
};

export const productValidators = {
  create: [
    body('name').trim().notEmpty().withMessage('El nombre es requerido'),
    body('price').isFloat({ min: 0 }).withMessage('El precio debe ser un número positivo'),
    body('category_id').isInt({ min: 1 }).withMessage('La categoría es requerida'),
    body('stock_quantity').isInt({ min: 0 }).withMessage('El stock debe ser un número entero positivo'),
    body('min_stock_alert').optional().isInt({ min: 0 }).withMessage('El stock mínimo debe ser un número entero positivo'),
    body('barcode').optional().trim().isLength({ min: 8, max: 20 }).withMessage('El código de barras debe tener entre 8 y 20 caracteres'),
    handleValidationErrors
  ],
  
  update: [
    param('id').isInt({ min: 1 }).withMessage('ID de producto inválido'),
    body('name').optional().trim().notEmpty().withMessage('El nombre no puede estar vacío'),
    body('price').optional().isFloat({ min: 0 }).withMessage('El precio debe ser un número positivo'),
    body('category_id').optional().isInt({ min: 1 }).withMessage('La categoría debe ser válida'),
    body('min_stock_alert').optional().isInt({ min: 0 }).withMessage('El stock mínimo debe ser un número entero positivo'),
    handleValidationErrors
  ],
  
  updateStock: [
    param('id').isInt({ min: 1 }).withMessage('ID de producto inválido'),
    body('stock_quantity').isInt({ min: 0 }).withMessage('La cantidad debe ser un número entero positivo'),
    body('reason').optional().trim().notEmpty().withMessage('La razón no puede estar vacía'),
    handleValidationErrors
  ],
  
  getProducts: [
    query('page').optional().isInt({ min: 1 }).withMessage('La página debe ser un número positivo'),
    query('limit').optional().isInt({ min: 1, max: 100 }).withMessage('El límite debe estar entre 1 y 100'),
    query('category').optional().isInt({ min: 1 }).withMessage('ID de categoría inválido'),
    query('sortBy').optional().isIn(['name', 'price', 'stock_quantity', 'created_at', 'popularity_score']).withMessage('Campo de ordenamiento inválido'),
    query('sortOrder').optional().isIn(['ASC', 'DESC', 'asc', 'desc']).withMessage('Orden debe ser ASC o DESC'),
    handleValidationErrors
  ]
}; 