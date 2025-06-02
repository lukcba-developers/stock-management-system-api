import React from 'react';

export const StockStatusBadge = ({ product }) => {
  const getStatusInfo = () => {
    if (product.stock_quantity === 0) {
      return {
        text: 'Sin Stock',
        color: 'bg-red-100 text-red-800'
      };
    }
    if (product.stock_quantity <= product.min_stock_alert) {
      return {
        text: 'Stock Bajo',
        color: 'bg-yellow-100 text-yellow-800'
      };
    }
    return {
      text: 'Stock Normal',
      color: 'bg-green-100 text-green-800'
    };
  };

  const status = getStatusInfo();

  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${status.color}`}>
      {status.text}
    </span>
  );
}; 