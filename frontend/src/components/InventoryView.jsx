import React from 'react';
import {
  Search, Edit, Eye, Clock, Package, ChevronLeft, ChevronRight, ChevronsLeft, ChevronsRight, Download, AlertCircle
} from 'lucide-react';
import { format } from 'date-fns';
import { es } from 'date-fns/locale';

// Componente de Paginación reutilizable
const Pagination = ({ currentPage, totalPages, onPageChange }) => {
  if (totalPages <= 1) return null;

  const pageNumbers = [];
  const maxPagesToShow = 5;
  let startPage = Math.max(1, currentPage - Math.floor(maxPagesToShow / 2));
  let endPage = Math.min(totalPages, startPage + maxPagesToShow - 1);

  if (endPage - startPage + 1 < maxPagesToShow) {
    startPage = Math.max(1, endPage - maxPagesToShow + 1);
  }

  for (let i = startPage; i <= endPage; i++) {
    pageNumbers.push(i);
  }

  return (
    <nav className="relative z-0 inline-flex rounded-md shadow-sm -space-x-px" aria-label="Pagination">
      <button
        onClick={() => onPageChange(1)}
        disabled={currentPage === 1}
        className="relative inline-flex items-center px-2 py-2 rounded-l-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 disabled:opacity-50"
      >
        <ChevronsLeft className="h-5 w-5" />
      </button>
      <button
        onClick={() => onPageChange(Math.max(1, currentPage - 1))}
        disabled={currentPage === 1}
        className="relative inline-flex items-center px-2 py-2 border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 disabled:opacity-50"
      >
        <ChevronLeft className="h-5 w-5" />
      </button>

      {pageNumbers.map(number => (
        <button
          key={number}
          onClick={() => onPageChange(number)}
          className={`relative inline-flex items-center px-4 py-2 border text-sm font-medium ${
            currentPage === number
              ? 'z-10 bg-indigo-50 border-indigo-500 text-indigo-600'
              : 'bg-white border-gray-300 text-gray-500 hover:bg-gray-50'
          }`}
        >
          {number}
        </button>
      ))}

      <button
        onClick={() => onPageChange(Math.min(totalPages, currentPage + 1))}
        disabled={currentPage === totalPages}
        className="relative inline-flex items-center px-2 py-2 border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 disabled:opacity-50"
      >
        <ChevronRight className="h-5 w-5" />
      </button>
      <button
        onClick={() => onPageChange(totalPages)}
        disabled={currentPage === totalPages}
        className="relative inline-flex items-center px-2 py-2 rounded-r-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50 disabled:opacity-50"
      >
        <ChevronsRight className="h-5 w-5" />
      </button>
    </nav>
  );
};

