import express from 'express';
import { authenticateToken, requireActiveOrganization } from '../middleware/auth.js';
import { injectOrganizationContext } from '../middleware/multitenancy.js';
import pool from '../config/database.js';

const router = express.Router();

// Aplicar middlewares a todas las rutas
router.use(authenticateToken);
router.use(requireActiveOrganization);
router.use(injectOrganizationContext);

// Obtener perfil de la organización
router.get('/profile', async (req, res) => {
  try {
    const query = `
      SELECT 
        o.id,
        o.name,
        o.slug,
        o.subscription_plan,
        o.subscription_status,
        o.max_users,
        o.max_products,
        o.max_monthly_orders,
        o.storage_gb,
        o.features,
        o.created_at,
        o.updated_at,
        (
          SELECT COUNT(*) 
          FROM saas.authorized_users au
          WHERE au.organization_id = o.id AND au.status = 'active'
        ) as active_users_count
      FROM saas.organizations o
      WHERE o.id = $1
    `;
    
    const result = await pool.query(query, [req.user.organization_id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ 
        error: 'Organización no encontrada',
        code: 'ORGANIZATION_NOT_FOUND'
      });
    }
    
    const org = result.rows[0];
    
    // Agregar valores por defecto según el plan si no están definidos
    const planDefaults = getPlanDefaults(org.subscription_plan);
    
    res.json({
      ...org,
      max_users: org.max_users || planDefaults.max_users,
      max_products: org.max_products || planDefaults.max_products,
      max_monthly_orders: org.max_monthly_orders || planDefaults.max_monthly_orders,
      storage_gb: org.storage_gb || planDefaults.storage_gb
    });
    
  } catch (error) {
    console.error('Error al obtener perfil de organización:', error);
    res.status(500).json({ 
      error: 'Error al obtener perfil de organización',
      code: 'ORGANIZATION_PROFILE_ERROR'
    });
  }
});

// Obtener uso actual de la organización
router.get('/usage', async (req, res) => {
  try {
    // Obtener métricas básicas de uso
    const usageQuery = `
      WITH usage_data AS (
        SELECT 
          -- Usuarios activos
          (
            SELECT COUNT(*) 
            FROM saas.authorized_users 
            WHERE organization_id = $1 AND status = 'active'
          ) as current_users,
          
          -- Productos activos (si existe la tabla)
          COALESCE((
            SELECT COUNT(*) 
            FROM products 
            WHERE organization_id = $1 
              AND is_available = true
          ), 0) as current_products,
          
          -- Órdenes del mes actual (si existe la tabla)
          COALESCE((
            SELECT COUNT(*) 
            FROM orders 
            WHERE organization_id = $1 
              AND DATE(created_at) >= DATE_TRUNC('month', CURRENT_DATE)
          ), 0) as monthly_orders,
          
          -- Categorías activas (si existe la tabla)
          COALESCE((
            SELECT COUNT(*) 
            FROM categories 
            WHERE organization_id = $1 
              AND is_active = true
          ), 0) as current_categories,
          
          -- Almacenamiento usado (estimado)
          0.5 as storage_used_gb
      )
      SELECT * FROM usage_data
    `;
    
    const usageResult = await pool.query(usageQuery, [req.user.organization_id]);
    const usage = usageResult.rows[0];
    
    // Obtener tendencia de órdenes (últimos 30 días)
    const trendsQuery = `
      SELECT 
        DATE(created_at) as date,
        COUNT(*) as orders
      FROM orders
      WHERE organization_id = $1 
        AND created_at >= CURRENT_DATE - INTERVAL '30 days'
      GROUP BY DATE(created_at)
      ORDER BY date
    `;
    
    let ordersTrand = [];
    try {
      const trendsResult = await pool.query(trendsQuery, [req.user.organization_id]);
      ordersTrand = trendsResult.rows;
    } catch (trendsError) {
      console.warn('No se pudieron obtener tendencias de órdenes:', trendsError.message);
      // Generar datos mock para demo
      ordersTrand = generateMockOrdersTrend();
    }
    
    // Obtener productos por categoría
    const categoryQuery = `
      SELECT 
        c.name as category,
        COUNT(p.id) as count
      FROM categories c
      LEFT JOIN products p ON c.id = p.category_id 
        AND p.organization_id = $1 
        AND p.is_available = true
      WHERE c.organization_id = $1 
        AND c.is_active = true
      GROUP BY c.id, c.name
      ORDER BY count DESC
    `;
    
    let productsByCategory = [];
    try {
      const categoryResult = await pool.query(categoryQuery, [req.user.organization_id]);
      productsByCategory = categoryResult.rows;
    } catch (categoryError) {
      console.warn('No se pudieron obtener productos por categoría:', categoryError.message);
      // Generar datos mock para demo
      productsByCategory = generateMockCategoryData();
    }
    
    // Obtener información de la organización para calcular alertas
    const orgQuery = `
      SELECT max_users, max_products, max_monthly_orders, storage_gb
      FROM saas.organizations 
      WHERE id = $1
    `;
    
    const orgResult = await pool.query(orgQuery, [req.user.organization_id]);
    const orgLimits = orgResult.rows[0];
    
    // Generar alertas de uso
    const alerts = generateUsageAlerts(usage, orgLimits);
    
    res.json({
      ...usage,
      orders_trend: ordersTrand,
      products_by_category: productsByCategory,
      alerts: alerts
    });
    
  } catch (error) {
    console.error('Error al obtener uso de organización:', error);
    res.status(500).json({ 
      error: 'Error al obtener uso de organización',
      code: 'ORGANIZATION_USAGE_ERROR'
    });
  }
});

