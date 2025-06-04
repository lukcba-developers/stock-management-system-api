import express from 'express';
import { authenticateToken, requireOwnerOrAdmin, requireActiveOrganization } from '../middleware/auth.js';
import { sendInvitationEmail, sendRoleChangeEmail } from '../services/emailService.js';
import pool from '../config/database.js';
import crypto from 'crypto';

const router = express.Router();

// Aplicar middlewares a todas las rutas de admin
router.use(authenticateToken);
router.use(requireActiveOrganization);

// Obtener todos los usuarios de la organización
router.get('/users', requireOwnerOrAdmin, async (req, res) => {
  try {
    const { search, role, status, sortBy = 'created_at', sortOrder = 'DESC' } = req.query;
    
    let query = `
      SELECT 
        au.*,
        au.role,
        au.status,
        au.last_login,
        au.login_count,
        CASE WHEN au.google_id IS NOT NULL THEN true ELSE false END as has_logged_in
      FROM saas.authorized_users au
      WHERE au.organization_id = $1
    `;
    
    const params = [req.user.organization_id];
    let paramCount = 1;
    
    // Filtro de búsqueda
    if (search) {
      paramCount++;
      query += ` AND (au.name ILIKE $${paramCount} OR au.email ILIKE $${paramCount})`;
      params.push(`%${search}%`);
    }
    
    // Filtro por rol
    if (role) {
      paramCount++;
      query += ` AND au.role = $${paramCount}`;
      params.push(role);
    }
    
    // Filtro por estado
    if (status) {
      paramCount++;
      query += ` AND au.status = $${paramCount}`;
      params.push(status);
    }
    
    // Ordenamiento
    const allowedSortFields = ['name', 'email', 'role', 'status', 'created_at', 'last_login'];
    const allowedSortOrders = ['ASC', 'DESC'];
    
    if (allowedSortFields.includes(sortBy) && allowedSortOrders.includes(sortOrder.toUpperCase())) {
      query += ` ORDER BY au.${sortBy} ${sortOrder.toUpperCase()}`;
    } else {
      query += ` ORDER BY au.created_at DESC`;
    }
    
    const result = await pool.query(query, params);
    
    res.json({
      success: true,
      users: result.rows
    });
  } catch (error) {
    console.error('Error al obtener usuarios:', error);
    res.status(500).json({ error: 'Error al obtener usuarios' });
  }
});

// Invitar nuevo usuario
router.post('/users/invite', requireOwnerOrAdmin, async (req, res) => {
  const { email, role = 'viewer' } = req.body;
  
  try {
    // Validar email
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ error: 'Email inválido' });
    }
    
    // Validar rol
    const allowedRoles = ['viewer', 'editor', 'admin', 'owner'];
    if (!allowedRoles.includes(role)) {
      return res.status(400).json({ error: 'Rol inválido' });
    }
    
    // Solo owners pueden crear otros owners
    if (role === 'owner' && req.user.role !== 'owner') {
      return res.status(403).json({ error: 'Solo el propietario puede asignar el rol de propietario' });
    }
    
    // Verificar límites del plan
    const countQuery = `
      SELECT COUNT(*) as user_count, o.max_users
      FROM saas.authorized_users au
      JOIN saas.organizations o ON au.organization_id = o.id
      WHERE au.organization_id = $1 AND au.status != 'removed'
      GROUP BY o.max_users
    `;
    
    const countResult = await pool.query(countQuery, [req.user.organization_id]);
    
    if (countResult.rows[0] && countResult.rows[0].user_count >= countResult.rows[0].max_users) {
      return res.status(400).json({ 
        error: 'Has alcanzado el límite de usuarios de tu plan' 
      });
    }
    
    // Generar token de invitación
    const invitationToken = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 días
    
    // Crear usuario autorizado
    const insertQuery = `
      INSERT INTO saas.authorized_users (
        organization_id, email, role, status, 
        invitation_token, invitation_sent_at, invitation_expires_at
      ) VALUES ($1, $2, $3, 'pending', $4, NOW(), $5)
      ON CONFLICT (organization_id, email) 
      DO UPDATE SET 
        role = EXCLUDED.role,
        invitation_token = EXCLUDED.invitation_token,
        invitation_sent_at = EXCLUDED.invitation_sent_at,
        invitation_expires_at = EXCLUDED.invitation_expires_at,
        status = CASE 
          WHEN saas.authorized_users.status = 'removed' THEN 'pending'
          ELSE saas.authorized_users.status
        END
      RETURNING *
    `;
    
    const result = await pool.query(insertQuery, [
      req.user.organization_id,
      email,
      role,
      invitationToken,
      expiresAt
    ]);
    
    // Enviar email de invitación
    try {
      await sendInvitationEmail({
        to: email,
        inviterName: req.user.name,
        organizationName: req.user.organization_name,
        invitationLink: `${process.env.FRONTEND_URL}/accept-invitation?token=${invitationToken}`,
        role: role
      });
    } catch (emailError) {
      console.error('Error enviando email de invitación:', emailError);
      // No fallar la invitación si el email falla, pero log el error
    }
    
    res.json({
      success: true,
      message: 'Invitación enviada correctamente',
      user: result.rows[0]
    });
    
  } catch (error) {
    console.error('Error al invitar usuario:', error);
    if (error.code === '23505') { // Unique violation
      res.status(400).json({ error: 'El usuario ya tiene una invitación pendiente' });
    } else {
      res.status(500).json({ error: 'Error al invitar usuario' });
    }
  }
});

