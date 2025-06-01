// frontend/src/App.jsx
import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { GoogleOAuthProvider, GoogleLogin, hasGrantedAllScopesGoogle } from '@react-oauth/google';
import axios from 'axios';
import { Toaster, toast } from 'react-hot-toast';
import {
  Search, Package, AlertCircle, TrendingUp, TrendingDown, Edit, Save, X, Plus, Filter,
  BarChart3, ShoppingCart, DollarSign, Bell, LogOut, Menu, Download, RefreshCw,
  Camera, Trash2, Eye, Clock, User, ChevronLeft, ChevronRight, ChevronsLeft, ChevronsRight,
  UploadCloud, Image as ImageIcon, XCircle, EyeOff, Settings, Users, FileText, HelpCircle
} from 'lucide-react';
import { format, parseISO } from 'date-fns';
import { es } from 'date-fns/locale';
import Dashboard from './components/Dashboard';

// Configuración de axios
const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001/api';
const GOOGLE_CLIENT_ID = import.meta.env.VITE_GOOGLE_CLIENT_ID;

axios.defaults.baseURL = API_URL;

axios.interceptors.request.use(
  config => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  error => Promise.reject(error)
);

axios.interceptors.response.use(
  response => response,
  error => {
    if (error.response && (error.response.status === 401 || error.response.status === 403) ) {
      const errorMessage = error.response.data.error;
      if (errorMessage === 'Token expirado' || errorMessage === 'Token inválido' || errorMessage === 'Usuario no válido o inactivo.') {
        localStorage.removeItem('token');
        toast.error(`Sesión inválida: ${errorMessage}. Por favor, inicie sesión de nuevo.`);
         setTimeout(() => window.dispatchEvent(new Event('authError')), 0);
      }
    }
    return Promise.reject(error);
  }
);

// Componente de Login
function LoginPage({ onLogin }) {
  // Función de login de prueba
  const handleTestLogin = async () => {
    try {
      const response = await fetch('http://localhost:4000/api/auth/test-login', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      const data = await response.json();
      
      if (data.success) {
        localStorage.setItem('token', data.token);
        onLogin(null, data.user, data.token);
      } else {
        console.error('Error en login de prueba:', data.error);
      }
    } catch (error) {
      console.error('Error conectando al backend:', error);
    }
  };

  if (!GOOGLE_CLIENT_ID) {
    return (
         <div className="min-h-screen bg-gradient-to-br from-red-50 to-orange-100 flex items-center justify-center p-4">
            <div className="bg-white rounded-2xl shadow-xl p-8 max-w-md w-full text-center">
                <AlertCircle className="w-12 h-12 text-orange-500 mx-auto mb-4" />
                <h1 className="text-2xl font-bold text-gray-800 mb-2">Modo de Desarrollo</h1>
                <p className="text-gray-600 mb-6">
                    La variable de entorno <code>VITE_GOOGLE_CLIENT_ID</code> no está configurada.
                    Puedes usar el login de prueba para testing.
                </p>
                <button
                  onClick={handleTestLogin}
                  className="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-medium py-3 px-4 rounded-lg transition-colors shadow-sm mb-4"
                >
                  🧪 Entrar como Usuario de Prueba
                </button>
                <p className="text-xs text-gray-500">
                  Este botón solo aparece en desarrollo. En producción, configure Google OAuth.
                </p>
            </div>
        </div>
    );
  }
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-xl p-8 max-w-md w-full">
        <div className="text-center mb-8">
          <div className="bg-indigo-100 w-20 h-20 rounded-full flex items-center justify-center mx-auto mb-4">
            <ShoppingCart className="w-10 h-10 text-indigo-600" />
          </div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Stock Manager Pro</h1>
          <p className="text-gray-600">Sistema de Gestión de Inventario Avanzado</p>
        </div>
        <GoogleOAuthProvider clientId={GOOGLE_CLIENT_ID}>
          <GoogleLogin
            onSuccess={credentialResponse => {
              if (credentialResponse.credential) {
                onLogin(credentialResponse.credential);
              } else {
                 toast.error('Respuesta de Google inválida.');
              }
            }}
            onError={() => {
              toast.error('Error al iniciar sesión con Google');
            }}
            useOneTap
            theme="outline"
            size="large"
            width="100%"
            text="signin_with"
            locale="es"
          />
        </GoogleOAuthProvider>
        <p className="text-center text-sm text-gray-500 mt-6">
          Acceso exclusivo para administradores del sistema.
        </p>
      </div>
    </div>
  );
}

