import axios from 'axios';
import { toast } from 'react-hot-toast';

// Configuración de axios
const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:3001/api';

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

export default axios; 