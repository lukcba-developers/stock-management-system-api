import React from 'react';
import { AlertTriangle } from 'lucide-react';

export const StockAlertBanner = ({ alerts }) => {
  if (!alerts || alerts.length === 0) return null;

  return (
    <div className="bg-orange-50 border-l-4 border-orange-400 p-4">
      <div className="flex">
        <div className="flex-shrink-0">
          <AlertTriangle className="h-5 w-5 text-orange-400" />
        </div>
        <div className="ml-3">
          <h3 className="text-sm font-medium text-orange-800">
            Alertas de Stock
          </h3>
          <div className="mt-2 text-sm text-orange-700">
            <ul className="list-disc pl-5 space-y-1">
              {alerts.map(alert => (
                <li key={alert.id}>
                  {alert.product_name}: {alert.current_stock} unidades restantes
                  {alert.min_stock_alert && (
                    <span className="ml-1">
                      (Mínimo: {alert.min_stock_alert})
                    </span>
                  )}
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}; 