// Componente Modal Genérico
const Modal = ({ isOpen, onClose, title, children }) => {
  if (!isOpen) return null;
  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex justify-center items-center p-4">
      <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-center p-4 border-b">
          <h3 className="text-xl font-semibold">{title}</h3>
          <button onClick={onClose} className="text-gray-500 hover:text-gray-700">
            <XCircle size={24} />
          </button>
        </div>
        <div className="p-4 md:p-6">{children}</div>
      </div>
    </div>
  );
};

// Componente para Formulario de Producto (Crear/Editar)
// (Este sería un componente más grande, aquí un esbozo)
const ProductFormModal = ({ isOpen, onClose, product, categories, onSave, loading }) => {
    const [formData, setFormData] = useState({});
    const [imagePreview, setImagePreview] = useState(null);
    const [imageFile, setImageFile] = useState(null);

    useEffect(() => {
        if (product) {
            setFormData({ ...product, category_id: product.category_id || '' });
            setImagePreview(product.image_url || null);
        } else {
            setFormData({ // Valores por defecto para nuevo producto
                name: '', description: '', price: 0, stock_quantity: 0, min_stock_alert: 0,
                category_id: categories.length > 0 ? categories[0].id : '',
                brand: '', barcode: '', weight_unit: 'unidad', weight_value: 0,
                is_featured: false, is_available: true, meta_keywords: ''
            });
            setImagePreview(null);
        }
        setImageFile(null);
    }, [product, isOpen, categories]);


    const handleChange = (e) => {
        const { name, value, type, checked } = e.target;
        setFormData(prev => ({ ...prev, [name]: type === 'checkbox' ? checked : value }));
    };

    const handleImageChange = (e) => {
        const file = e.target.files[0];
        if (file) {
            setImageFile(file);
            const reader = new FileReader();
            reader.onloadend = () => {
                setImagePreview(reader.result);
            };
            reader.readAsDataURL(file);
        }
    };

    const handleSubmit = (e) => {
        e.preventDefault();
        const dataToSave = new FormData();
        Object.keys(formData).forEach(key => {
            if (key !== 'image_url' && key !== 'category_name' && key !== 'category_icon' && key !== 'stock_status' && key !== 'total_count') { // Evitar enviar campos no deseados
                 dataToSave.append(key, formData[key]);
            }
        });
        if (imageFile) {
            dataToSave.append('image', imageFile);
        } else if (formData.image_url === null && product?.image_url) { // Si se eliminó la imagen existente y no se subió nueva
            dataToSave.append('image_url', ''); // O manejar en backend para eliminarla
        }


        onSave(dataToSave, product?.id);
    };

    if (!isOpen) return null;

    return (
        <Modal isOpen={isOpen} onClose={onClose} title={product ? "Editar Producto" : "Crear Nuevo Producto"}>
            <form onSubmit={handleSubmit} className="space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                        <label htmlFor="name" className="block text-sm font-medium text-gray-700">Nombre*</label>
                        <input type="text" name="name" id="name" value={formData.name || ''} onChange={handleChange} required className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm p-2"/>
                    </div>
                    <div>
                        <label htmlFor="category_id" className="block text-sm font-medium text-gray-700">Categoría*</label>
                        <select name="category_id" id="category_id" value={formData.category_id || ''} onChange={handleChange} required className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm p-2">
                            <option value="" disabled>Seleccionar categoría</option>
                            {categories.map(cat => <option key={cat.id} value={cat.id}>{cat.name}</option>)}
                        </select>
                    </div>
                </div>

                <div>
                    <label htmlFor="description" className="block text-sm font-medium text-gray-700">Descripción</label>
                    <textarea name="description" id="description" value={formData.description || ''} onChange={handleChange} rows="3" className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm p-2"></textarea>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div>
                        <label htmlFor="price" className="block text-sm font-medium text-gray-700">Precio*</label>
                        <input type="number" name="price" id="price" value={formData.price || 0} onChange={handleChange} required step="0.01" className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm p-2"/>
                    </div>
                    <div>
                        <label htmlFor="stock_quantity" className="block text-sm font-medium text-gray-700">Stock Actual*</label>
                        <input type="number" name="stock_quantity" id="stock_quantity" value={formData.stock_quantity || 0} onChange={handleChange} required className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm p-2"/>
                    </div>
                    <div>
                        <label htmlFor="min_stock_alert" className="block text-sm font-medium text-gray-700">Alerta Stock Mínimo</label>
                        <input type="number" name="min_stock_alert" id="min_stock_alert" value={formData.min_stock_alert || 0} onChange={handleChange} className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm p-2"/>
                    </div>
                </div>

                 <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div>
                        <label htmlFor="brand" className="block text-sm font-medium text-gray-700">Marca</label>
                        <input type="text" name="brand" id="brand" value={formData.brand || ''} onChange={handleChange} className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm p-2"/>
                    </div>
                     <div>
                        <label htmlFor="barcode" className="block text-sm font-medium text-gray-700">Código de Barras</label>
                        <input type="text" name="barcode" id="barcode" value={formData.barcode || ''} onChange={handleChange} className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm p-2"/>
                    </div>
                </div>

                <div>
                    <label className="block text-sm font-medium text-gray-700">Imagen del Producto</label>
                    <div className="mt-1 flex items-center space-x-4">
                        {imagePreview ? (
                            <img src={imagePreview} alt="Vista previa" className="h-20 w-20 object-cover rounded-md" />
                        ) : (
                            <div className="h-20 w-20 bg-gray-100 rounded-md flex items-center justify-center text-gray-400">
                                <ImageIcon size={32} />
                            </div>
                        )}
                        <input type="file" name="image" id="image" onChange={handleImageChange} accept="image/jpeg,image/png,image/webp" className="hidden"/>
                        <button type="button" onClick={() => document.getElementById('image').click()} className="px-3 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 hover:bg-gray-50">
                            Cambiar imagen
                        </button>
                        {imagePreview && (
                            <button type="button" onClick={() => { setImagePreview(null); setImageFile(null); setFormData(prev => ({...prev, image_url: null})); }} className="text-red-500 hover:text-red-700">
                                <Trash2 size={18}/>
                            </button>
                        )}
                    </div>
                </div>


                <div className="flex items-center space-x-4 pt-4">
                    <label className="flex items-center">
                        <input type="checkbox" name="is_available" checked={formData.is_available || false} onChange={handleChange} className="h-4 w-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500"/>
                        <span className="ml-2 text-sm text-gray-700">Disponible para la venta</span>
                    </label>
                    <label className="flex items-center">
                        <input type="checkbox" name="is_featured" checked={formData.is_featured || false} onChange={handleChange} className="h-4 w-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500"/>
                        <span className="ml-2 text-sm text-gray-700">Producto Destacado</span>
                    </label>
                </div>


                <div className="pt-5">
                    <div className="flex justify-end space-x-3">
                        <button type="button" onClick={onClose} className="bg-white py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                            Cancelar
                        </button>
                        <button type="submit" disabled={loading} className={`inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white ${loading ? 'bg-indigo-400 cursor-not-allowed' : 'bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500'}`}>
                            {loading ? 'Guardando...' : (product ? 'Actualizar Producto' : 'Crear Producto')}
                        </button>
                    </div>
                </div>
            </form>
        </Modal>
    );
};

