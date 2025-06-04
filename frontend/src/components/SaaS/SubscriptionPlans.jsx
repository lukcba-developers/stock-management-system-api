import React, { useState } from 'react';
import { 
  Crown, Check, Star, Zap, Users, Package, 
  ShoppingCart, Database, Settings, Support, 
  CreditCard, ArrowRight, Sparkles 
} from 'lucide-react';

const SubscriptionPlans = ({ currentPlan = 'starter', onUpgrade }) => {
  const [selectedPlan, setSelectedPlan] = useState(currentPlan);
  const [billingCycle, setBillingCycle] = useState('monthly');

  const plans = [
    {
      id: 'starter',
      name: 'Starter',
      icon: Star,
      description: 'Perfecto para pequeños negocios que empiezan',
      monthlyPrice: 29,
      yearlyPrice: 290,
      popular: false,
      features: [
        { icon: Users, text: 'Hasta 5 usuarios', included: true },
        { icon: Package, text: '100 productos máximo', included: true },
        { icon: ShoppingCart, text: '500 órdenes/mes', included: true },
        { icon: Database, text: '1 GB almacenamiento', included: true },
        { icon: Settings, text: 'Configuración básica', included: true },
        { icon: Support, text: 'Soporte por email', included: true },
        { icon: Zap, text: 'API acceso', included: false },
        { icon: Crown, text: 'Soporte prioritario', included: false }
      ],
      limitations: [
        'Sin acceso a API',
        'Reportes básicos',
        'Solo email de soporte'
      ]
    },
    {
      id: 'professional',
      name: 'Professional',
      icon: Crown,
      description: 'Ideal para empresas en crecimiento',
      monthlyPrice: 99,
      yearlyPrice: 990,
      popular: true,
      features: [
        { icon: Users, text: 'Hasta 20 usuarios', included: true },
        { icon: Package, text: '1,000 productos máximo', included: true },
        { icon: ShoppingCart, text: '2,000 órdenes/mes', included: true },
        { icon: Database, text: '10 GB almacenamiento', included: true },
        { icon: Settings, text: 'Configuración avanzada', included: true },
        { icon: Support, text: 'Soporte por email y chat', included: true },
        { icon: Zap, text: 'API completo', included: true },
        { icon: Crown, text: 'Soporte prioritario', included: false }
      ],
      limitations: [
        'Sin soporte telefónico',
        'Personalización limitada'
      ]
    },
    {
      id: 'enterprise',
      name: 'Enterprise',
      icon: Sparkles,
      description: 'Para grandes organizaciones',
      monthlyPrice: 299,
      yearlyPrice: 2990,
      popular: false,
      features: [
        { icon: Users, text: 'Usuarios ilimitados', included: true },
        { icon: Package, text: 'Productos ilimitados', included: true },
        { icon: ShoppingCart, text: 'Órdenes ilimitadas', included: true },
        { icon: Database, text: '100 GB almacenamiento', included: true },
        { icon: Settings, text: 'Personalización completa', included: true },
        { icon: Support, text: 'Soporte 24/7 dedicado', included: true },
        { icon: Zap, text: 'API empresarial', included: true },
        { icon: Crown, text: 'Gestor de cuenta dedicado', included: true }
      ],
      limitations: []
    }
  ];

  const getPrice = (plan) => {
    return billingCycle === 'monthly' ? plan.monthlyPrice : plan.yearlyPrice;
  };

  const getSavings = (plan) => {
    const monthlyTotal = plan.monthlyPrice * 12;
    const savings = monthlyTotal - plan.yearlyPrice;
    const percentage = Math.round((savings / monthlyTotal) * 100);
    return { amount: savings, percentage };
  };

  const handlePlanSelect = (planId) => {
    setSelectedPlan(planId);
  };

  const handleUpgrade = () => {
    if (onUpgrade) {
      onUpgrade(selectedPlan, billingCycle);
    }
  };

  return (
    <div className="max-w-7xl mx-auto p-6">
      {/* Header */}
      <div className="text-center mb-12">
        <h1 className="text-4xl font-bold text-gray-900 mb-4">
          Planes de Suscripción
        </h1>
        <p className="text-xl text-gray-600 mb-8">
          Elige el plan perfecto para tu negocio
        </p>

        {/* Toggle de facturación */}
        <div className="flex items-center justify-center gap-4">
          <span className={`text-sm ${billingCycle === 'monthly' ? 'text-gray-900 font-medium' : 'text-gray-500'}`}>
            Mensual
          </span>
          <button
            onClick={() => setBillingCycle(billingCycle === 'monthly' ? 'yearly' : 'monthly')}
            className="relative inline-flex h-6 w-11 items-center rounded-full bg-gray-200 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
          >
            <span
              className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                billingCycle === 'yearly' ? 'translate-x-6' : 'translate-x-1'
              }`}
            />
          </button>
          <span className={`text-sm ${billingCycle === 'yearly' ? 'text-gray-900 font-medium' : 'text-gray-500'}`}>
            Anual
          </span>
          {billingCycle === 'yearly' && (
            <span className="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
              Ahorra hasta 17%
            </span>
          )}
        </div>
      </div>

      {/* Planes */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mb-12">
        {plans.map((plan) => {
          const PlanIcon = plan.icon;
          const price = getPrice(plan);
          const savings = getSavings(plan);
          const isCurrentPlan = plan.id === currentPlan;
          const isSelected = plan.id === selectedPlan;

          return (
            <div
              key={plan.id}
              className={`relative bg-white rounded-xl shadow-lg overflow-hidden transition-all duration-300 hover:shadow-xl ${
                plan.popular 
                  ? 'ring-2 ring-blue-500 transform scale-105' 
                  : isSelected 
                    ? 'ring-2 ring-blue-300' 
                    : ''
              }`}
            >
              {/* Badge de popular */}
              {plan.popular && (
                <div className="absolute top-0 left-0 right-0 bg-gradient-to-r from-blue-500 to-purple-600 text-white text-center py-2 text-sm font-medium">
                  ⭐ Más Popular
                </div>
              )}

              {/* Badge de plan actual */}
              {isCurrentPlan && (
                <div className="absolute top-4 right-4 bg-green-100 text-green-800 px-3 py-1 rounded-full text-xs font-medium">
                  Plan Actual
                </div>
              )}

              <div className={`p-8 ${plan.popular ? 'pt-16' : ''}`}>
                {/* Header del plan */}
                <div className="text-center mb-8">
                  <div className={`inline-flex items-center justify-center w-16 h-16 rounded-full mb-4 ${
                    plan.popular ? 'bg-blue-100' : 'bg-gray-100'
                  }`}>
                    <PlanIcon className={`w-8 h-8 ${
                      plan.popular ? 'text-blue-600' : 'text-gray-600'
                    }`} />
                  </div>
                  
                  <h3 className="text-2xl font-bold text-gray-900 mb-2">
                    {plan.name}
                  </h3>
                  
                  <p className="text-gray-600 mb-6">
                    {plan.description}
                  </p>

                  {/* Precio */}
                  <div className="mb-6">
                    <div className="flex items-baseline justify-center gap-2">
                      <span className="text-4xl font-bold text-gray-900">
                        ${price}
                      </span>
                      <span className="text-gray-500">
                        /{billingCycle === 'monthly' ? 'mes' : 'año'}
                      </span>
                    </div>
                    
                    {billingCycle === 'yearly' && savings.amount > 0 && (
                      <p className="text-green-600 text-sm mt-2">
                        Ahorra ${savings.amount} al año ({savings.percentage}%)
                      </p>
                    )}
                  </div>
                </div>

                {/* Características */}
                <div className="space-y-4 mb-8">
                  {plan.features.map((feature, idx) => {
                    const FeatureIcon = feature.icon;
                    return (
                      <div 
                        key={idx} 
                        className={`flex items-center gap-3 ${
                          feature.included ? 'text-gray-900' : 'text-gray-400'
                        }`}
                      >
                        <div className={`w-5 h-5 rounded-full flex items-center justify-center ${
                          feature.included 
                            ? 'bg-green-100 text-green-600' 
                            : 'bg-gray-100 text-gray-400'
                        }`}>
                          {feature.included ? (
                            <Check className="w-3 h-3" />
                          ) : (
                            <span className="text-xs">×</span>
                          )}
                        </div>
                        <FeatureIcon className="w-4 h-4" />
                        <span className="text-sm">{feature.text}</span>
                      </div>
                    );
                  })}
                </div>

                {/* Botón de acción */}
                <button
                  onClick={() => handlePlanSelect(plan.id)}
                  disabled={isCurrentPlan}
                  className={`w-full py-3 px-4 rounded-lg font-medium transition-colors ${
                    isCurrentPlan
                      ? 'bg-gray-100 text-gray-500 cursor-not-allowed'
                      : plan.popular
                        ? 'bg-blue-600 text-white hover:bg-blue-700'
                        : isSelected
                          ? 'bg-blue-100 text-blue-700 border-2 border-blue-300'
                          : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                  }`}
                >
                  {isCurrentPlan 
                    ? 'Plan Actual' 
                    : isSelected 
                      ? 'Seleccionado' 
                      : 'Seleccionar Plan'
                  }
                </button>
              </div>
            </div>
          );
        })}
      </div>

      {/* Botón de actualización */}
      {selectedPlan !== currentPlan && (
        <div className="text-center">
          <button
            onClick={handleUpgrade}
            className="inline-flex items-center gap-2 px-8 py-4 bg-gradient-to-r from-blue-600 to-purple-600 text-white font-semibold rounded-xl hover:from-blue-700 hover:to-purple-700 transition-all duration-300 transform hover:scale-105 shadow-lg"
          >
            <CreditCard className="w-5 h-5" />
            Actualizar a {plans.find(p => p.id === selectedPlan)?.name}
            <ArrowRight className="w-5 h-5" />
          </button>
          
          <p className="text-gray-600 text-sm mt-4">
            Cambio inmediato • Cancelación en cualquier momento • Soporte incluido
          </p>
        </div>
      )}

      {/* Comparación de características */}
      <div className="mt-16 bg-gray-50 rounded-xl p-8">
        <h3 className="text-2xl font-bold text-center mb-8">
          Comparación Detallada
        </h3>
        
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-gray-200">
                <th className="text-left py-4 px-4 font-medium text-gray-900">
                  Características
                </th>
                {plans.map(plan => (
                  <th key={plan.id} className="text-center py-4 px-4 font-medium text-gray-900">
                    {plan.name}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              <tr>
                <td className="py-4 px-4 text-gray-700">Usuarios máximos</td>
                <td className="py-4 px-4 text-center">5</td>
                <td className="py-4 px-4 text-center">20</td>
                <td className="py-4 px-4 text-center">Ilimitados</td>
              </tr>
              <tr>
                <td className="py-4 px-4 text-gray-700">Productos máximos</td>
                <td className="py-4 px-4 text-center">100</td>
                <td className="py-4 px-4 text-center">1,000</td>
                <td className="py-4 px-4 text-center">Ilimitados</td>
              </tr>
              <tr>
                <td className="py-4 px-4 text-gray-700">Órdenes mensuales</td>
                <td className="py-4 px-4 text-center">500</td>
                <td className="py-4 px-4 text-center">2,000</td>
                <td className="py-4 px-4 text-center">Ilimitadas</td>
              </tr>
              <tr>
                <td className="py-4 px-4 text-gray-700">Almacenamiento</td>
                <td className="py-4 px-4 text-center">1 GB</td>
                <td className="py-4 px-4 text-center">10 GB</td>
                <td className="py-4 px-4 text-center">100 GB</td>
              </tr>
              <tr>
                <td className="py-4 px-4 text-gray-700">Acceso API</td>
                <td className="py-4 px-4 text-center">❌</td>
                <td className="py-4 px-4 text-center">✅</td>
                <td className="py-4 px-4 text-center">✅ Avanzado</td>
              </tr>
              <tr>
                <td className="py-4 px-4 text-gray-700">Soporte</td>
                <td className="py-4 px-4 text-center">Email</td>
                <td className="py-4 px-4 text-center">Email + Chat</td>
                <td className="py-4 px-4 text-center">24/7 Dedicado</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

export default SubscriptionPlans; 