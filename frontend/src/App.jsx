// frontend/src/App.jsx
import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { GoogleOAuthProvider, GoogleLogin } from '@react-oauth/google';
import axios from 'axios';
import { Toaster, toast } from 'react-hot-toast';
import {
  Search, Package, AlertCircle, TrendingUp, TrendingDown, Edit, Save, X, Plus, Filter,
  BarChart3, ShoppingCart, DollarSign, Bell, LogOut, Menu, Download, RefreshCw,
  Camera, Trash2, Eye, Clock, User, ChevronLeft, ChevronRight, ChevronsLeft, ChevronsRight,
  UploadCloud, Image as ImageIcon, XCircle, EyeOff, Settings, Users, FileText, HelpCircle
} from 'lucide-react';
import { format, parseISO, subDays, startOfDay, endOfDay } from 'date-fns';
import { es } from 'date-fns/locale';

// Importar componentes de vistas
import DashboardComponent from './components/Dashboard'; // El Dashboard.jsx actual
import InventoryView from './components/InventoryView'; // Se acaba de crear
import AlertsView from './components/AlertsView'; // Importar AlertsView
// import AlertsView from './components/AlertsView'; // Se creará después

// FORZANDO API_URL PARA DIAGNÓSTICO (TEMPORAL)
console.log('[DIAGNÓSTICO] VITE_API_URL desde import.meta.env:', import.meta.env.VITE_API_URL);
const API_URL = 'http://localhost:4000/api'; // <-- ¡FORZADO TEMPORALMENTE!
console.log('[DIAGNÓSTICO] API_URL efectiva (forzada):', API_URL);