// Componente para ver detalles de producto
const ProductDetailModal = ({ isOpen, onClose, product }) => {
    if (!isOpen || !product) return null;

    const formatDate = (dateString) => {
        if (!dateString) return 'N/A';
        try {
            return format(parseISO(dateString), "dd/MM/yyyy HH:mm", { locale: es });
        } catch (e) {
            return dateString; // si falla el parseo, muestra el string original
        }
    };

    return (
        <Modal isOpen={isOpen} onClose={onClose} title={`Detalles de: ${product.name}`}>
            <div className="space-y-4">
                <div className="flex justify-center mb-4">
                    <img src={product.image_url || 'https://via.placeholder.com/150'} alt={product.name} className="w-40 h-40 object-cover rounded-lg shadow-md" />
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-4 text-sm">
                    <p><strong>ID:</strong> {product.id}</p>
                    <p><strong>Marca:</strong> {product.brand || 'N/A'}</p>
                    <p><strong>Categoría:</strong> {product.category_icon} {product.category_name}</p>
                    <p><strong>Código de Barras:</strong> {product.barcode || 'N/A'}</p>
                    <p><strong>Precio:</strong> ${product.price?.toFixed(2)}</p>
                    <p><strong>Stock Actual:</strong> {product.stock_quantity} {product.weight_unit || ''}</p>
                    <p><strong>Stock Mínimo:</strong> {product.min_stock_alert}</p>
                    <p><strong>Estado:</strong> <span className={`px-2 py-1 text-xs font-semibold rounded-full ${getStockStatusUI(product).bg} ${getStockStatusUI(product).color}`}>{getStockStatusUI(product).label}</span></p>
                    <p><strong>Valor de Stock:</strong> ${(product.price * product.stock_quantity).toFixed(2)}</p>
                    <p><strong>Destacado:</strong> {product.is_featured ? 'Sí' : 'No'}</p>
                    <p><strong>Disponible:</strong> {product.is_available ? 'Sí' : 'No'}</p>
                    <p><strong>Creado:</strong> {formatDate(product.created_at)}</p>
                    <p><strong>Última Actualización:</strong> {formatDate(product.updated_at)}</p>
                    {product.weight_value && <p><strong>Peso/Volumen:</strong> {product.weight_value} {product.weight_unit}</p>}
                </div>

                {product.description && (
                    <div>
                        <h4 className="font-semibold mt-2">Descripción:</h4>
                        <p className="text-sm text-gray-700 whitespace-pre-wrap">{product.description}</p>
                    </div>
                )}

                {product.meta_keywords && (
                     <div>
                        <h4 className="font-semibold mt-2">Palabras Clave:</h4>
                        <p className="text-sm text-gray-600">{product.meta_keywords}</p>
                    </div>
                )}


                {product.stock_history && product.stock_history.length > 0 && (
                    <div className="mt-4">
                        <h4 className="font-semibold mb-2">Historial de Stock Reciente (últimos 10):</h4>
                        <ul className="space-y-2 max-h-60 overflow-y-auto text-xs border rounded-md p-2">
                            {product.stock_history.map(entry => (
                                <li key={entry.id} className="p-2 bg-gray-50 rounded-md">
                                    <div className="flex justify-between items-center">
                                        <span className={`font-medium ${entry.movement_type === 'in' ? 'text-green-600' : 'text-red-600'}`}>
                                            {entry.movement_type === 'in' ? '+' : '-'}{entry.quantity_change}
                                        </span>
                                        <span className="text-gray-500">{formatDate(entry.created_at)}</span>
                                    </div>
                                    <p className="text-gray-700">Razón: {entry.reason || 'N/A'}</p>
                                    <p className="text-gray-500">Stock: {entry.quantity_before} → {entry.quantity_after}</p>
                                    {entry.user_name && <p className="text-gray-500">Usuario: {entry.user_name}</p>}
                                </li>
                            ))}
                        </ul>
                    </div>
                )}
                 {product.recent_sales && product.recent_sales.length > 0 && (
                    <div className="mt-4">
                        <h4 className="font-semibold mb-2">Ventas Recientes (últimos 30 días):</h4>
                         <ul className="space-y-2 max-h-60 overflow-y-auto text-xs border rounded-md p-2">
                            {product.recent_sales.map(sale => (
                                <li key={sale.id} className="p-2 bg-blue-50 rounded-md">
                                    <p>Orden ID: {sale.order_id} - Cantidad: {sale.quantity}</p>
                                    <p className="text-gray-500">Fecha: {formatDate(sale.created_at)}</p>
                                </li>
                            ))}
                        </ul>
                    </div>
                )}

                <div className="flex justify-end mt-6">
                    <button onClick={onClose} className="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700">
                        Cerrar
                    </button>
                </div>
            </div>
        </Modal>
    );
};

