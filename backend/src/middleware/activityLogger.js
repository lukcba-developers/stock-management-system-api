import pool from '../config/database.js';

export const logActivity = async (userId, action, entityType, entityId, details, ipAddress, userAgent) => {
  try {
    await pool.query(
      `INSERT INTO activity_logs (
        user_id, 
        action, 
        entity_type, 
        entity_id, 
        entity_name, 
        changes, 
        ip_address, 
        user_agent
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        userId,
        action,
        entityType,
        entityId,
        details?.name,
        details,
        ipAddress,
        userAgent
      ]
    );
  } catch (error) {
    console.error('Error logging activity:', error);
  }
};

// Middleware para registrar actividad
export const activityLogger = (action, entityType) => {
  return async (req, res, next) => {
    const originalJson = res.json;
    res.json = function(data) {
      if (data.success) {
        const entityId = req.params.id || data.data?.id;
        logActivity(
          req.user.id,
          action,
          entityType,
          entityId,
          data.data,
          req.ip,
          req.headers['user-agent']
        );
      }
      return originalJson.call(this, data);
    };
    next();
  };
}; 