// Configuración de axios
// const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001/api'; // LÍNEA ORIGINAL COMENTADA
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
    if (error.response && (error.response.status === 401 || error.response.status === 403)) {
      const errorMessage = error.response?.data?.error;
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
  const handleTestLogin = async () => {
    alert('[DIAGNÓSTICO SUPER-TEST] ¡Ejecutando la versión más reciente de handleTestLogin!');
    try {
      // FORZANDO URL DIRECTAMENTE PARA TEST LOGIN (TEMPORAL)
      console.log('[DIAGNÓSTICO LoginPage] API_URL global es:', API_URL);
      const testLoginUrl = 'http://localhost:4000/api/auth/test-login';
      console.log('[DIAGNÓSTICO LoginPage] Usando URL para test-login:', testLoginUrl);
      const response = await fetch(testLoginUrl, { 
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      });
      const data = await response.json();
      if (data.success) {
        localStorage.setItem('token', data.token);
        onLogin(null, data.user, data.token);
      } else {
        toast.error(data.error || 'Error en login de prueba');
        console.error('Error en login de prueba:', data.error);
      }
    } catch (error) {
      toast.error('Error conectando al backend de prueba.');
      console.error('Error conectando al backend de prueba:', error);
    }
  };

  if (!GOOGLE_CLIENT_ID) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-red-50 to-orange-100 flex items-center justify-center p-4">
        <div className="bg-white rounded-2xl shadow-xl p-8 max-w-md w-full text-center">
          <AlertCircle className="w-12 h-12 text-orange-500 mx-auto mb-4" />
          <h1 className="text-2xl font-bold text-gray-800 mb-2">Modo de Desarrollo</h1>
          <p className="text-gray-600 mb-6">
            <code>VITE_GOOGLE_CLIENT_ID</code> no está configurada.
          </p>
          <button
            onClick={handleTestLogin}
            className="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-medium py-3 px-4 rounded-lg transition-colors shadow-sm mb-4"
          >
            🧪 Entrar como Usuario de Prueba
          </button>
          <p className="text-xs text-gray-500">
            Este botón solo aparece si Google Client ID no está configurado.
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
        if (isOpen) { // Reset form only when modal opens
            if (product) {
                setFormData({ ...product, category_id: product.category_id || '' });
                setImagePreview(product.image_url ? `${API_URL.replace('/api', '')}${product.image_url}` : null);
            } else {
                setFormData({
                    name: '', description: '', price: 0, stock_quantity: 0, min_stock_alert: 0,
                    category_id: categories.length > 0 ? categories[0].id : '',
                    brand: '', barcode: '', weight_unit: 'unidad', weight_value: 0,
                    is_featured: false, is_available: true, meta_keywords: ''
                });
                setImagePreview(null);
            }
            setImageFile(null);
        }
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
            reader.onloadend = () => setImagePreview(reader.result);
            reader.readAsDataURL(file);
        }
    };

    const handleSubmit = (e) => {
        e.preventDefault();
        const dataToSubmit = new FormData();
        for (const key in formData) {
            if (key !== 'image_url' && key !== 'category_name' && key !== 'category_icon' && key !== 'stock_status' && key !== 'total_count' && key !== 'id' && key !== 'created_at' && key !== 'updated_at' && key !== 'stock_history' && key !== 'recent_sales') {
                 dataToSubmit.append(key, formData[key]);
            }
        }
        if (imageFile) {
            dataToSubmit.append('image', imageFile);
        } else if (formData.image_url === null && product?.image_url) { // Image was removed
            dataToSubmit.append('delete_image', 'true');
        }
        onSave(dataToSubmit, product?.id);
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
                        <input type="file" name="image" id="product_image_upload" onChange={handleImageChange} accept="image/jpeg,image/png,image/webp" className="hidden"/>
                        <button type="button" onClick={() => document.getElementById('product_image_upload').click()} className="px-3 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 hover:bg-gray-50">
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
                        <input type="checkbox" name="is_available" checked={formData.is_available === undefined ? true : formData.is_available} onChange={handleChange} className="h-4 w-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500"/>
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

    const stockStatusUI = getStockStatusUI(product); // Usar la función global

    return (
        <Modal isOpen={isOpen} onClose={onClose} title={`Detalles de: ${product.name}`}>
            <div className="space-y-4">
                <div className="flex justify-center mb-4">
                    <img 
                        src={product.image_url ? `${API_URL.replace('/api', '')}${product.image_url}` : 'https://via.placeholder.com/150'} 
                        alt={product.name} 
                        className="w-40 h-40 object-cover rounded-lg shadow-md" 
                        onError={(e) => e.target.src='https://via.placeholder.com/150'} // Fallback si la imagen no carga
                    />
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-4 text-sm">
                    <p><strong>ID:</strong> {product.id}</p>
                    <p><strong>Marca:</strong> {product.brand || 'N/A'}</p>
                    <p><strong>Categoría:</strong> {product.category_icon} {product.category_name}</p>
                    <p><strong>Código de Barras:</strong> {product.barcode || 'N/A'}</p>
                    <p><strong>Precio:</strong> ${product.price?.toFixed(2)}</p>
                    <p><strong>Stock Actual:</strong> {product.stock_quantity} {product.weight_unit || ''}</p>
                    <p><strong>Stock Mínimo:</strong> {product.min_stock_alert}</p>
                    <p><strong>Estado:</strong> <span className={`px-2 py-1 text-xs font-semibold rounded-full ${stockStatusUI.bg} ${stockStatusUI.color}`}>{stockStatusUI.label}</span></p>
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
    if (!product || typeof product.stock_quantity === 'undefined') {
      return { color: 'text-gray-500', bg: 'bg-gray-100', label: 'N/A' };
    }
    if (!product.is_available) {
      return { color: 'text-gray-500', bg: 'bg-gray-100', label: 'No Disp.' };
    }
    if (product.stock_quantity === 0) {
      return { color: 'text-red-600', bg: 'bg-red-100', label: 'Sin Stock' };
    }
    if (typeof product.min_stock_alert !== 'undefined' && product.stock_quantity <= product.min_stock_alert) {
      return { color: 'text-orange-600', bg: 'bg-orange-100', label: 'Stock Bajo' };
    }
    return { color: 'text-green-600', bg: 'bg-green-100', label: 'Normal' };
};

// Componente Principal
function StockManagementApp() {
  const [user, setUser] = useState(null);
  const [appLoading, setAppLoading] = useState(true);
  const [dataLoading, setDataLoading] = useState(false);

  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [activeView, setActiveView] = useState('dashboard'); // 'dashboard', 'inventory', 'alerts'

  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [stats, setStats] = useState({ 
    totalProducts: 0,
    totalValue: 0,
    lowStockCount: 0,
    outOfStockCount: 0,
    stockAlerts: [], // <-- Asegurar que stockAlerts esté inicializado como array
    // ...otras stats que pueda tener el dashboard
  });
  const [filters, setFilters] = useState({
    search: '',
    category: '',
    lowStock: false, // Para la vista de inventario
    page: 1,
    limit: 10, // Paginación
    sortBy: 'created_at',
    sortOrder: 'DESC',
    // Para el dashboard, el rango de fechas se maneja en DashboardComponent
  });
  const [pagination, setPagination] = useState({ page: 1, limit: 10, total: 0, totalPages: 0 });
  
  const [showProductFormModal, setShowProductFormModal] = useState(false);
  const [selectedProductForModal, setSelectedProductForModal] = useState(null); // Para editar o crear
  const [showProductDetailModal, setShowProductDetailModal] = useState(false);
  const [selectedProductForDetail, setSelectedProductForDetail] = useState(null);

  const handleAuthError = useCallback(() => {
    setUser(null);
    localStorage.removeItem('token');
  }, []);

  useEffect(() => {
    window.addEventListener('authError', handleAuthError);
    return () => window.removeEventListener('authError', handleAuthError);
  }, [handleAuthError]);

  // Verificar autenticación al cargar
  useEffect(() => {
    setAppLoading(true);
    const token = localStorage.getItem('token');
    if (token) {
      if (token.startsWith('test-jwt-token-')) { // Manejo de token de prueba
        try {
            const pseudoUser = JSON.parse(atob(token.split('.')[1])); // Decodificar payload para test user
             setUser({ name: pseudoUser.name || 'Usuario de Prueba', email: pseudoUser.email || 'test@example.com', role: pseudoUser.role || 'admin', picture: pseudoUser.picture || null });
        } catch (e) {
             setUser({ name: 'Usuario de Prueba', email: 'test@example.com', role: 'admin', picture: null });
        }
        setAppLoading(false);
        return;
      }
      axios.get('/auth/verify')
        .then(response => setUser(response.data.user))
        .catch(() => {
          localStorage.removeItem('token');
          setUser(null);
        })
        .finally(() => setAppLoading(false));
    } else {
      setAppLoading(false);
    }
  }, []);

  // Cargar datos principales
  const loadData = useCallback(async (forceStatsReload = false) => {
    if (!user) return;
    setDataLoading(true);
    try {
      const requests = [];
      
      // Cargar categorías si no están o se fuerza (aunque categories.length chequea esto ya)
      if (!categories.length) {
           requests.push(axios.get('/categories'));
      }

      // Cargar productos para la vista de inventario
      if (activeView === 'inventory') {
        const productParams = { 
            page: filters.page, 
            limit: filters.limit,
            search: filters.search,
            category_id: filters.category,
            low_stock: filters.lowStock,
            sort_by: filters.sortBy,
            sort_order: filters.sortOrder,
        };
        requests.push(axios.get('/products', { params: productParams }));
      }
      
      // Cargar stats para dashboard o alertas, o si se fuerza la recarga
      // El DashboardComponent ya no cargará sus propios stats, los recibirá de App.jsx
      if (activeView === 'dashboard' || activeView === 'alerts' || forceStatsReload || !stats.totalProducts) { // Cargar si no hay stats o se fuerza
         requests.push(axios.get('/dashboard/stats'));
      }
      
      const responses = await Promise.all(requests);
      
      responses.forEach(response => {
        const url = response.config.url;
        if (url.includes('/categories')) {
          setCategories(response.data.data || []);
        }
        if (url.includes('/products')) {
          setProducts(response.data.data || []);
          setPagination(response.data.pagination || { page: 1, limit: 10, total: 0, totalPages: 0 });
        }
        if (url.includes('/dashboard/stats')) {
          setStats(prevStats => ({ ...prevStats, ...(response.data.data || {}) }));
        }
      });

    } catch (error) {
      console.error('Error cargando datos:', error);
      toast.error(error.response?.data?.error || 'Error al cargar los datos');
    } finally {
      setDataLoading(false);
    }
  }, [user, activeView, filters, categories.length, stats.totalProducts]); // stats.totalProducts para recargar si cambia una stat clave

  useEffect(() => {
    if (user) {
      // Cargar categorías siempre una vez si no están
      if (!categories.length) loadData(); 
      // Cargar datos específicos de la vista o stats si es necesario
      if (activeView === 'inventory') {
        loadData();
      } else if (activeView === 'dashboard' || activeView === 'alerts') {
        // Cargar stats si aún no se han cargado (totalProducts es un indicador)
        if (!stats.totalProducts) {
            loadData();
        }
      }
    }
  }, [user, activeView, categories.length, stats.totalProducts, loadData]); // loadData ahora es una dependencia clave


  const handleLogin = async (credential, testUser = null, testToken = null) => {
    setAppLoading(true);
    try {
      if (testUser && testToken) { // Login de prueba
        setUser(testUser);
        localStorage.setItem('token', testToken); // Guardar token de prueba
        toast.success(`¡Bienvenido, ${testUser.name}! (Modo de prueba)`);
        setAppLoading(false);
        return;
      }
      // Login con Google
      const response = await axios.post('/auth/google', { credential });
      const { token, user: loggedUser } = response.data;
      localStorage.setItem('token', token);
      setUser(loggedUser);
      toast.success(`¡Bienvenido, ${loggedUser.name}!`);
    } catch (error) {
      console.error('Error en login:', error);
      toast.error(error.response?.data?.error || 'Error al iniciar sesión.');
    } finally {
        setAppLoading(false);
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('token');
    setUser(null);
    setProducts([]); // Limpiar datos
    setCategories([]);
    setStats({ 
      totalProducts: 0,
      totalValue: 0,
      lowStockCount: 0,
      outOfStockCount: 0,
      stockAlerts: [],
    });
    setActiveView('dashboard'); // Resetear vista
    toast.success('Sesión cerrada correctamente');
  };
  
  // Funciones CRUD
  const handleSaveProduct = async (formData, productId) => {
    setDataLoading(true);
    try {
      const method = productId ? 'put' : 'post';
      const url = productId ? `/products/${productId}` : '/products';
      // console.log('Saving product:', url, Object.fromEntries(formData));
      
      await axios({ method, url, data: formData, headers: {'Content-Type': 'multipart/form-data'} });
      
      toast.success(`Producto ${productId ? 'actualizado' : 'creado'} correctamente`);
      setShowProductFormModal(false);
      setSelectedProductForModal(null);
      await loadData(true); // true para forzar recarga de stats
    } catch (error) {
      console.error('Error guardando producto:', error.response?.data || error.message);
      toast.error(error.response?.data?.error || error.response?.data?.details?.[0]?.msg || 'Error al guardar el producto');
    } finally {
      setDataLoading(false);
    }
  };

  const handleUpdateStock = async (productId, quantityChange, movementType, reason) => {
    setDataLoading(true);
    try {
      await axios.post(`/products/${productId}/stock`, {
        quantity_change: quantityChange,
        movement_type: movementType, 
        reason: reason,
      });
      toast.success(`Stock actualizado para el producto.`);
      // Forzar recarga de datos y stats para reflejar el cambio en todas las vistas.
      await loadData(true); 
    } catch (error) {
      console.error('Error actualizando stock:', error.response?.data || error.message);
      toast.error(error.response?.data?.error || error.response?.data?.details?.[0]?.msg || 'Error al actualizar el stock');
    } finally {
      setDataLoading(false);
    }
  };

  const handleExportReport = async (format = 'csv') => {
    // Usaremos los filtros actuales de la vista de inventario para la exportación
    setDataLoading(true);
    try {
      const params = {
        page: 1, // Podríamos querer todos los productos, no solo la página actual
        limit: 0, // 0 o un número muy grande para "todos", o el backend debe soportar 'all'
        search: filters.search,
        category_id: filters.category,
        low_stock: filters.lowStock,
        sort_by: filters.sortBy,
        sort_order: filters.sortOrder,
        export_format: format,
      };
      
      // El endpoint del backend /products debería soportar un query param como ?export=csv
      // y devolver el archivo directamente o un JSON con la data para generar el CSV en frontend.
      // Para este ejemplo, asumiremos que el backend devuelve el archivo directamente.
      const response = await axios.get('/products', { 
          params: { ...params, export: format }, 
          responseType: 'blob', // Importante para manejar la descarga de archivos
      });

      const blob = new Blob([response.data], { type: response.headers['content-type'] });
      const link = document.createElement('a');
      link.href = window.URL.createObjectURL(blob);
      
      let filename = `reporte_inventario_${new Date().toISOString().split('T')[0]}.${format}`;
      const contentDisposition = response.headers['content-disposition'];
      if (contentDisposition) {
        const filenameMatch = contentDisposition.match(/filename="?(.+)"?/i);
        if (filenameMatch && filenameMatch.length === 2)
          filename = filenameMatch[1];
      }
      link.download = filename;
      link.click();
      window.URL.revokeObjectURL(link.href);
      toast.success('Reporte exportado correctamente.');

    } catch (error) {
      console.error('Error exportando reporte:', error);
      toast.error(error.response?.data?.error || 'Error al exportar el reporte. Asegúrese que el backend soporta esta función.');
    } finally {
      setDataLoading(false);
    }
  };

  const openNewProductModal = () => {
    setSelectedProductForModal(null);
    setShowProductFormModal(true);
  };

  const openEditProductModal = (product) => {
    setSelectedProductForModal(product);
    setShowProductFormModal(true);
  };
  
  const openDetailProductModal = (product) => {
    setSelectedProductForDetail(product);
    setShowProductDetailModal(true);
  };


  // Renderizado condicional
  if (appLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-100">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
        <p className="ml-4 text-lg text-gray-700">Verificando sesión...</p>
      </div>
    );
  }

  if (!user) {
    return <LoginPage onLogin={handleLogin} />;
  }

  // Layout principal con Sidebar y Header
  return (
    <div className="min-h-screen bg-gray-100 flex">
      <Toaster position="top-right" containerClassName="text-sm" />
      
      {/* Sidebar */}
      <aside className={`${sidebarOpen ? 'w-64' : 'w-20'} bg-white shadow-lg transition-all duration-300 flex flex-col`}>
        <div className="p-4">
          <div className={`flex items-center ${sidebarOpen ? 'justify-between' : 'justify-center'} mb-8`}>
            {sidebarOpen && (
              <div className="flex items-center gap-2">
                <ShoppingCart className="w-8 h-8 text-indigo-600" />
                <h2 className="text-xl font-bold text-gray-900">StockPro</h2>
              </div>
            )}
            <button
              onClick={() => setSidebarOpen(!sidebarOpen)}
              className="p-2 hover:bg-gray-100 rounded-lg"
            >
              <Menu className="w-6 h-6 text-gray-700" />
            </button>
          </div>
          
          <nav className="space-y-2">
            {[
              { view: 'dashboard', label: 'Dashboard', icon: BarChart3 },
              { view: 'inventory', label: 'Inventario', icon: Package },
              { view: 'alerts', label: 'Alertas', icon: Bell },
              // Añadir más vistas si es necesario
            ].map(item => (
              <button
                key={item.view}
                onClick={() => setActiveView(item.view)}
                title={item.label}
                className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg transition-colors text-gray-700 ${
                  activeView === item.view ? 'bg-indigo-50 text-indigo-600 font-semibold' : 'hover:bg-gray-100'
                } ${!sidebarOpen && 'justify-center'}`}
              >
                <item.icon className={`w-5 h-5 ${activeView === item.view ? 'text-indigo-600' : 'text-gray-500'}`} />
                {sidebarOpen && <span>{item.label}</span>}
              </button>
            ))}
          </nav>
        </div>
        
        <div className="mt-auto p-4 border-t border-gray-200">
          <div className={`flex items-center gap-3 ${!sidebarOpen && 'justify-center'}`}>
            {user.picture ? (
                <img src={user.picture} alt={user.name} className="w-10 h-10 rounded-full" />
            ) : (
                <div className="w-10 h-10 rounded-full bg-indigo-500 text-white flex items-center justify-center text-lg font-semibold">
                    {user.name?.charAt(0).toUpperCase()}
                </div>
            )}
            {sidebarOpen && (
              <div className="flex-1 overflow-hidden">
                <p className="text-sm font-medium text-gray-900 truncate">{user.name}</p>
                <p className="text-xs text-gray-500 capitalize">{user.role}</p>
              </div>
            )}
            {sidebarOpen && (
                 <button onClick={handleLogout} className="p-2 hover:bg-red-100 text-gray-500 hover:text-red-600 rounded-lg" title="Cerrar sesión">
                    <LogOut className="w-5 h-5" />
                 </button>
            )}
          </div>
           {!sidebarOpen && (
                <button onClick={handleLogout} className="w-full mt-2 p-2 hover:bg-red-100 text-gray-500 hover:text-red-600 rounded-lg flex justify-center" title="Cerrar sesión">
                    <LogOut className="w-5 h-5" />
                </button>
            )}
        </div>
      </aside>

      {/* Contenido principal */}
      <main className="flex-1 overflow-auto">
        <header className="bg-white shadow-sm border-b sticky top-0 z-40">
          <div className="px-6 py-4 flex items-center justify-between">
            <h1 className="text-2xl font-bold text-gray-900">
              {activeView === 'dashboard' && 'Dashboard General'}
              {activeView === 'inventory' && 'Gestión de Inventario'}
              {activeView === 'alerts' && 'Alertas de Stock'}
            </h1>
            
            <div className="flex items-center gap-4">
              <button onClick={() => loadData()} className="p-2 hover:bg-gray-100 rounded-lg" title="Actualizar Datos">
                <RefreshCw className={`w-5 h-5 ${dataLoading ? 'animate-spin' : ''}`} />
              </button>
              
              {activeView === 'inventory' && user.role !== 'viewer' && ( // Solo admin/editor pueden crear
                <button
                  onClick={openNewProductModal}
                  className="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white hover:bg-indigo-700 rounded-lg transition-colors"
                >
                  <Plus className="w-4 h-4" />
                  Nuevo Producto
                </button>
              )}
              {activeView === 'inventory' && (
                <button
                  onClick={() => handleExportReport('csv')}
                  disabled={dataLoading}
                  className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white hover:bg-green-700 rounded-lg transition-colors disabled:opacity-50"
                >
                  <Download className="w-4 h-4" />
                  Exportar CSV
                </button>
              )}
            </div>
          </div>
        </header>

        <div className="p-6">
          {activeView === 'dashboard' && <DashboardComponent stats={stats} isLoading={dataLoading} />}
          {activeView === 'inventory' && 
            <InventoryView 
              products={products}
              categories={categories}
              filters={filters}
              setFilters={setFilters}
              pagination={pagination}
              onEdit={openEditProductModal}
              onDetail={openDetailProductModal}
              userRole={user?.role}
              getStockStatusUI={getStockStatusUI}
              API_URL={API_URL}
              dataLoading={dataLoading}
            />
          }
          {activeView === 'alerts' && 
            <AlertsView 
                userRole={user?.role}
                onProductDetail={openDetailProductModal}
                API_URL={API_URL}
                onUpdateStock={handleUpdateStock}
                stockAlerts={stats.stockAlerts || []}
                isLoading={dataLoading}
            />
          }
        </div>
      </main>

      {/* Modales */}
      {showProductFormModal && (
        <ProductFormModal
          isOpen={showProductFormModal}
          onClose={() => { setShowProductFormModal(false); setSelectedProductForModal(null); }}
          product={selectedProductForModal}
          categories={categories}
          onSave={handleSaveProduct}
          loading={dataLoading}
        />
      )}

      {showProductDetailModal && selectedProductForDetail && (
        <ProductDetailModal
          isOpen={showProductDetailModal}
          onClose={() => { setShowProductDetailModal(false); setSelectedProductForDetail(null); }}
          product={selectedProductForDetail}
        />
      )}
    </div>
  );
}

export default StockManagementApp;