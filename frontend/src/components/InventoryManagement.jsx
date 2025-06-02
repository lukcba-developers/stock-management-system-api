import React, { useState, useEffect } from 'react';
import { toast } from 'react-hot-toast';
import axios from 'axios';
import { useAuth } from '../contexts/AuthContext';
import { StockStatusBadge } from './StockStatusBadge';
import { CategoryFilter } from './CategoryFilter';
import { SearchInput } from './SearchInput';
import { StockAdjustmentModal } from './StockAdjustmentModal';
import { StockAlertBanner } from './StockAlertBanner';
import { InventoryStats } from './InventoryStats';

const InventoryManagement = () => {
  const { token } = useAuth();
  const [products, setProducts] = useState([]);
  const [stockAlerts, setStockAlerts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedProduct, setSelectedProduct] = useState(null);
  const [showAdjustmentModal, setShowAdjustmentModal] = useState(false);
  const [filters, setFilters] = useState({
    stockStatus: 'all',
    category: '',
    search: '',
    sortBy: 'name',
    sortOrder: 'asc'
  });

  // Cargar productos y categorías
  useEffect(() => {
    fetchProducts();
    fetchCategories();
    fetchStockAlerts();
  }, [filters]);

  const fetchProducts = async () => {
    try {
      setLoading(true);
      const response = await axios.get('/api/products', {
        headers: { Authorization: `Bearer ${token}` },
        params: filters
      });
      setProducts(response.data.data);
    } catch (error) {
      toast.error('Error al cargar productos');
      console.error('Error:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchCategories = async () => {
    try {
      const response = await axios.get('/api/categories', {
        headers: { Authorization: `Bearer ${token}` }
      });
      setCategories(response.data.data);
    } catch (error) {
      toast.error('Error al cargar categorías');
    }
  };

  const fetchStockAlerts = async () => {
    try {
      const response = await axios.get('/api/inventory/alerts', {
        headers: { Authorization: `Bearer ${token}` }
      });
      setStockAlerts(response.data.data);
    } catch (error) {
      toast.error('Error al cargar alertas de stock');
    }
  };

  const handleFilterChange = (newFilters) => {
    setFilters(prev => ({ ...prev, ...newFilters }));
  };

  const handleSort = (field) => {
    setFilters(prev => ({
      ...prev,
      sortBy: field,
      sortOrder: prev.sortBy === field && prev.sortOrder === 'asc' ? 'desc' : 'asc'
    }));
  };

  const handleQuickAdjustment = (product) => {
    setSelectedProduct(product);
    setShowAdjustmentModal(true);
  };

  return (
    <div className="space-y-6 p-6">
      {/* Estadísticas de inventario */}
      <InventoryStats />

      {/* Filtros avanzados */}
      <div className="bg-white p-4 rounded-lg shadow">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <SearchInput
            value={filters.search}
            onChange={(value) => handleFilterChange({ search: value })}
            placeholder="Buscar productos..."
          />
          
          <CategoryFilter
            categories={categories}
            value={filters.category}
            onChange={(value) => handleFilterChange({ category: value })}
          />

          <select
            value={filters.stockStatus}
            onChange={(e) => handleFilterChange({ stockStatus: e.target.value })}
            className="border rounded px-3 py-2"
          >
            <option value="all">Todos los estados</option>
            <option value="normal">Stock Normal</option>
            <option value="low">Stock Bajo</option>
            <option value="out">Sin Stock</option>
          </select>

          <select
            value={`${filters.sortBy}-${filters.sortOrder}`}
            onChange={(e) => {
              const [sortBy, sortOrder] = e.target.value.split('-');
              handleFilterChange({ sortBy, sortOrder });
            }}
            className="border rounded px-3 py-2"
          >
            <option value="name-asc">Nombre (A-Z)</option>
            <option value="name-desc">Nombre (Z-A)</option>
            <option value="stock_quantity-asc">Stock (Menor a Mayor)</option>
            <option value="stock_quantity-desc">Stock (Mayor a Menor)</option>
          </select>
        </div>
      </div>

      {/* Alertas de stock */}
      {stockAlerts.length > 0 && (
        <StockAlertBanner alerts={stockAlerts} />
      )}

      {/* Lista de productos */}
      <div className="bg-white rounded-lg shadow overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th 
                  className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer"
                  onClick={() => handleSort('name')}
                >
                  Producto
                </th>
                <th 
                  className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer"
                  onClick={() => handleSort('stock_quantity')}
                >
                  Stock Actual
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Stock Mínimo
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Estado
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Acciones
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {loading ? (
                <tr>
                  <td colSpan="5" className="px-6 py-4 text-center">
                    Cargando productos...
                  </td>
                </tr>
              ) : products.length === 0 ? (
                <tr>
                  <td colSpan="5" className="px-6 py-4 text-center">
                    No se encontraron productos
                  </td>
                </tr>
              ) : (
                products.map(product => (
                  <tr key={product.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center">
                        {product.image_url && (
                          <img 
                            src={product.image_url} 
                            alt={product.name}
                            className="h-10 w-10 rounded-full object-cover mr-3"
                          />
                        )}
                        <div>
                          <div className="text-sm font-medium text-gray-900">
                            {product.name}
                          </div>
                          <div className="text-sm text-gray-500">
                            {product.category_name}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-900">{product.stock_quantity}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-900">{product.min_stock_alert}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <StockStatusBadge product={product} />
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <button
                        onClick={() => handleQuickAdjustment(product)}
                        className="text-indigo-600 hover:text-indigo-900 mr-4"
                      >
                        Ajustar Stock
                      </button>
                      <button
                        onClick={() => {/* Implementar vista detallada */}}
                        className="text-gray-600 hover:text-gray-900"
                      >
                        Ver Detalles
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal de ajuste de stock */}
      {showAdjustmentModal && selectedProduct && (
        <StockAdjustmentModal
          product={selectedProduct}
          onClose={() => {
            setShowAdjustmentModal(false);
            setSelectedProduct(null);
          }}
          onSuccess={() => {
            fetchProducts();
            fetchStockAlerts();
          }}
        />
      )}
    </div>
  );
};

export default InventoryManagement; 