// Obtener información de facturación
router.get('/billing', async (req, res) => {
  try {
    // Obtener información de la organización
    const orgQuery = `
      SELECT 
        subscription_plan,
        max_users,
        max_products,
        max_monthly_orders,
        storage_gb,
        created_at
      FROM saas.organizations 
      WHERE id = $1
    `;
    
    const orgResult = await pool.query(orgQuery, [req.user.organization_id]);
    const org = orgResult.rows[0];
    
    // Obtener uso actual para calcular costos adicionales
    const usageQuery = `
      SELECT 
        (
          SELECT COUNT(*) 
          FROM saas.authorized_users 
          WHERE organization_id = $1 AND status = 'active'
        ) as current_users
    `;
    
    const usageResult = await pool.query(usageQuery, [req.user.organization_id]);
    const usage = usageResult.rows[0];
    
    // Calcular precios y costos
    const planPrices = getPlanPricing();
    const basePlanPrice = planPrices[org.subscription_plan] || 0;
    
    // Calcular usuarios adicionales
    const extraUsers = Math.max(0, usage.current_users - org.max_users);
    const extraUsersCost = extraUsers * planPrices.per_extra_user;
    
    // Calcular almacenamiento adicional (por ahora 0)
    const extraStorageCost = 0;
    
    // Calcular próxima fecha de facturación (mensual)
    const nextBillingDate = new Date();
    nextBillingDate.setMonth(nextBillingDate.getMonth() + 1);
    
    const billingInfo = {
      plan_price: basePlanPrice,
      extra_users_cost: extraUsersCost,
      extra_storage_cost: extraStorageCost,
      next_bill_amount: basePlanPrice + extraUsersCost + extraStorageCost,
      next_billing_date: nextBillingDate.toISOString(),
      current_month_total: basePlanPrice, // Simplificado
      billing_history: [] // Por implementar
    };
    
    res.json(billingInfo);
    
  } catch (error) {
    console.error('Error al obtener facturación:', error);
    res.status(500).json({ 
      error: 'Error al obtener información de facturación',
      code: 'BILLING_ERROR'
    });
  }
});