const InventoryView = ({
  products,
  categories,
  filters,
  setFilters,
  pagination,
  onEdit,
  onDetail,
  userRole,
  getStockStatusUI,
  API_URL,
  dataLoading,
}) => {

  const handleFilterChange = (e) => {
    const { name, value, type, checked } = e.target;
    setFilters(prev => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : value,
      page: 1 // Reset page on filter change
    }));
  };

  const handleSort = (newSortBy) => {
    setFilters(prev => ({
        ...prev,
        sortBy: newSortBy,
        sortOrder: prev.sortBy === newSortBy && prev.sortOrder === 'ASC' ? 'DESC' : 'ASC',
        page: 1,
    }));
  };

  const SortableHeader = ({ label, field }) => (
    <th 
        className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
        onClick={() => handleSort(field)}
    >
        <div className="flex items-center">
            {label}
            {filters.sortBy === field && (
                <span className="ml-1">
                    {filters.sortOrder === 'ASC' ? '▲' : '▼'}
                </span>
            )}
        </div>
    </th>
  );

  return (
    <div className="space-y-6">
      {/* Filtros */}
      <div className="bg-white rounded-lg shadow p-4">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 items-end">
          <div className="lg:col-span-1">
            <label htmlFor="search" className="block text-sm font-medium text-gray-700 mb-1">Buscar</label>
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
              <input
                type="text"
                name="search"
                id="search"
                placeholder="Nombre, marca, código..."
                value={filters.search}
                onChange={handleFilterChange}
                className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent shadow-sm"
              />
            </div>
          </div>
          
          <div>
            <label htmlFor="category" className="block text-sm font-medium text-gray-700 mb-1">Categoría</label>
            <select
              name="category"
              id="category"
              value={filters.category}
              onChange={handleFilterChange}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 shadow-sm"
            >
              <option value="">Todas</option>
              {categories.map(cat => (
                <option key={cat.id} value={cat.id}>
                  {cat.icon_emoji} {cat.name}
                </option>
              ))}
            </select>
          </div>
          
          <div className="flex items-center justify-start pt-5 md:pt-0">
            <label className="flex items-center gap-2 cursor-pointer p-2 border border-gray-300 rounded-lg hover:bg-gray-50 shadow-sm">
              <input
                type="checkbox"
                name="lowStock"
                checked={filters.lowStock}
                onChange={handleFilterChange}
                className="w-4 h-4 text-indigo-600 rounded focus:ring-indigo-500 border-gray-300"
              />
              <span className="text-sm text-gray-700">Solo stock bajo</span>
              <AlertCircle className="w-4 h-4 text-orange-500 ml-1"/>
            </label>
          </div>
        </div>
      </div>

      {/* Tabla de productos */}
      <div className="bg-white rounded-lg shadow overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full min-w-max">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Producto</th>
                <SortableHeader label="Categoría" field="category_name" />
                <SortableHeader label="Stock" field="stock_quantity" />
                <SortableHeader label="Precio" field="price" />
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Estado</th>
                <SortableHeader label="Actualizado" field="updated_at" />
                <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Acciones</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {dataLoading && products.length === 0 ? (
                <tr>
                  <td colSpan="7" className="px-6 py-10 text-center">
                    <div className="flex justify-center items-center">
                      <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600 mr-3"></div>
                      Cargando productos...
                    </div>
                  </td>
                </tr>
              ) : !dataLoading && products.length === 0 ? (
                <tr>
                  <td colSpan="7" className="px-6 py-10 text-center text-gray-500">
                    No se encontraron productos con los filtros actuales.
                  </td>
                </tr>
              ) : (
                products.map((product) => {
                  const stockStatus = getStockStatusUI(product);
                  return (
                    <tr key={product.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-4 py-3 whitespace-nowrap">
                        <div className="flex items-center">
                          {product.image_url ? (
                            <img
                              src={`${API_URL.replace('/api', '')}${product.image_url}`}
                              alt={product.name}
                              className="w-10 h-10 rounded-lg object-cover shadow-sm"
                              onError={(e) => e.target.src='https://via.placeholder.com/40'}
                            />
                          ) : (
                            <div className="w-10 h-10 rounded-lg bg-gray-200 flex items-center justify-center shadow-sm">
                              <Package className="w-5 h-5 text-gray-400" />
                            </div>
                          )}
                          <div className="ml-3">
                            <div className="text-sm font-medium text-gray-900 truncate max-w-xs">
                              {product.name}
                            </div>
                            <div className="text-xs text-gray-500">
                              {product.brand || 'Sin marca'} • {product.barcode || 'S/C'}
                            </div>
                          </div>
                        </div>
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap">
                        <span className="text-sm text-gray-700">
                          {product.category_icon || ''} {product.category_name || 'N/A'}
                        </span>
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap">
                        <div className="text-sm font-medium text-gray-900">
                          {product.stock_quantity} {product.weight_unit || ''}
                        </div>
                        <div className="text-xs text-gray-500">
                          Mín: {product.min_stock_alert}
                        </div>
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap">
                        <div className="text-sm font-medium text-gray-900">
                          ${typeof product.price === 'number' ? product.price.toFixed(2) : '0.00'}
                        </div>
                        {product.discount_percentage > 0 && (
                          <div className="text-xs text-red-600">
                            -{product.discount_percentage}%
                          </div>
                        )}
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap">
                        <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${stockStatus.bg} ${stockStatus.color}`}>
                          {stockStatus.label}
                        </span>
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap text-sm text-gray-500">
                        <div className="flex items-center gap-1">
                          <Clock className="w-3.5 h-3.5" />
                          {product.updated_at ? format(new Date(product.updated_at), 'dd/MM HH:mm', { locale: es }) : 'N/A'}
                        </div>
                      </td>
                      <td className="px-4 py-3 whitespace-nowrap text-right text-sm font-medium">
                        <div className="flex items-center justify-end gap-2">
                          <button
                            onClick={() => onDetail(product)}
                            className="text-gray-500 hover:text-indigo-600 p-1 rounded-md hover:bg-indigo-50"
                            title="Ver detalles"
                          >
                            <Eye className="w-4 h-4" />
                          </button>
                          {userRole !== 'viewer' && (
                            <button
                              onClick={() => onEdit(product)}
                              className="text-gray-500 hover:text-blue-600 p-1 rounded-md hover:bg-blue-50"
                              title="Editar"
                            >
                              <Edit className="w-4 h-4" />
                            </button>
                          )}
                          {/* Añadir botón de eliminar si es necesario y permitido por rol */}
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        {/* Paginación */} 
        {pagination.totalPages > 0 && (
            <div className="bg-white px-4 py-3 flex items-center justify-between border-t border-gray-200 sm:px-6">
                <div className="flex-1 flex justify-between sm:hidden">
                    <button
                        onClick={() => setFilters(prev => ({ ...prev, page: Math.max(1, prev.page - 1) }))}
                        disabled={pagination.page === 1 || dataLoading}
                        className="relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50"
                    >
                        Anterior
                    </button>
                    <button
                        onClick={() => setFilters(prev => ({ ...prev, page: Math.min(pagination.totalPages, prev.page + 1) }))}
                        disabled={pagination.page === pagination.totalPages || dataLoading}
                        className="ml-3 relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50"
                    >
                        Siguiente
                    </button>
                </div>
                <div className="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
                    <div>
                        <p className="text-sm text-gray-700">
                        Mostrando <span className="font-medium">{(pagination.page - 1) * pagination.limit + 1}</span> a <span className="font-medium">
                            {Math.min(pagination.page * pagination.limit, pagination.total)}
                        </span> de <span className="font-medium">{pagination.total}</span> productos
                        </p>
                    </div>
                    <div>
                        <Pagination 
                            currentPage={pagination.page}
                            totalPages={pagination.totalPages}
                            onPageChange={(page) => setFilters(prev => ({ ...prev, page }))}
                        />
                    </div>
                </div>
            </div>
        )}
      </div>
    </div>
  );
};

export default InventoryView; 