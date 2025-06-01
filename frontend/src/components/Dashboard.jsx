import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { format, subDays, parseISO } from 'date-fns';
import { es } from 'date-fns/locale';
import {
  BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend,
  ResponsiveContainer, PieChart, Pie, Cell
} from 'recharts';
import { Calendar, TrendingUp, Package, AlertCircle, DollarSign } from 'lucide-react';

const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884d8'];

const Dashboard = () => {
  const [stats, setStats] = useState(null);
  const [dateRange, setDateRange] = useState({
    start: subDays(new Date(), 30),
    end: new Date()
  });
  const [loading, setLoading] = useState(true);
  const [visibleKPIs, setVisibleKPIs] = useState({
    totalProducts: true,
    lowStockProducts: true,
    outOfStockProducts: true,
    totalInventoryValue: true,
    ordersToday: true,
    revenueToday: true
  });

  useEffect(() => {
    fetchDashboardData();
  }, [dateRange]);

  const fetchDashboardData = async () => {
    try {
      setLoading(true);
      const response = await axios.get('/api/dashboard/stats', {
        params: {
          startDate: dateRange.start.toISOString(),
          endDate: dateRange.end.toISOString()
        }
      });
      setStats(response.data.data);
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
    } finally {
      setLoading(false);
    }
  };

  const toggleKPI = (kpi) => {
    setVisibleKPIs(prev => ({
      ...prev,
      [kpi]: !prev[kpi]
    }));
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
      </div>
    );
  }

  if (!stats) return null;

  return (
    <div className="space-y-6">
      {/* Date Range Selector */}
      <div className="bg-white p-4 rounded-lg shadow-sm">
        <div className="flex items-center gap-4">
          <Calendar className="text-indigo-600" />
          <input
            type="date"
            value={format(dateRange.start, 'yyyy-MM-dd')}
            onChange={(e) => setDateRange(prev => ({ ...prev, start: new Date(e.target.value) }))}
            className="border rounded-md px-3 py-2"
          />
          <span>hasta</span>
          <input
            type="date"
            value={format(dateRange.end, 'yyyy-MM-dd')}
            onChange={(e) => setDateRange(prev => ({ ...prev, end: new Date(e.target.value) }))}
            className="border rounded-md px-3 py-2"
          />
        </div>
      </div>

      {/* KPIs Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {Object.entries(visibleKPIs).map(([kpi, isVisible]) => {
          if (!isVisible) return null;
          
          const kpiConfig = {
            totalProducts: { icon: Package, label: 'Total Productos', color: 'bg-blue-100 text-blue-600' },
            lowStockProducts: { icon: AlertCircle, label: 'Stock Bajo', color: 'bg-orange-100 text-orange-600' },
            outOfStockProducts: { icon: AlertCircle, label: 'Sin Stock', color: 'bg-red-100 text-red-600' },
            totalInventoryValue: { icon: DollarSign, label: 'Valor Inventario', color: 'bg-green-100 text-green-600' },
            ordersToday: { icon: TrendingUp, label: 'Órdenes Hoy', color: 'bg-purple-100 text-purple-600' },
            revenueToday: { icon: DollarSign, label: 'Ingresos Hoy', color: 'bg-indigo-100 text-indigo-600' }
          };

          const { icon: Icon, label, color } = kpiConfig[kpi];
          const value = kpi.includes('Value') || kpi.includes('revenue')
            ? `$${stats[kpi]?.toFixed(2)}`
            : stats[kpi];

          return (
            <div key={kpi} className="bg-white p-4 rounded-lg shadow-sm">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <div className={`p-2 rounded-full ${color}`}>
                    <Icon className="w-5 h-5" />
                  </div>
                  <span className="text-sm font-medium text-gray-600">{label}</span>
                </div>
                <button
                  onClick={() => toggleKPI(kpi)}
                  className="text-gray-400 hover:text-gray-600"
                >
                  ×
                </button>
              </div>
              <p className="text-2xl font-bold mt-2">{value}</p>
            </div>
          );
        })}
      </div>

      {/* Charts Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Stock Evolution Chart */}
        <div className="bg-white p-4 rounded-lg shadow-sm">
          <h3 className="text-lg font-semibold mb-4">Evolución de Stock</h3>
          <div className="h-80">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={stats.stockEvolution}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="date" />
                <YAxis />
                <Tooltip />
                <Legend />
                <Line type="monotone" dataKey="stock" stroke="#8884d8" />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Sales by Category Chart */}
        <div className="bg-white p-4 rounded-lg shadow-sm">
          <h3 className="text-lg font-semibold mb-4">Ventas por Categoría</h3>
          <div className="h-80">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={stats.salesByCategory}
                  dataKey="value"
                  nameKey="name"
                  cx="50%"
                  cy="50%"
                  outerRadius={80}
                  label
                >
                  {stats.salesByCategory.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Inventory Turnover Chart */}
        <div className="bg-white p-4 rounded-lg shadow-sm">
          <h3 className="text-lg font-semibold mb-4">Rotación de Inventario</h3>
          <div className="h-80">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={stats.inventoryTurnover}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="category" />
                <YAxis />
                <Tooltip />
                <Legend />
                <Bar dataKey="turnover" fill="#82ca9d" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Top Selling Products Chart */}
        <div className="bg-white p-4 rounded-lg shadow-sm">
          <h3 className="text-lg font-semibold mb-4">Productos Más Vendidos</h3>
          <div className="h-80">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={stats.topSellingProducts}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" />
                <YAxis />
                <Tooltip />
                <Legend />
                <Bar dataKey="total_sold" fill="#8884d8" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard; 