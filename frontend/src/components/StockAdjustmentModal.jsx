import React, { useState } from 'react';
import { toast } from 'react-hot-toast';
import axios from 'axios';
import { useAuth } from '../contexts/AuthContext';
import { X } from 'lucide-react';

export const StockAdjustmentModal = ({ product, onClose, onSuccess }) => {
  const { token } = useAuth();
  const [adjustment, setAdjustment] = useState({
    type: 'increase',
    quantity: '',
    reason: ''
  });
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!adjustment.quantity || adjustment.quantity <= 0) {
      toast.error('Por favor ingrese una cantidad válida');
      return;
    }

    if (!adjustment.reason) {
      toast.error('Por favor ingrese un motivo para el ajuste');
      return;
    }

    try {
      setLoading(true);
      const response = await axios.post(
        `/api/inventory/adjust/${product.id}`,
        {
          adjustment_type: adjustment.type,
          quantity_change: parseInt(adjustment.quantity),
          reason: adjustment.reason
        },
        {
          headers: { Authorization: `Bearer ${token}` }
        }
      );

      if (response.data.success) {
        toast.success('Stock actualizado correctamente');
        onSuccess();
        onClose();
      }
    } catch (error) {
      toast.error(error.response?.data?.error || 'Error al actualizar el stock');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg max-w-md w-full">
        <div className="flex justify-between items-center p-4 border-b">
          <h3 className="text-lg font-medium">
            Ajustar Stock - {product.name}
          </h3>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-500"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-4 space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700">
              Tipo de Ajuste
            </label>
            <div className="mt-1 flex space-x-4">
              <label className="inline-flex items-center">
                <input
                  type="radio"
                  value="increase"
                  checked={adjustment.type === 'increase'}
                  onChange={(e) => setAdjustment(prev => ({ ...prev, type: e.target.value }))}
                  className="form-radio"
                />
                <span className="ml-2">Aumentar</span>
              </label>
              <label className="inline-flex items-center">
                <input
                  type="radio"
                  value="decrease"
                  checked={adjustment.type === 'decrease'}
                  onChange={(e) => setAdjustment(prev => ({ ...prev, type: e.target.value }))}
                  className="form-radio"
                />
                <span className="ml-2">Disminuir</span>
              </label>
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700">
              Cantidad
            </label>
            <input
              type="number"
              min="1"
              value={adjustment.quantity}
              onChange={(e) => setAdjustment(prev => ({ ...prev, quantity: e.target.value }))}
              className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
              placeholder="Ingrese la cantidad"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700">
              Motivo
            </label>
            <textarea
              value={adjustment.reason}
              onChange={(e) => setAdjustment(prev => ({ ...prev, reason: e.target.value }))}
              rows="3"
              className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
              placeholder="Ingrese el motivo del ajuste"
            />
          </div>

          <div className="flex justify-end space-x-3">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 hover:bg-gray-50"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={loading}
              className="px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50"
            >
              {loading ? 'Guardando...' : 'Guardar Ajuste'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}; 