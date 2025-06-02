import { body, validationResult } from 'express-validator';

export const validateOrder = [
  // Validar teléfono del cliente
  body('customerPhone')
    .notEmpty()
    .withMessage('El teléfono del cliente es requerido')
    .matches(/^\+?[1-9]\d{1,14}$/)
    .withMessage('Formato de teléfono inválido'),

  // Validar items
  body('items')
    .isArray()
    .withMessage('Los items deben ser un array')
    .notEmpty()
    .withMessage('La orden debe contener al menos un item'),

  // Validar cada item
  body('items.*.productId')
    .isInt()
    .withMessage('ID de producto inválido'),

  body('items.*.quantity')
    .isInt({ min: 1 })
    .withMessage('La cantidad debe ser un número positivo'),

  // Validar dirección de entrega
  body('deliveryAddress')
    .optional()
    .isObject()
    .withMessage('La dirección de entrega debe ser un objeto'),

  body('deliveryAddress.street')
    .optional()
    .isString()
    .withMessage('La calle debe ser una cadena de texto'),

  body('deliveryAddress.number')
    .optional()
    .isString()
    .withMessage('El número debe ser una cadena de texto'),

  body('deliveryAddress.city')
    .optional()
    .isString()
    .withMessage('La ciudad debe ser una cadena de texto'),

  body('deliveryAddress.state')
    .optional()
    .isString()
    .withMessage('El estado debe ser una cadena de texto'),

  body('deliveryAddress.zipCode')
    .optional()
    .isString()
    .withMessage('El código postal debe ser una cadena de texto'),

  // Middleware para procesar los resultados de la validación
  (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        error: 'Datos de orden inválidos',
        details: errors.array()
      });
    }
    next();
  }
]; 