import React, { useEffect } from 'react';
import { AlertCircle, Package, ShoppingCart, RefreshCw, Image as ImageIcon } from 'lucide-react';
import { toast } from 'react-hot-toast';

const AlertsView = ({ userRole, onProductDetail, API_URL, onUpdateStock, stockAlerts, isLoading }) => {
  const handleQuickRestock = async (productId, productName, currentStock, minimumStock) => {
    const suggestedQuantityBase = Math.max(1, (minimumStock * 2) - currentStock);
    const newTotalSuggested = currentStock + suggestedQuantityBase; 
    const quantityStr = prompt(`Nuevo stock TOTAL para ${productName} (actual: ${currentStock}, mínimo: ${minimumStock}):`, newTotalSuggested);
    
    if (quantityStr) {
      const newTotalStock = parseInt(quantityStr);
      if (!isNaN(newTotalStock) && newTotalStock >= 0) {
        const quantityChange = newTotalStock - currentStock;
        if (quantityChange !== 0) {
            try {
                if (onUpdateStock) {
                    const movementType = quantityChange > 0 ? 'in' : 'adjustment'; 
                    await onUpdateStock(productId, quantityChange, movementType, 'Reabastecimiento rápido desde alertas');
                } else {
                    toast.error('Función de actualización de stock no proporcionada.');
                }
            } catch (error) {
            }
        } else {
            toast.info('No se realizaron cambios en el stock.');
        }
      } else {
        toast.error('Cantidad total inválida. Debe ser un número mayor o igual a cero.');
      }
    }
  };

  if (isLoading && !stockAlerts.length) {
    return (
      <div className="flex justify-center items-center p-10">
        <RefreshCw className="w-8 h-8 animate-spin text-indigo-600" />
        <span className="ml-3 text-lg">Cargando alertas...</span>
      </div>
    );
  }

  if (!isLoading && stockAlerts.length === 0) {
    return (
      <div className="bg-white rounded-lg shadow p-8 text-center">
        <Package className="w-16 h-16 text-gray-300 mx-auto mb-4" />
        <h3 className="text-xl font-semibold text-gray-700">Todo en Orden</h3>
        <p className="text-gray-500 mt-2">No hay alertas de stock bajo o sin stock en este momento.</p>
      </div>
    );
  }

  if (stockAlerts.length > 0) {
    return (
      <div className="space-y-6">
        {stockAlerts.map((alert) => (
          <div key={alert.product_id || alert.id} className="bg-white rounded-lg shadow-md overflow-hidden transition-all hover:shadow-lg">
            <div className={`p-5 border-l-4 ${alert.current_stock === 0 ? 'border-red-500' : 'border-orange-400'}`}>
              <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
                  <div className="flex items-center gap-4 flex-1 min-w-0">
                      {alert.image_url ? (
                          <img 
                              src={`${API_URL.replace('/api', '')}${alert.image_url}`}
                              alt={alert.product_name}
                              className="w-16 h-16 object-cover rounded-md shadow-sm flex-shrink-0"
                              onError={(e) => { e.target.onerror = null; e.target.src='data:image/gif;base64,R0lGODlhAQABAIAAAMLCwgAAACH5BAAAAAAALAAAAAABAAEAAAICRAEAOw=='; }}
                          />
                      ) : (
                          <div className="w-16 h-16 bg-gray-100 rounded-md flex items-center justify-center flex-shrink-0">
                              <ImageIcon className="w-8 h-8 text-gray-400" />
                          </div>
                      )}
                      <div className="min-w-0">
                          <h4 
                              className="text-lg font-semibold text-gray-800 truncate hover:text-indigo-600 cursor-pointer"
                              onClick={() => onProductDetail ? onProductDetail({ ...(alert.product_id && {id: alert.product_id}), ...alert }) : null}
                              title={alert.product_name}
                          >
                              {alert.product_name}
                          </h4>
                          <p className="text-sm text-gray-500">Categoría: {alert.category_name || 'N/A'}</p>
                          <div className="mt-1 flex items-center gap-x-4 gap-y-1 text-xs flex-wrap">
                              <span className={`font-medium px-2 py-0.5 rounded-full ${alert.current_stock === 0 ? 'bg-red-100 text-red-700' : 'bg-orange-100 text-orange-700'}`}>
                                  Stock: {alert.current_stock}
                              </span>
                              <span className="text-gray-600">
                                  Mínimo: {alert.minimum_stock}
                              </span>
                          </div>
                      </div>
                  </div>
                
                {userRole !== 'viewer' && (
                  <button
                    onClick={() => handleQuickRestock(alert.product_id || alert.id, alert.product_name, alert.current_stock, alert.minimum_stock)}
                    className="mt-3 sm:mt-0 flex-shrink-0 flex items-center gap-2 px-4 py-2 bg-indigo-500 text-white text-sm font-medium rounded-md hover:bg-indigo-600 transition-colors shadow-sm focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                  >
                    <ShoppingCart className="w-4 h-4" />
                    Reabastecer
                  </button>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>
    );
  }
  
  return null;
};

export default AlertsView; 