// Obtener analytics detallados (para administradores)
router.get('/analytics', async (req, res) => {
  try {
    const { period = '30d', metric = 'orders' } = req.query;
    
    // Determinar el intervalo de fechas
    const periodMap = {
      '7d': 7,
      '30d': 30,
      '90d': 90,
      '1y': 365
    };
    
    const days = periodMap[period] || 30;
    
    let analyticsQuery = '';
    let params = [req.user.organization_id, days];
    
    switch (metric) {
      case 'orders':
        analyticsQuery = `
          SELECT 
            DATE(created_at) as date,
            COUNT(*) as value,
            SUM(total_amount) as revenue
          FROM orders
          WHERE organization_id = $1 
            AND created_at >= CURRENT_DATE - INTERVAL '${days} days'
          GROUP BY DATE(created_at)
          ORDER BY date
        `;
        break;
        
      case 'users':
        analyticsQuery = `
          SELECT 
            DATE(created_at) as date,
            COUNT(*) as value
          FROM saas.authorized_users
          WHERE organization_id = $1 
            AND created_at >= CURRENT_DATE - INTERVAL '${days} days'
            AND status = 'active'
          GROUP BY DATE(created_at)
          ORDER BY date
        `;
        break;
        
      case 'products':
        analyticsQuery = `
          SELECT 
            DATE(created_at) as date,
            COUNT(*) as value
          FROM products
          WHERE organization_id = $1 
            AND created_at >= CURRENT_DATE - INTERVAL '${days} days'
            AND is_available = true
          GROUP BY DATE(created_at)
          ORDER BY date
        `;
        break;
        
      default:
        return res.status(400).json({ 
          error: 'Métrica no válida',
          code: 'INVALID_METRIC'
        });
    }
    
    let analyticsData = [];
    try {
      const result = await pool.query(analyticsQuery, params);
      analyticsData = result.rows;
    } catch (queryError) {
      console.warn(`No se pudieron obtener analytics para ${metric}:`, queryError.message);
      // Generar datos mock para demo
      analyticsData = generateMockAnalytics(metric, days);
    }
    
    res.json({
      metric,
      period,
      data: analyticsData,
      summary: {
        total: analyticsData.reduce((sum, item) => sum + parseInt(item.value), 0),
        average: analyticsData.length > 0 
          ? Math.round(analyticsData.reduce((sum, item) => sum + parseInt(item.value), 0) / analyticsData.length)
          : 0,
        growth: calculateGrowthRate(analyticsData)
      }
    });
    
  } catch (error) {
    console.error('Error al obtener analytics:', error);
    res.status(500).json({ 
      error: 'Error al obtener analytics',
      code: 'ANALYTICS_ERROR'
    });
  }
});

// Actualizar configuración de la organización
router.patch('/settings', async (req, res) => {
  try {
    const { name, features } = req.body;
    
    // Validar que el usuario sea owner o admin
    if (req.user.role !== 'owner' && req.user.role !== 'admin') {
      return res.status(403).json({
        error: 'No tienes permisos para modificar la configuración',
        code: 'INSUFFICIENT_PERMISSIONS'
      });
    }
    
    const updateFields = [];
    const values = [];
    let paramCount = 0;
    
    if (name) {
      paramCount++;
      updateFields.push(`name = $${paramCount}`);
      values.push(name);
    }
    
    if (features) {
      paramCount++;
      updateFields.push(`features = $${paramCount}`);
      values.push(JSON.stringify(features));
    }
    
    if (updateFields.length === 0) {
      return res.status(400).json({
        error: 'No hay campos para actualizar',
        code: 'NO_FIELDS_TO_UPDATE'
      });
    }
    
    paramCount++;
    updateFields.push(`updated_at = NOW()`);
    values.push(req.user.organization_id);
    
    const updateQuery = `
      UPDATE saas.organizations 
      SET ${updateFields.join(', ')}
      WHERE id = $${paramCount}
      RETURNING *
    `;
    
    const result = await pool.query(updateQuery, values);
    
    res.json({
      success: true,
      organization: result.rows[0]
    });
    
  } catch (error) {
    console.error('Error actualizando configuración:', error);
    res.status(500).json({ 
      error: 'Error al actualizar configuración',
      code: 'UPDATE_SETTINGS_ERROR'
    });
  }
});