// Actualizar rol de usuario
router.patch('/users/:userId/role', requireOwnerOrAdmin, async (req, res) => {
  const { userId } = req.params;
  const { role } = req.body;
  
  try {
    // Validar rol
    const allowedRoles = ['viewer', 'editor', 'admin', 'owner'];
    if (!allowedRoles.includes(role)) {
      return res.status(400).json({ error: 'Rol inválido' });
    }
    
    // Solo owners pueden asignar/cambiar roles de owner
    if (role === 'owner' && req.user.role !== 'owner') {
      return res.status(403).json({ error: 'Solo el propietario puede asignar el rol de propietario' });
    }
    
    // Verificar que el usuario existe y pertenece a la organización
    const checkQuery = `
      SELECT * FROM saas.authorized_users 
      WHERE id = $1 AND organization_id = $2
    `;
    
    const checkResult = await pool.query(checkQuery, [userId, req.user.organization_id]);
    
    if (checkResult.rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    
    const userToUpdate = checkResult.rows[0];
    
    // No permitir cambiar el rol del owner principal (excepto el mismo owner)
    if (userToUpdate.role === 'owner' && req.user.id !== parseInt(userId)) {
      return res.status(400).json({ 
        error: 'No se puede cambiar el rol del propietario principal' 
      });
    }
    
    // No permitir que un usuario cambie su propio rol
    if (req.user.id === parseInt(userId)) {
      return res.status(400).json({ 
        error: 'No puedes cambiar tu propio rol' 
      });
    }
    
    const updateQuery = `
      UPDATE saas.authorized_users 
      SET role = $1, updated_at = NOW()
      WHERE id = $2 AND organization_id = $3
      RETURNING *
    `;
    
    const result = await pool.query(updateQuery, [role, userId, req.user.organization_id]);
    
    // Enviar email de notificación (opcional)
    try {
      if (userToUpdate.email && userToUpdate.status === 'active') {
        await sendRoleChangeEmail({
          to: userToUpdate.email,
          userName: userToUpdate.name || userToUpdate.email,
          newRole: role,
          organizationName: req.user.organization_name,
          changedBy: req.user.name
        });
      }
    } catch (emailError) {
      console.error('Error enviando email de cambio de rol:', emailError);
    }
    
    res.json({
      success: true,
      user: result.rows[0]
    });
    
  } catch (error) {
    console.error('Error al actualizar rol:', error);
    res.status(500).json({ error: 'Error al actualizar rol' });
  }
});

// Cambiar estado de usuario
router.patch('/users/:userId/status', requireOwnerOrAdmin, async (req, res) => {
  const { userId } = req.params;
  const { status } = req.body;
  
  try {
    // Validar estado
    const allowedStatuses = ['active', 'suspended', 'pending'];
    if (!allowedStatuses.includes(status)) {
      return res.status(400).json({ error: 'Estado inválido' });
    }
    
    // Verificar que el usuario existe y pertenece a la organización
    const checkQuery = `
      SELECT * FROM saas.authorized_users 
      WHERE id = $1 AND organization_id = $2
    `;
    
    const checkResult = await pool.query(checkQuery, [userId, req.user.organization_id]);
    
    if (checkResult.rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    
    const userToUpdate = checkResult.rows[0];
    
    // No permitir suspender al owner principal (excepto el mismo owner)
    if (userToUpdate.role === 'owner' && req.user.id !== parseInt(userId) && status === 'suspended') {
      return res.status(400).json({ 
        error: 'No se puede suspender al propietario principal' 
      });
    }
    
    // No permitir que un usuario cambie su propio estado
    if (req.user.id === parseInt(userId)) {
      return res.status(400).json({ 
        error: 'No puedes cambiar tu propio estado' 
      });
    }
    
    const updateQuery = `
      UPDATE saas.authorized_users 
      SET status = $1, updated_at = NOW()
      WHERE id = $2 AND organization_id = $3
      RETURNING *
    `;
    
    const result = await pool.query(updateQuery, [status, userId, req.user.organization_id]);
    
    res.json({
      success: true,
      user: result.rows[0]
    });
    
  } catch (error) {
    console.error('Error al cambiar estado:', error);
    res.status(500).json({ error: 'Error al cambiar estado del usuario' });
  }
});

// Eliminar usuario
router.delete('/users/:userId', requireOwnerOrAdmin, async (req, res) => {
  const { userId } = req.params;
  
  try {
    // Verificar que el usuario existe y pertenece a la organización
    const checkQuery = `
      SELECT * FROM saas.authorized_users 
      WHERE id = $1 AND organization_id = $2
    `;
    
    const checkResult = await pool.query(checkQuery, [userId, req.user.organization_id]);
    
    if (checkResult.rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }
    
    const userToDelete = checkResult.rows[0];
    
    // No permitir eliminar al owner principal
    if (userToDelete.role === 'owner') {
      return res.status(400).json({ 
        error: 'No se puede eliminar al propietario principal' 
      });
    }
    
    // No permitir que un usuario se elimine a sí mismo
    if (req.user.id === parseInt(userId)) {
      return res.status(400).json({ 
        error: 'No puedes eliminarte a ti mismo' 
      });
    }
    
    // Marcar como removido en lugar de eliminar
    const updateQuery = `
      UPDATE saas.authorized_users 
      SET status = 'removed', updated_at = NOW()
      WHERE id = $1 AND organization_id = $2
      RETURNING *
    `;
    
    const result = await pool.query(updateQuery, [userId, req.user.organization_id]);
    
    res.json({
      success: true,
      message: 'Usuario eliminado correctamente'
    });
    
  } catch (error) {
    console.error('Error al eliminar usuario:', error);
    res.status(500).json({ error: 'Error al eliminar usuario' });
  }
});

// Reenviar invitación
router.post('/users/:userId/resend-invitation', requireOwnerOrAdmin, async (req, res) => {
  const { userId } = req.params;
  
  try {
    // Verificar que el usuario existe, pertenece a la organización y está pendiente
    const checkQuery = `
      SELECT * FROM saas.authorized_users 
      WHERE id = $1 AND organization_id = $2 AND status = 'pending'
    `;
    
    const checkResult = await pool.query(checkQuery, [userId, req.user.organization_id]);
    
    if (checkResult.rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado o no tiene invitación pendiente' });
    }
    
    const user = checkResult.rows[0];
    
    // Generar nuevo token de invitación
    const invitationToken = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 días
    
    // Actualizar token
    const updateQuery = `
      UPDATE saas.authorized_users 
      SET 
        invitation_token = $1, 
        invitation_sent_at = NOW(), 
        invitation_expires_at = $2,
        updated_at = NOW()
      WHERE id = $3
      RETURNING *
    `;
    
    const result = await pool.query(updateQuery, [invitationToken, expiresAt, userId]);
    
    // Enviar email de invitación
    try {
      await sendInvitationEmail({
        to: user.email,
        inviterName: req.user.name,
        organizationName: req.user.organization_name,
        invitationLink: `${process.env.FRONTEND_URL}/accept-invitation?token=${invitationToken}`,
        role: user.role
      });
    } catch (emailError) {
      console.error('Error enviando email de invitación:', emailError);
      return res.status(500).json({ error: 'Error al enviar el email de invitación' });
    }
    
    res.json({
      success: true,
      message: 'Invitación reenviada correctamente'
    });
    
  } catch (error) {
    console.error('Error al reenviar invitación:', error);
    res.status(500).json({ error: 'Error al reenviar invitación' });
  }
});

// Obtener estadísticas de usuarios
router.get('/users/stats', requireOwnerOrAdmin, async (req, res) => {
  try {
    const statsQuery = `
      SELECT 
        COUNT(*) as total_users,
        COUNT(*) FILTER (WHERE status = 'active') as active_users,
        COUNT(*) FILTER (WHERE status = 'pending') as pending_users,
        COUNT(*) FILTER (WHERE status = 'suspended') as suspended_users,
        COUNT(*) FILTER (WHERE role = 'admin') as admin_users,
        COUNT(*) FILTER (WHERE role = 'editor') as editor_users,
        COUNT(*) FILTER (WHERE role = 'viewer') as viewer_users,
        COUNT(*) FILTER (WHERE role = 'owner') as owner_users,
        COUNT(*) FILTER (WHERE last_login > NOW() - INTERVAL '30 days') as active_last_month,
        o.max_users
      FROM saas.authorized_users au
      JOIN saas.organizations o ON au.organization_id = o.id
      WHERE au.organization_id = $1 AND au.status != 'removed'
      GROUP BY o.max_users
    `;
    
    const result = await pool.query(statsQuery, [req.user.organization_id]);
    
    const stats = result.rows[0] || {
      total_users: 0,
      active_users: 0,
      pending_users: 0,
      suspended_users: 0,
      admin_users: 0,
      editor_users: 0,
      viewer_users: 0,
      owner_users: 0,
      active_last_month: 0,
      max_users: 0
    };
    
    res.json({
      success: true,
      stats
    });
    
  } catch (error) {
    console.error('Error al obtener estadísticas:', error);
    res.status(500).json({ error: 'Error al obtener estadísticas' });
  }
});

export default router; 