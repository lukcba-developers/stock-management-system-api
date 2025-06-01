import jwt from 'jsonwebtoken';
import pool from '../config/database.js';

// Middleware de autenticación
export const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Token no proporcionado' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    // Verificar si el usuario sigue activo o si su rol ha cambiado
    const userQuery = await pool.query('SELECT id, email, role, is_active FROM admin_users WHERE id = $1', [decoded.id]);
    if (userQuery.rows.length === 0 || !userQuery.rows[0].is_active) {
      return res.status(403).json({ error: 'Usuario no válido o inactivo.' });
    }
    req.user = userQuery.rows[0]; // Usar datos frescos de la BD
    next();
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      return res.status(401).json({ error: 'Token expirado' });
    }
    return res.status(403).json({ error: 'Token inválido' });
  }
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