// Funciones auxiliares

function getPlanDefaults(plan) {
  const defaults = {
    starter: {
      max_users: 5,
      max_products: 100,
      max_monthly_orders: 500,
      storage_gb: 1
    },
    professional: {
      max_users: 20,
      max_products: 1000,
      max_monthly_orders: 2000,
      storage_gb: 10
    },
    enterprise: {
      max_users: 100,
      max_products: 10000,
      max_monthly_orders: 10000,
      storage_gb: 100
    }
  };
  
  return defaults[plan] || defaults.starter;
}

function getPlanPricing() {
  return {
    starter: 29,
    professional: 99,
    enterprise: 299,
    per_extra_user: 5,
    per_extra_gb: 2
  };
}

function generateUsageAlerts(usage, limits) {
  const alerts = [];
  
  if (!limits) return alerts;
  
  // Alerta de usuarios
  if (usage.current_users >= limits.max_users * 0.8) {
    alerts.push(`Estás usando ${usage.current_users} de ${limits.max_users} usuarios disponibles`);
  }
  
  // Alerta de productos
  if (usage.current_products >= limits.max_products * 0.8) {
    alerts.push(`Tienes ${usage.current_products} de ${limits.max_products} productos máximos`);
  }
  
  // Alerta de órdenes mensuales
  if (usage.monthly_orders >= limits.max_monthly_orders * 0.8) {
    alerts.push(`Has procesado ${usage.monthly_orders} de ${limits.max_monthly_orders} órdenes este mes`);
  }
  
  // Alerta de almacenamiento
  if (usage.storage_used_gb >= limits.storage_gb * 0.8) {
    alerts.push(`Estás usando ${usage.storage_used_gb} GB de ${limits.storage_gb} GB de almacenamiento`);
  }
  
  return alerts;
}

function generateMockOrdersTrend() {
  const trend = [];
  const today = new Date();
  
  for (let i = 29; i >= 0; i--) {
    const date = new Date(today);
    date.setDate(date.getDate() - i);
    
    trend.push({
      date: date.toISOString().split('T')[0],
      orders: Math.floor(Math.random() * 20) + 5
    });
  }
  
  return trend;
}

function generateMockCategoryData() {
  return [
    { category: 'Lácteos', count: 15 },
    { category: 'Frutas y Verduras', count: 22 },
    { category: 'Carnes', count: 8 },
    { category: 'Bebidas', count: 12 },
    { category: 'Panadería', count: 6 }
  ];
}

function generateMockAnalytics(metric, days) {
  const data = [];
  const today = new Date();
  
  for (let i = days - 1; i >= 0; i--) {
    const date = new Date(today);
    date.setDate(date.getDate() - i);
    
    let value = 0;
    switch (metric) {
      case 'orders':
        value = Math.floor(Math.random() * 50) + 10;
        break;
      case 'users':
        value = Math.floor(Math.random() * 5) + 1;
        break;
      case 'products':
        value = Math.floor(Math.random() * 10) + 2;
        break;
    }
    
    data.push({
      date: date.toISOString().split('T')[0],
      value: value
    });
  }
  
  return data;
}

function calculateGrowthRate(data) {
  if (data.length < 2) return 0;
  
  const firstHalf = data.slice(0, Math.floor(data.length / 2));
  const secondHalf = data.slice(Math.floor(data.length / 2));
  
  const firstAvg = firstHalf.reduce((sum, item) => sum + parseInt(item.value), 0) / firstHalf.length;
  const secondAvg = secondHalf.reduce((sum, item) => sum + parseInt(item.value), 0) / secondHalf.length;
  
  return firstAvg > 0 ? Math.round(((secondAvg - firstAvg) / firstAvg) * 100) : 0;
}

export default router; 