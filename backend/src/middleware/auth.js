import jwt from 'jsonwebtoken';
import pool from '../config/database.js';

// Middleware de autenticación
export const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Token no proporcionado' });
  }

  jwt.verify(token, process.env.JWT_SECRET || 'your_super_secret_jwt_key_123', (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Token inválido' });
    }
    req.user = user;
    next();
  });
};

// Middleware para verificar rol de admin
export const requireAdmin = (req, res, next) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Acceso denegado. Se requiere rol de administrador.' });
  }
  next();
};

// Middleware para verificar rol de editor o admin
export const requireEditorOrAdmin = (req, res, next) => {
  if (req.user.role !== 'admin' && req.user.role !== 'editor') {
    return res.status(403).json({ error: 'Acceso denegado. Se requiere rol de editor o administrador.' });
  }
  next();
};

// Middleware para verificar rol de owner o admin (para gestión de usuarios)
export const requireOwnerOrAdmin = (req, res, next) => {
  if (req.user.role !== 'owner' && req.user.role !== 'admin') {
    return res.status(403).json({ 
      error: 'Acceso denegado. Se requiere rol de propietario o administrador.' 
    });
  }
  next();
};

// Middleware para verificar si el usuario puede ver el recurso (viewer, editor, admin, owner)
export const requireViewerOrAbove = (req, res, next) => {
  const allowedRoles = ['viewer', 'editor', 'admin', 'owner'];
  if (!allowedRoles.includes(req.user.role)) {
    return res.status(403).json({ 
      error: 'Acceso denegado. Se requiere al menos rol de visualizador.' 
    });
  }
  next();
};

// Middleware para verificar que la organización esté activa
export const requireActiveOrganization = async (req, res, next) => {
  try {
    // Si el usuario no tiene organization_id, saltar la validación
    if (!req.user || !req.user.organization_id) {
      return next();
    }

    // Verificar que la organización esté activa
    const orgQuery = `
      SELECT subscription_status, is_active 
      FROM saas.organizations 
      WHERE id = $1
    `;
    
    const result = await pool.query(orgQuery, [req.user.organization_id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ 
        error: 'Organización no encontrada',
        code: 'ORGANIZATION_NOT_FOUND'
      });
    }
    
    const org = result.rows[0];
    
    // Verificar que la organización no esté suspendida o inactiva
    if (org.subscription_status === 'suspended' || org.is_active === false) {
      return res.status(403).json({ 
        error: 'La organización está suspendida o inactiva',
        code: 'ORGANIZATION_SUSPENDED'
      });
    }
    
    next();
  } catch (error) {
    console.error('Error verificando estado de organización:', error);
    // En caso de error, permitir continuar para no bloquear el sistema
    next();
  }
};

export default {
  authenticateToken,
  requireAdmin,
  requireEditorOrAdmin,
  requireActiveOrganization
}; 