import React, { useState, useEffect } from 'react';
import { 
  Building2, Users, Package, ShoppingCart, CreditCard, 
  TrendingUp, AlertCircle, Settings, Crown, Clock, 
  BarChart3, Activity, Database, Zap, Loader2
} from 'lucide-react';
import { 
  LineChart, Line, BarChart, Bar, XAxis, YAxis, 
  CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell 
} from 'recharts';

const OrganizationDashboard = () => {
  const [orgData, setOrgData] = useState(null);
  const [usage, setUsage] = useState({});
  const [billing, setBilling] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadOrganizationData();
  }, []);

  const loadOrganizationData = async () => {
    try {
      setLoading(true);
      setError(null);

      // Obtener token para las requests
      const token = localStorage.getItem('token');
      if (!token) {
        throw new Error('No hay token de autenticación');
      }

      const headers = {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      };

      const [orgRes, usageRes, billingRes] = await Promise.all([
        fetch(`${process.env.REACT_APP_API_URL}/api/organization/profile`, { headers }),
        fetch(`${process.env.REACT_APP_API_URL}/api/organization/usage`, { headers }),
        fetch(`${process.env.REACT_APP_API_URL}/api/organization/billing`, { headers })
      ]);

      if (!orgRes.ok || !usageRes.ok || !billingRes.ok) {
        throw new Error('Error al cargar datos de la organización');
      }

      const [orgData, usageData, billingData] = await Promise.all([
        orgRes.json(),
        usageRes.json(),
        billingRes.json()
      ]);
      
      setOrgData(orgData);
      setUsage(usageData);
      setBilling(billingData);
    } catch (error) {
      console.error('Error loading organization data:', error);
      setError(error.message);
    } finally {
      setLoading(false);
    }
  };

  const usagePercentage = (current, max) => {
    return max > 0 ? Math.round((current / max) * 100) : 0;
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-96">
        <div className="text-center">
          <Loader2 className="w-12 h-12 text-blue-600 mx-auto mb-4 animate-spin" />
          <p className="text-gray-600">Cargando dashboard de organización...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-6 max-w-7xl mx-auto">
        <div className="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
          <AlertCircle className="w-12 h-12 text-red-600 mx-auto mb-4" />
          <h3 className="text-lg font-semibold text-red-900 mb-2">Error al cargar datos</h3>
          <p className="text-red-700 mb-4">{error}</p>
          <button 
            onClick={loadOrganizationData}
            className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
          >
            Reintentar
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-6">
      {/* Header de Organización */}
      <div className="bg-white rounded-lg shadow-lg p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-4">
            <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center">
              <Building2 className="w-8 h-8 text-blue-600" />
            </div>
            <div>
              <h1 className="text-3xl font-bold text-gray-900">{orgData.name}</h1>
              <p className="text-gray-500">ID: {orgData.slug}</p>
              <div className="flex items-center gap-2 mt-1">
                <div className={`w-2 h-2 rounded-full ${
                  orgData.subscription_status === 'active' ? 'bg-green-500' : 'bg-red-500'
                }`}></div>
                <span className="text-sm text-gray-600 capitalize">
                  {orgData.subscription_status}
                </span>
              </div>
            </div>
          </div>
          
          <div className="text-right">
            <div className="flex items-center gap-2 mb-2">
              <Crown className="w-6 h-6 text-yellow-500" />
              <span className="text-xl font-bold capitalize">
                Plan {orgData.subscription_plan}
              </span>
            </div>
            <p className="text-gray-500 text-sm">
              {orgData.active_users_count} usuarios activos
            </p>
          </div>
        </div>

        {/* Métricas de Uso */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          <UsageCard
            icon={Users}
            title="Usuarios"
            current={usage.current_users || 0}
            max={orgData.max_users}
            color="blue"
          />
          
          <UsageCard
            icon={Package}
            title="Productos"
            current={usage.current_products || 0}
            max={orgData.max_products}
            color="green"
          />
          
          <UsageCard
            icon={ShoppingCart}
            title="Órdenes/Mes"
            current={usage.monthly_orders || 0}
            max={orgData.max_monthly_orders}
            color="purple"
          />
          
          <UsageCard
            icon={Database}
            title="Almacenamiento"
            current={`${usage.storage_used_gb || 0} GB`}
            max={`${orgData.storage_gb} GB`}
            color="orange"
            showProgress={true}
            currentNumeric={usage.storage_used_gb || 0}
            maxNumeric={orgData.storage_gb}
          />
        </div>
      </div>

      {/* Gráficos de Uso */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Tendencia de Órdenes */}
        <div className="bg-white rounded-lg shadow-lg p-6">
          <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
            <TrendingUp className="w-5 h-5 text-blue-600" />
            Tendencia de Órdenes (30 días)
          </h3>
          
          {usage.orders_trend && usage.orders_trend.length > 0 ? (
            <ResponsiveContainer width="100%" height={250}>
              <LineChart data={usage.orders_trend}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis 
                  dataKey="date" 
                  tick={{ fontSize: 12 }}
                  tickFormatter={(value) => new Date(value).toLocaleDateString()}
                />
                <YAxis />
                <Tooltip 
                  labelFormatter={(value) => new Date(value).toLocaleDateString()}
                />
                <Line 
                  type="monotone" 
                  dataKey="orders" 
                  stroke="#3B82F6" 
                  strokeWidth={2}
                  dot={{ fill: '#3B82F6', r: 4 }}
                />
              </LineChart>
            </ResponsiveContainer>
          ) : (
            <div className="h-64 flex items-center justify-center text-gray-500">
              <div className="text-center">
                <Activity className="w-12 h-12 mx-auto mb-2 opacity-50" />
                <p>No hay datos de órdenes aún</p>
              </div>
            </div>
          )}
        </div>

        {/* Uso por Categoría */}
        <div className="bg-white rounded-lg shadow-lg p-6">
          <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
            <BarChart3 className="w-5 h-5 text-green-600" />
            Productos por Categoría
          </h3>
          
          {usage.products_by_category && usage.products_by_category.length > 0 ? (
            <ResponsiveContainer width="100%" height={250}>
              <BarChart data={usage.products_by_category}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis 
                  dataKey="category" 
                  tick={{ fontSize: 12 }}
                  angle={-45}
                  textAnchor="end"
                  height={60}
                />
                <YAxis />
                <Tooltip />
                <Bar dataKey="count" fill="#10B981" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <div className="h-64 flex items-center justify-center text-gray-500">
              <div className="text-center">
                <Package className="w-12 h-12 mx-auto mb-2 opacity-50" />
                <p>No hay productos aún</p>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Alertas de Uso */}
      {usage.alerts && usage.alerts.length > 0 && (
        <div className="bg-amber-50 border border-amber-200 rounded-lg p-6">
          <div className="flex items-center gap-3 mb-4">
            <AlertCircle className="w-6 h-6 text-amber-600" />
            <h3 className="text-lg font-semibold text-amber-900">
              Atención: Aproximándote a los límites
            </h3>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {usage.alerts.map((alert, idx) => (
              <div key={idx} className="flex items-center gap-2 text-amber-800">
                <div className="w-2 h-2 bg-amber-500 rounded-full"></div>
                <span className="text-sm">{alert}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Plan y Facturación */}
      <div className="bg-white rounded-lg shadow-lg p-6">
        <h3 className="text-xl font-semibold mb-6 flex items-center gap-2">
          <CreditCard className="w-6 h-6 text-purple-600" />
          Plan y Facturación
        </h3>
        
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Detalles del Plan */}
          <div>
            <h4 className="font-semibold text-lg mb-4">Plan Actual: {orgData.subscription_plan}</h4>
            
            <div className="space-y-3">
              <PlanFeature 
                name="Usuarios máximos" 
                value={orgData.max_users}
                current={usage.current_users}
              />
              <PlanFeature 
                name="Productos máximos" 
                value={orgData.max_products}
                current={usage.current_products}
              />
              <PlanFeature 
                name="Órdenes mensuales" 
                value={orgData.max_monthly_orders}
                current={usage.monthly_orders}
              />
              <PlanFeature 
                name="Almacenamiento" 
                value={`${orgData.storage_gb} GB`}
                current={`${usage.storage_used_gb || 0} GB`}
              />
            </div>

            <div className="mt-6 p-4 bg-blue-50 rounded-lg">
              <h5 className="font-medium text-blue-900 mb-2">Características incluidas:</h5>
              <ul className="text-sm text-blue-800 space-y-1">
                <li>• Gestión de inventario completa</li>
                <li>• Reportes y analytics</li>
                <li>• Notificaciones por email</li>
                <li>• Soporte técnico</li>
                {orgData.subscription_plan !== 'starter' && (
                  <>
                    <li>• API access</li>
                    <li>• Integraciones avanzadas</li>
                  </>
                )}
                {orgData.subscription_plan === 'enterprise' && (
                  <>
                    <li>• Soporte prioritario</li>
                    <li>• Personalización</li>
                  </>
                )}
              </ul>
            </div>
          </div>

          {/* Información de Facturación */}
          <div>
            <h4 className="font-semibold text-lg mb-4">Próxima Facturación</h4>
            
            <div className="space-y-3">
              <div className="flex justify-between items-center p-4 bg-gray-50 rounded-lg">
                <span className="font-medium">Plan {orgData.subscription_plan}</span>
                <span className="font-bold text-lg">${billing.plan_price || 0}/mes</span>
              </div>
              
              {billing.extra_users_cost > 0 && (
                <div className="flex justify-between items-center p-3 bg-gray-50 rounded-lg">
                  <span>Usuarios adicionales</span>
                  <span>${billing.extra_users_cost}</span>
                </div>
              )}
              
              {billing.extra_storage_cost > 0 && (
                <div className="flex justify-between items-center p-3 bg-gray-50 rounded-lg">
                  <span>Almacenamiento extra</span>
                  <span>${billing.extra_storage_cost}</span>
                </div>
              )}
              
              <div className="border-t border-gray-200 pt-4">
                <div className="flex justify-between items-center">
                  <span className="font-semibold text-lg">Total estimado</span>
                  <span className="font-bold text-2xl text-green-600">
                    ${billing.next_bill_amount || billing.plan_price || 0}
                  </span>
                </div>
              </div>
              
              <div className="flex items-center gap-2 text-sm text-gray-500 mt-4">
                <Clock className="w-4 h-4" />
                <span>
                  Próximo cobro: {billing.next_billing_date 
                    ? new Date(billing.next_billing_date).toLocaleDateString('es-ES')
                    : 'No disponible'
                  }
                </span>
              </div>
            </div>

            <div className="mt-6 space-y-3">
              <button className="w-full px-4 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium">
                Actualizar Plan
              </button>
              <button className="w-full px-4 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
                Ver Historial de Facturación
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

// Componente de tarjeta de uso
const UsageCard = ({ 
  icon: Icon, 
  title, 
  current, 
  max, 
  color, 
  showProgress = true,
  currentNumeric,
  maxNumeric 
}) => {
  // Para casos como almacenamiento, usar valores numéricos específicos
  const numCurrent = currentNumeric !== undefined ? currentNumeric : (typeof current === 'number' ? current : parseInt(current) || 0);
  const numMax = maxNumeric !== undefined ? maxNumeric : (typeof max === 'number' ? max : parseInt(max) || 1);
  
  const percentage = showProgress ? Math.round((numCurrent / numMax) * 100) : 0;
  const isNearLimit = percentage > 80;
  const isAtLimit = percentage >= 100;
  
  const getColorClasses = () => {
    if (isAtLimit) return 'border-red-300 bg-red-50';
    if (isNearLimit) return 'border-yellow-300 bg-yellow-50';
    return 'border-gray-200 bg-white';
  };

  const getProgressColor = () => {
    if (isAtLimit) return 'bg-red-500';
    if (isNearLimit) return 'bg-yellow-500';
    return `bg-${color}-500`;
  };
  
  return (
    <div className={`p-6 rounded-lg border ${getColorClasses()} transition-all hover:shadow-md`}>
      <div className="flex items-center justify-between mb-3">
        <Icon className={`w-6 h-6 text-${color}-600`} />
        {isNearLimit && <AlertCircle className="w-5 h-5 text-yellow-500" />}
        {isAtLimit && <AlertCircle className="w-5 h-5 text-red-500" />}
      </div>
      
      <h3 className="text-sm font-medium text-gray-600 mb-1">{title}</h3>
      <p className="text-2xl font-bold text-gray-900">
        {current}
        {showProgress && <span className="text-lg text-gray-500 font-normal"> / {max}</span>}
      </p>
      
      {showProgress && (
        <div className="mt-4">
          <div className="h-2 bg-gray-200 rounded-full overflow-hidden">
            <div 
              className={`h-full ${getProgressColor()} transition-all duration-300`}
              style={{ width: `${Math.min(percentage, 100)}%` }}
            />
          </div>
          <p className={`text-xs mt-2 ${
            isAtLimit ? 'text-red-600' : isNearLimit ? 'text-yellow-600' : 'text-gray-500'
          }`}>
            {percentage}% usado
          </p>
        </div>
      )}
    </div>
  );
};

// Componente de característica del plan
const PlanFeature = ({ name, value, current }) => {
  const currentNum = typeof current === 'number' ? current : parseInt(current) || 0;
  const maxNum = typeof value === 'number' ? value : parseInt(value) || 1;
  const percentage = Math.round((currentNum / maxNum) * 100);
  const isNearLimit = percentage > 80;
  
  return (
    <div className="flex justify-between items-center py-3 border-b border-gray-100 last:border-b-0">
      <span className="text-gray-600">{name}</span>
      <div className="text-right">
        <span className="font-semibold">{current} / {value}</span>
        {typeof value === 'number' && (
          <div className={`text-xs ${isNearLimit ? 'text-yellow-600' : 'text-gray-500'}`}>
            {percentage}%
          </div>
        )}
      </div>
    </div>
  );
};

export default OrganizationDashboard; 