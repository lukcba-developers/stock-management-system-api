import rateLimit from 'express-rate-limit';
import { body, validationResult } from 'express-validator';

// Middleware para validación de API keys de N8N
export const validateN8NApiKey = (req, res, next) => {
  const apiKey = req.headers['x-api-key'];
  
  if (!apiKey || apiKey !== process.env.N8N_API_KEY) {
    return res.status(401).json({ error: 'API key inválida' });
  }
  
  next();
};

// Rate limiting específico para webhooks
export const webhookLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minuto
  max: 100, // máximo 100 requests por minuto
  message: 'Demasiadas peticiones desde este webhook',
});

// Rate limiting para endpoints de stock
export const stockLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutos
  max: 300, // máximo 300 requests por 5 minutos
  message: 'Demasiadas consultas de stock',
});

// Validación de datos de sincronización
export const validateSyncData = [
  body('items').isArray().withMessage('Los items deben ser un array'),
  body('items.*.productId').isInt().withMessage('ID de producto inválido'),
  body('items.*.quantity').isInt({ min: 0 }).withMessage('Cantidad inválida'),
  body('items.*.operation').isIn(['add', 'subtract', 'set']).withMessage('Operación inválida'),
  
  (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Datos de sincronización inválidos',
        details: errors.array()
      });
    }
    next();
  }
];

// Middleware para sanitización de datos
export const sanitizeInput = (req, res, next) => {
  if (req.body) {
    // Sanitizar strings
    Object.keys(req.body).forEach(key => {
      if (typeof req.body[key] === 'string') {
        req.body[key] = req.body[key].trim();
      }
    });
    
    // Sanitizar arrays de items
    if (Array.isArray(req.body.items)) {
      req.body.items = req.body.items.map(item => ({
        ...item,
        productId: parseInt(item.productId),
        quantity: parseInt(item.quantity)
      }));
    }
  }
  next();
}; 