// Función para obtener clases de UI para el estado del stock
const getStockStatusUI = (product) => {
    if (!product || typeof product.stock_quantity === 'undefined' || typeof product.min_stock_alert === 'undefined') {
      return { color: 'text-gray-500', bg: 'bg-gray-100', label: 'N/A' };
    }
    if (!product.is_available) {
      return { color: 'text-gray-500', bg: 'bg-gray-100', label: 'No Disponible' };
    }
    if (product.stock_quantity === 0) {
      return { color: 'text-red-600', bg: 'bg-red-100', label: 'Sin Stock' };
    }
    if (product.stock_quantity <= product.min_stock_alert) {
      return { color: 'text-orange-600', bg: 'bg-orange-100', label: 'Stock Bajo' };
    }
    return { color: 'text-green-600', bg: 'bg-green-100', label: 'Normal' };
};

// Componente Principal
function StockManagementApp() {
  const [user, setUser] = useState(null);
  const [appLoading, setAppLoading] = useState(true);
  const [dataLoading, setDataLoading] = useState(false);

  const handleAuthError = useCallback(() => {
    setUser(null);
  }, []);

  useEffect(() => {
    window.addEventListener('authError', handleAuthError);
    return () => {
      window.removeEventListener('authError', handleAuthError);
    };
  }, [handleAuthError]);

  // Verificar autenticación al cargar
  useEffect(() => {
    const token = localStorage.getItem('token');
    if (token) {
      // Si es un token de prueba, no hacer petición al backend
      if (token.startsWith('test-jwt-token-')) {
        const testUser = {
          name: 'Usuario de Prueba',
          email: 'test@example.com',
          role: 'admin',
          picture: null
        };
        setUser(testUser);
        setAppLoading(false);
        return;
      }
      
      // Token real, verificar con el backend
      axios.get('/auth/verify')
        .then(response => {
          setUser(response.data.user);
        })
        .catch(() => {
          localStorage.removeItem('token');
          setUser(null);
        })
        .finally(() => {
          setAppLoading(false);
        });
    } else {
      setAppLoading(false);
    }
  }, []);

  // Función de login
  const handleLogin = async (credential, testUser = null, testToken = null) => {
    try {
      // Si es modo de prueba (testUser y testToken están definidos)
      if (testUser && testToken) {
        setUser(testUser);
        toast.success(`¡Bienvenido, ${testUser.name}! (Modo de prueba)`);
        return;
      }
      
      // Modo normal con Google OAuth
      const response = await axios.post('/auth/google', { credential });
      const { token, user: loggedUser } = response.data;
      localStorage.setItem('token', token);
      setUser(loggedUser);
      toast.success(`¡Bienvenido, ${loggedUser.name}!`);
    } catch (error) {
      console.error('Error en login:', error);
      toast.error(error.response?.data?.error || 'Error al iniciar sesión. Verifica tus permisos.');
    }
  };

  // Función de logout
  const handleLogout = () => {
    localStorage.removeItem('token');
    setUser(null);
    toast.success('Sesión cerrada correctamente');
  };

  // Renderizado condicional mientras se verifica la autenticación
  if (appLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-100">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
        <p className="ml-4 text-lg text-gray-700">Verificando sesión...</p>
      </div>
    );
  }

  // Si no hay usuario, mostrar login
  if (!user) {
    return <LoginPage onLogin={handleLogin} />;
  }

  // Dashboard principal (versión simplificada para testing)
  return (
    <div className="min-h-screen bg-gray-100">
      <Toaster position="top-right" containerClassName="text-sm"/>
      
      {/* Header simple */}
      <header className="bg-white shadow-sm border-b">
        <div className="px-4 sm:px-6 lg:px-8 py-4 flex items-center justify-between">
          <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
          <div className="flex items-center gap-3">
            {user.picture ? (
                <img src={user.picture} alt={user.name} className="w-10 h-10 rounded-full" />
            ) : (
                <div className="w-10 h-10 rounded-full bg-indigo-500 text-white flex items-center justify-center text-lg font-semibold">
                    {user.name?.charAt(0).toUpperCase()}
                </div>
            )}
            <div>
                <p className="text-sm font-semibold text-gray-900">{user.name}</p>
                <p className="text-xs text-gray-500 capitalize">{user.role}</p>
            </div>
            <button
              onClick={handleLogout}
              className="p-2 hover:bg-red-100 text-gray-500 hover:text-red-600 rounded-lg"
              title="Cerrar sesión"
            >
              <LogOut className="w-5 h-5" />
            </button>
          </div>
        </div>
      </header>

      {/* Contenido principal */}
      <main className="p-8">
        <div className="max-w-7xl mx-auto">
          <Dashboard />
        </div>
      </main>
    </div>
  );
}

export default StockManagementApp;