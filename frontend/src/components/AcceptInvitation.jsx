import React, { useState, useEffect } from 'react';
import { useSearchParams, useNavigate } from 'react-router-dom';
import { CheckCircle, XCircle, Loader2, Mail, Building2, UserCheck } from 'lucide-react';
import { GoogleLogin } from '@react-oauth/google';

const AcceptInvitation = () => {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const [invitationData, setInvitationData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [accepting, setAccepting] = useState(false);
  
  const token = searchParams.get('token');

  useEffect(() => {
    if (!token) {
      setError('Token de invitación no proporcionado');
      setLoading(false);
      return;
    }

    validateInvitation();
  }, [token]);

  const validateInvitation = async () => {
    try {
      setLoading(true);
      setError(null);

      const response = await fetch(`${process.env.REACT_APP_API_URL}/api/auth/validate-invitation/${token}`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Error validando invitación');
      }

      setInvitationData(data.invitation);
    } catch (err) {
      console.error('Error validating invitation:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleGoogleSuccess = async (credentialResponse) => {
    try {
      setAccepting(true);
      setError(null);

      const response = await fetch(`${process.env.REACT_APP_API_URL}/api/auth/accept-invitation`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          token: token,
          credential: credentialResponse.credential,
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Error aceptando invitación');
      }

      // Guardar token y usuario
      localStorage.setItem('token', data.token);
      localStorage.setItem('user', JSON.stringify(data.user));

      // Mostrar mensaje de éxito y redirigir
      setTimeout(() => {
        navigate('/dashboard', { state: { welcomeMessage: data.message } });
      }, 2000);

    } catch (err) {
      console.error('Error accepting invitation:', err);
      setError(err.message);
      setAccepting(false);
    }
  };

  const handleGoogleError = () => {
    setError('Error de autenticación con Google. Por favor, intenta nuevamente.');
  };

  const getRoleDisplayName = (role) => {
    const roleNames = {
      viewer: 'Visualizador',
      editor: 'Editor',
      admin: 'Administrador',
      owner: 'Propietario'
    };
    return roleNames[role] || role;
  };

  const getRoleDescription = (role) => {
    const descriptions = {
      viewer: 'Podrás ver el inventario, reportes y alertas de stock',
      editor: 'Podrás gestionar productos, inventario y generar reportes',
      admin: 'Tendrás acceso completo para administrar usuarios y configuraciones',
      owner: 'Control total del sistema y gestión de la organización'
    };
    return descriptions[role] || 'Acceso básico al sistema';
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
        <div className="bg-white rounded-xl shadow-xl p-8 text-center max-w-md w-full">
          <Loader2 className="w-12 h-12 text-blue-600 mx-auto mb-4 animate-spin" />
          <h2 className="text-xl font-semibold text-gray-900 mb-2">
            Validando invitación...
          </h2>
          <p className="text-gray-600">
            Por favor, espera mientras verificamos tu invitación.
          </p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-red-50 to-pink-100 flex items-center justify-center p-4">
        <div className="bg-white rounded-xl shadow-xl p-8 text-center max-w-md w-full">
          <XCircle className="w-16 h-16 text-red-500 mx-auto mb-4" />
          <h1 className="text-2xl font-bold text-gray-900 mb-2">
            Error de Invitación
          </h1>
          <p className="text-gray-600 mb-6">
            {error}
          </p>
          <div className="space-y-3">
            <button
              onClick={() => window.location.href = '/'}
              className="w-full px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
            >
              Ir al Inicio
            </button>
            <button
              onClick={() => window.location.href = 'mailto:admin@empresa.com'}
              className="w-full px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
            >
              Contactar Soporte
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (accepting) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-green-50 to-emerald-100 flex items-center justify-center p-4">
        <div className="bg-white rounded-xl shadow-xl p-8 text-center max-w-md w-full">
          <CheckCircle className="w-16 h-16 text-green-500 mx-auto mb-4" />
          <h1 className="text-2xl font-bold text-gray-900 mb-2">
            ¡Invitación Aceptada!
          </h1>
          <p className="text-gray-600 mb-4">
            Tu cuenta ha sido activada exitosamente.
          </p>
          <div className="flex items-center justify-center gap-2 text-sm text-gray-500">
            <Loader2 className="w-4 h-4 animate-spin" />
            Redirigiendo al dashboard...
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div className="bg-white rounded-xl shadow-xl p-8 max-w-md w-full">
        {/* Header */}
        <div className="text-center mb-8">
          <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <Mail className="w-8 h-8 text-blue-600" />
          </div>
          <h1 className="text-2xl font-bold text-gray-900 mb-2">
            Aceptar Invitación
          </h1>
          <p className="text-gray-600">
            Has sido invitado a unirte a Stock Manager Pro
          </p>
        </div>

        {/* Invitation Details */}
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
          <div className="flex items-start gap-3 mb-4">
            <Building2 className="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" />
            <div>
              <p className="font-medium text-blue-900">Organización</p>
              <p className="text-blue-800">{invitationData?.organizationName}</p>
            </div>
          </div>
          
          <div className="flex items-start gap-3 mb-4">
            <UserCheck className="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" />
            <div>
              <p className="font-medium text-blue-900">Rol Asignado</p>
              <p className="text-blue-800 font-medium">
                {getRoleDisplayName(invitationData?.role)}
              </p>
              <p className="text-sm text-blue-700 mt-1">
                {getRoleDescription(invitationData?.role)}
              </p>
            </div>
          </div>

          <div className="flex items-start gap-3">
            <Mail className="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" />
            <div>
              <p className="font-medium text-blue-900">Email</p>
              <p className="text-blue-800">{invitationData?.email}</p>
            </div>
          </div>
        </div>

        {/* Instructions */}
        <div className="bg-amber-50 border border-amber-200 rounded-lg p-4 mb-6">
          <p className="text-sm text-amber-800">
            <strong>Para activar tu cuenta:</strong> Inicia sesión con tu cuenta de Google. 
            Asegúrate de usar el email <strong>{invitationData?.email}</strong> que coincida con esta invitación.
          </p>
        </div>

        {/* Google Login */}
        <div className="space-y-4">
          <GoogleLogin
            onSuccess={handleGoogleSuccess}
            onError={handleGoogleError}
            theme="filled_blue"
            size="large"
            text="continue_with"
            shape="rounded"
            width="100%"
          />
          
          {/* Expiration info */}
          {invitationData?.expiresAt && (
            <p className="text-xs text-gray-500 text-center">
              Esta invitación expira el {new Date(invitationData.expiresAt).toLocaleDateString('es-ES', {
                year: 'numeric',
                month: 'long',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
              })}
            </p>
          )}
        </div>

        {/* Footer */}
        <div className="mt-8 pt-6 border-t border-gray-200 text-center">
          <p className="text-xs text-gray-500 mb-2">
            ¿Tienes problemas? 
          </p>
          <button
            onClick={() => window.location.href = 'mailto:admin@empresa.com'}
            className="text-xs text-blue-600 hover:text-blue-700 underline"
          >
            Contactar Soporte
          </button>
        </div>
      </div>
    </div>
  );
};

export default AcceptInvitation; 