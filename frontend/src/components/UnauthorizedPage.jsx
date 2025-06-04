import React from 'react';
import { ShieldOff, Mail, ArrowLeft, AlertTriangle } from 'lucide-react';
import { useLocation, useNavigate } from 'react-router-dom';

const UnauthorizedPage = () => {
  const location = useLocation();
  const navigate = useNavigate();
  
  // Intentar obtener el email del estado o parámetros URL
  const attemptedEmail = location.state?.email || 
                        new URLSearchParams(location.search).get('email') || 
                        localStorage.getItem('attempted_email');

  const handleContactAdmin = () => {
    const subject = encodeURIComponent('Solicitud de Acceso - Stock Manager Pro');
    const body = encodeURIComponent(
      `Hola,\n\nMe gustaría solicitar acceso al sistema Stock Manager Pro.\n\n` +
      `Email: ${attemptedEmail || 'mi-email@empresa.com'}\n\n` +
      `Por favor, envíenme una invitación para acceder al sistema.\n\n` +
      `Gracias.`
    );
    
    // Usar el email de administrador desde variables de entorno o uno por defecto
    const adminEmail = process.env.REACT_APP_ADMIN_EMAIL || 'admin@empresa.com';
    window.open(`mailto:${adminEmail}?subject=${subject}&body=${body}`);
  };

  const handleBackToLogin = () => {
    // Limpiar cualquier dato de sesión
    localStorage.removeItem('attempted_email');
    localStorage.removeItem('token');
    
    // Volver al login
    navigate('/');
  };

  const handleTryAgain = () => {
    // Volver al login para intentar con otro email
    navigate('/', { state: { retry: true } });
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-white rounded-xl shadow-xl p-8 text-center border border-gray-200">
        {/* Icono principal */}
        <div className="mb-6">
          <div className="w-20 h-20 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <ShieldOff className="w-10 h-10 text-red-600" />
          </div>
        </div>
        
        {/* Título */}
        <h1 className="text-2xl font-bold text-gray-900 mb-2">
          Acceso No Autorizado
        </h1>
        
        {/* Mensaje principal */}
        <div className="mb-6">
          {attemptedEmail ? (
            <p className="text-gray-600">
              El email <span className="font-semibold text-gray-800">{attemptedEmail}</span> no está 
              autorizado para acceder a Stock Manager Pro.
            </p>
          ) : (
            <p className="text-gray-600">
              Tu cuenta no está autorizada para acceder a este sistema.
            </p>
          )}
        </div>
        
        {/* Información adicional */}
        <div className="bg-amber-50 border border-amber-200 rounded-lg p-4 mb-6">
          <div className="flex items-start gap-3">
            <AlertTriangle className="w-5 h-5 text-amber-600 flex-shrink-0 mt-0.5" />
            <div className="text-left">
              <p className="text-sm text-amber-800 font-medium mb-1">
                ¿Necesitas acceso?
              </p>
              <p className="text-sm text-amber-700">
                Si crees que deberías tener acceso, contacta al administrador del sistema 
                para solicitar una invitación.
              </p>
            </div>
          </div>
        </div>
        
        {/* Lista de pasos para obtener acceso */}
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6 text-left">
          <p className="text-sm font-medium text-blue-900 mb-2">Para obtener acceso:</p>
          <ol className="text-sm text-blue-800 space-y-1">
            <li>1. Contacta al administrador usando el botón de abajo</li>
            <li>2. Proporciona tu email y motivo de acceso</li>
            <li>3. Espera la invitación por email</li>
            <li>4. Sigue las instrucciones del email de invitación</li>
          </ol>
        </div>
        
        {/* Botones de acción */}
        <div className="space-y-3">
          <button
            onClick={handleContactAdmin}
            className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors duration-200 font-medium"
          >
            <Mail className="w-4 h-4" />
            Contactar Administrador
          </button>
          
          <button
            onClick={handleTryAgain}
            className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors duration-200 font-medium"
          >
            <ArrowLeft className="w-4 h-4" />
            Intentar con Otra Cuenta
          </button>
          
          <button
            onClick={handleBackToLogin}
            className="w-full flex items-center justify-center gap-2 px-4 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors duration-200"
          >
            Volver al Inicio
          </button>
        </div>
        
        {/* Footer */}
        <div className="mt-8 pt-6 border-t border-gray-200">
          <p className="text-xs text-gray-500">
            Stock Manager Pro - Sistema de Gestión de Inventario
          </p>
        </div>
      </div>
    </div>
  );
};

export default UnauthorizedPage; 