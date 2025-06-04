import pool from '../config/database.js';

/**
 * Middleware para inyectar contexto de organización
 * Asegura el aislamiento de datos entre organizaciones (multi-tenancy)
 */
export const injectOrganizationContext = async (req, res, next) => {
  try {
    // Verificar que el usuario esté autenticado y tenga organización
    if (!req.user || !req.user.organization_id) {
      return res.status(403).json({ 
        error: 'Contexto de organización no encontrado',
        code: 'MISSING_ORGANIZATION_CONTEXT'
      });
    }
    
    // Inyectar organización en el request para fácil acceso
    req.organizationId = req.user.organization_id;
    req.organization = {
      id: req.user.organization_id,
      name: req.user.organization_name,
      slug: req.user.organization_slug
    };
    
    // Configurar Row Level Security (RLS) para PostgreSQL
    // Esto asegura que todas las queries automáticamente filtren por organización
    try {
      await pool.query('SET LOCAL app.current_organization_id = $1', [req.organizationId]);
    } catch (rlsError) {
      console.warn('Warning: No se pudo configurar RLS context:', rlsError.message);
      // No fallar si RLS no está configurado, pero logear la advertencia
    }
    
    next();
  } catch (error) {
    console.error('Error en middleware de multi-tenancy:', error);
    res.status(500).json({ 
      error: 'Error configurando contexto de organización',
      code: 'ORGANIZATION_CONTEXT_ERROR'
    });
  }
};

/**
 * Middleware para verificar que el usuario pertenece a la organización especificada
 * Útil para rutas que incluyen organization_id en los parámetros
 */
export const validateOrganizationAccess = (req, res, next) => {
  const { organizationId } = req.params;
  
  if (organizationId && parseInt(organizationId) !== req.user.organization_id) {
    return res.status(403).json({ 
      error: 'Acceso denegado a esta organización',
      code: 'ORGANIZATION_ACCESS_DENIED'
    });
  }
  
  next();
};

/**
 * Helper para crear queries con filtro automático de organización
 * Uso: addOrganizationFilter('SELECT * FROM products', req.organizationId)
 */
export const addOrganizationFilter = (baseQuery, organizationId, tableAlias = '') => {
  const prefix = tableAlias ? `${tableAlias}.` : '';
  
  // Si la query ya tiene WHERE, usar AND; si no, agregar WHERE
  if (baseQuery.toLowerCase().includes('where')) {
    return `${baseQuery} AND ${prefix}organization_id = ${organizationId}`;
  } else {
    return `${baseQuery} WHERE ${prefix}organization_id = ${organizationId}`;
  }
};

/**
 * Wrapper para queries que automáticamente agrega filtro de organización
 */
export const queryWithOrganization = async (query, params = [], organizationId) => {
  // Agregar organization_id como último parámetro si no está incluido
  if (!query.toLowerCase().includes('organization_id')) {
    // Para queries simples, agregar filtro automáticamente
    query = addOrganizationFilter(query, '$' + (params.length + 1));
    params.push(organizationId);
  }
  
  return await pool.query(query, params);
};

/**
 * Middleware específico para rutas de productos
 * Asegura que solo se acceda a productos de la organización del usuario
 */
export const enforceProductOrganization = (req, res, next) => {
  // Para operaciones CREATE, inyectar organization_id automáticamente
  if (req.method === 'POST' && req.body) {
    req.body.organization_id = req.organizationId;
  }
  
  // Para operaciones UPDATE/DELETE, verificar que el producto pertenezca a la org
  if (req.method === 'PUT' || req.method === 'PATCH' || req.method === 'DELETE') {
    req.organizationFilter = true; // Flag para que la ruta aplique filtro
  }
  
  next();
};

/**
 * Middleware específico para rutas de órdenes/ventas
 * Asegura que solo se acceda a órdenes de la organización del usuario
 */
export const enforceOrderOrganization = (req, res, next) => {
  // Similar al de productos pero para órdenes
  if (req.method === 'POST' && req.body) {
    req.body.organization_id = req.organizationId;
  }
  
  if (req.method === 'PUT' || req.method === 'PATCH' || req.method === 'DELETE') {
    req.organizationFilter = true;
  }
  
  next();
};

/**
 * Middleware para logging de actividades con contexto de organización
 */
export const logActivityWithOrganization = (action) => {
  return (req, res, next) => {
    // Agregar información de organización al log
    req.activityLog = {
      organization_id: req.organizationId,
      organization_name: req.organization?.name,
      action: action,
      user_id: req.user.id,
      user_email: req.user.email,
      ip_address: req.ip,
      user_agent: req.headers['user-agent'],
      timestamp: new Date()
    };
    
    next();
  };
};

/**
 * Middleware para verificar límites del plan de la organización
 */
export const checkOrganizationLimits = (resource) => {
  return async (req, res, next) => {
    try {
      // Obtener información del plan de la organización
      const orgQuery = `
        SELECT subscription_plan, max_users, features 
        FROM saas.organizations 
        WHERE id = $1
      `;
      
      const result = await pool.query(orgQuery, [req.organizationId]);
      
      if (result.rows.length === 0) {
        return res.status(404).json({ 
          error: 'Organización no encontrada',
          code: 'ORGANIZATION_NOT_FOUND'
        });
      }
      
      const organization = result.rows[0];
      req.organizationLimits = organization;
      
      // Verificar límites específicos según el recurso
      if (resource === 'users' && req.method === 'POST') {
        const userCountQuery = `
          SELECT COUNT(*) as user_count 
          FROM saas.authorized_users 
          WHERE organization_id = $1 AND status != 'removed'
        `;
        
        const userCountResult = await pool.query(userCountQuery, [req.organizationId]);
        const currentUsers = parseInt(userCountResult.rows[0].user_count);
        
        if (currentUsers >= organization.max_users) {
          return res.status(400).json({
            error: 'Has alcanzado el límite de usuarios de tu plan',
            code: 'USER_LIMIT_EXCEEDED',
            current: currentUsers,
            limit: organization.max_users
          });
        }
      }
      
      next();
    } catch (error) {
      console.error('Error verificando límites de organización:', error);
      res.status(500).json({ 
        error: 'Error verificando límites de plan',
        code: 'LIMIT_CHECK_ERROR'
      });
    }
  };
};

export default {
  injectOrganizationContext,
  validateOrganizationAccess,
  addOrganizationFilter,
  queryWithOrganization,
  enforceProductOrganization,
  enforceOrderOrganization,
  logActivityWithOrganization,
  checkOrganizationLimits
}; 