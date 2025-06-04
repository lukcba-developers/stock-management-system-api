import React, { useState, useEffect, useCallback } from 'react';
import { toast } from 'react-hot-toast';
import axios from 'axios';
import {
  Users, UserPlus, UserCheck, UserX, Settings, Edit, Trash2, 
  Search, Filter, RefreshCw, Eye, Shield, Mail, Clock,
  ChevronDown, ChevronUp, MoreVertical, CheckCircle, XCircle
} from 'lucide-react';

const UserManagement = ({ currentUser }) => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [inviteLoading, setInviteLoading] = useState(false);
  
  // Estados para invitación
  const [inviteEmail, setInviteEmail] = useState('');
  const [inviteRole, setInviteRole] = useState('viewer');
  
  // Estados para filtros
  const [searchTerm, setSearchTerm] = useState('');
  const [filterRole, setFilterRole] = useState('all');
  const [filterStatus, setFilterStatus] = useState('all'); // all, active, pending, suspended
  const [sortBy, setSortBy] = useState('created_at');
  const [sortOrder, setSortOrder] = useState('DESC');
  
  // Estados para UI
  const [showConfirmDialog, setShowConfirmDialog] = useState(false);
  const [confirmAction, setConfirmAction] = useState(null);
  const [expandedUser, setExpandedUser] = useState(null);

  // Roles disponibles
  const roles = [
    { value: 'viewer', label: 'Visualizador', color: 'bg-green-100 text-green-800' },
    { value: 'editor', label: 'Editor', color: 'bg-blue-100 text-blue-800' },
    { value: 'admin', label: 'Administrador', color: 'bg-purple-100 text-purple-800' },
    { value: 'owner', label: 'Propietario', color: 'bg-red-100 text-red-800' }
  ];

  // Estados disponibles
  const statusConfig = {
    active: { label: 'Activo', color: 'bg-green-100 text-green-800' },
    pending: { label: 'Pendiente', color: 'bg-yellow-100 text-yellow-800' },
    suspended: { label: 'Suspendido', color: 'bg-red-100 text-red-800' }
  };

  // Cargar usuarios
  const loadUsers = useCallback(async () => {
    try {
      setLoading(true);
      const params = {
        search: searchTerm,
        role: filterRole !== 'all' ? filterRole : undefined,
        status: filterStatus !== 'all' ? filterStatus : undefined,
        sortBy,
        sortOrder
      };

      const response = await axios.get('/api/admin/users', { params });
      setUsers(response.data.users || []);
    } catch (error) {
      console.error('Error loading users:', error);
      toast.error('Error al cargar usuarios');
    } finally {
      setLoading(false);
    }
  }, [searchTerm, filterRole, filterStatus, sortBy, sortOrder]);

  useEffect(() => {
    loadUsers();
  }, [loadUsers]);

  // Invitar nuevo usuario
  const inviteUser = async (e) => {
    e.preventDefault();
    setInviteLoading(true);
    
    try {
      await axios.post('/api/admin/users/invite', {
        email: inviteEmail,
        role: inviteRole
      });
      
      toast.success(`Invitación enviada a ${inviteEmail}`);
      setInviteEmail('');
      setInviteRole('viewer');
      loadUsers();
    } catch (error) {
      toast.error(error.response?.data?.error || 'Error al enviar invitación');
    } finally {
      setInviteLoading(false);
    }
  };

  // Actualizar rol de usuario
  const updateUserRole = async (userId, newRole) => {
    try {
      await axios.patch(`/api/admin/users/${userId}/role`, { role: newRole });
      toast.success('Rol actualizado correctamente');
      loadUsers();
    } catch (error) {
      console.error('Error updating user role:', error);
      toast.error('Error al actualizar el rol');
    }
  };

  // Cambiar estado del usuario
  const toggleUserStatus = async (userId, currentStatus) => {
    const newStatus = currentStatus === 'active' ? 'suspended' : 'active';
    try {
      await axios.patch(`/api/admin/users/${userId}/status`, { status: newStatus });
      toast.success(`Usuario ${newStatus === 'active' ? 'activado' : 'suspendido'} correctamente`);
      loadUsers();
    } catch (error) {
      console.error('Error updating user status:', error);
      toast.error('Error al cambiar estado del usuario');
    }
  };

  // Eliminar usuario
  const removeUser = async (userId) => {
    try {
      await axios.delete(`/api/admin/users/${userId}`);
      toast.success('Usuario eliminado correctamente');
      loadUsers();
    } catch (error) {
      console.error('Error deleting user:', error);
      toast.error('Error al eliminar usuario');
    }
  };

  // Manejar ordenamiento
  const handleSort = (field) => {
    if (sortBy === field) {
      setSortOrder(sortOrder === 'ASC' ? 'DESC' : 'ASC');
    } else {
      setSortBy(field);
      setSortOrder('ASC');
    }
  };

  // Confirmar acción
  const confirmActionHandler = (action, user) => {
    setConfirmAction({ action, user });
    setShowConfirmDialog(true);
  };

  const executeConfirmAction = () => {
    if (!confirmAction) return;

    const { action, user } = confirmAction;
    
    switch (action) {
      case 'toggleStatus':
        toggleUserStatus(user.id, user.status);
        break;
      case 'delete':
        removeUser(user.id);
        break;
      default:
        break;
    }

    setShowConfirmDialog(false);
    setConfirmAction(null);
  };

  // Filtrar usuarios
  const filteredUsers = users.filter(user => {
    const matchesSearch = user.name?.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         user.email?.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesRole = filterRole === 'all' || user.role === filterRole;
    const matchesStatus = filterStatus === 'all' || user.status === filterStatus;
    
    return matchesSearch && matchesRole && matchesStatus;
  });

  // Componente de badge de rol
  const RoleBadge = ({ role, isEditable = false, onRoleChange, userId, disabled = false }) => {
    const roleInfo = roles.find(r => r.value === role) || { label: role, color: 'bg-gray-100 text-gray-800' };
    
    if (isEditable && !disabled) {
      return (
        <select
          value={role}
          onChange={(e) => onRoleChange(userId, e.target.value)}
          className="text-sm border-0 bg-transparent focus:ring-2 focus:ring-indigo-500 rounded px-2 py-1"
        >
          {roles.map(r => (
            <option key={r.value} value={r.value}>{r.label}</option>
          ))}
        </select>
      );
    }

    return (
      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${roleInfo.color}`}>
        <Shield className="w-3 h-3 mr-1" />
        {roleInfo.label}
      </span>
    );
  };

  // Componente de badge de estado
  const StatusBadge = ({ status }) => {
    const config = statusConfig[status] || { label: status, color: 'bg-gray-100 text-gray-800' };
    return (
      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${config.color}`}>
        {config.label}
      </span>
    );
  };

  // Modal de confirmación
  const ConfirmDialog = () => {
    if (!showConfirmDialog || !confirmAction) return null;

    const { action, user } = confirmAction;
    
    const messages = {
      toggleStatus: {
        title: user.status === 'active' ? 'Suspender Usuario' : 'Activar Usuario',
        message: user.status === 'active' 
          ? `¿Estás seguro de que quieres suspender a ${user.name || user.email}? El usuario no podrá acceder al sistema.`
          : `¿Estás seguro de que quieres activar a ${user.name || user.email}?`,
        confirmButton: user.status === 'active' ? 'Suspender' : 'Activar',
        confirmClass: user.status === 'active' ? 'bg-orange-600 hover:bg-orange-700' : 'bg-green-600 hover:bg-green-700'
      },
      delete: {
        title: 'Eliminar Usuario',
        message: `¿Estás seguro de que quieres eliminar el acceso de ${user.name || user.email}? Esta acción no se puede deshacer.`,
        confirmButton: 'Eliminar',
        confirmClass: 'bg-red-600 hover:bg-red-700'
      }
    };

    const config = messages[action];

    return (
      <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div className="bg-white rounded-lg p-6 max-w-md w-full mx-4">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">{config.title}</h3>
          <p className="text-gray-600 mb-6">{config.message}</p>
          <div className="flex justify-end gap-3">
            <button
              onClick={() => setShowConfirmDialog(false)}
              className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-md transition-colors"
            >
              Cancelar
            </button>
            <button
              onClick={executeConfirmAction}
              className={`px-4 py-2 text-sm font-medium text-white rounded-md transition-colors ${config.confirmClass}`}
            >
              {config.confirmButton}
            </button>
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <Users className="w-7 h-7" />
            Gestión de Usuarios
          </h1>
          <p className="text-gray-600 mt-1">Administra usuarios y sus permisos en el sistema</p>
        </div>
        
        <button
          onClick={loadUsers}
          disabled={loading}
          className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 transition-colors"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          Actualizar
        </button>
      </div>

      {/* Formulario de invitación */}
      {currentUser?.role === 'admin' || currentUser?.role === 'owner' ? (
        <div className="bg-white rounded-lg shadow-sm border p-6">
          <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
            <UserPlus className="w-5 h-5" />
            Invitar Nuevo Usuario
          </h3>
          
          <form onSubmit={inviteUser} className="flex flex-col sm:flex-row gap-4">
            <input
              type="email"
              placeholder="email@ejemplo.com"
              value={inviteEmail}
              onChange={(e) => setInviteEmail(e.target.value)}
              className="flex-1 px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
              required
            />
            
            <select
              value={inviteRole}
              onChange={(e) => setInviteRole(e.target.value)}
              className="px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
            >
              {roles.map(role => (
                <option key={role.value} value={role.value}>{role.label}</option>
              ))}
            </select>
            
            <button
              type="submit"
              disabled={inviteLoading}
              className="px-6 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 disabled:opacity-50 flex items-center gap-2 transition-colors"
            >
              <Mail className="w-4 h-4" />
              {inviteLoading ? 'Enviando...' : 'Enviar Invitación'}
            </button>
          </form>
        </div>
      ) : null}

      {/* Filtros */}
      <div className="bg-white rounded-lg shadow-sm border p-4">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          {/* Búsqueda */}
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
            <input
              type="text"
              placeholder="Buscar por nombre o email..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
            />
          </div>

          {/* Filtro por rol */}
          <div>
            <select
              value={filterRole}
              onChange={(e) => setFilterRole(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
            >
              <option value="all">Todos los roles</option>
              {roles.map(role => (
                <option key={role.value} value={role.value}>{role.label}</option>
              ))}
            </select>
          </div>

          {/* Filtro por estado */}
          <div>
            <select
              value={filterStatus}
              onChange={(e) => setFilterStatus(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
            >
              <option value="all">Todos los estados</option>
              <option value="active">Activos</option>
              <option value="pending">Pendientes</option>
              <option value="suspended">Suspendidos</option>
            </select>
          </div>

          {/* Estadísticas rápidas */}
          <div className="flex items-center justify-center bg-gray-50 rounded-md px-3 py-2">
            <span className="text-sm text-gray-600">
              {filteredUsers.length} usuario{filteredUsers.length !== 1 ? 's' : ''}
            </span>
          </div>
        </div>
      </div>

      {/* Tabla de usuarios */}
      <div className="bg-white rounded-lg shadow-sm border overflow-hidden">
        {loading ? (
          <div className="flex items-center justify-center p-8">
            <RefreshCw className="w-8 h-8 animate-spin text-indigo-600" />
            <span className="ml-3 text-lg text-gray-600">Cargando usuarios...</span>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th 
                    className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                    onClick={() => handleSort('name')}
                  >
                    <div className="flex items-center">
                      Usuario
                      {sortBy === 'name' && (
                        sortOrder === 'ASC' ? <ChevronUp className="w-4 h-4 ml-1" /> : <ChevronDown className="w-4 h-4 ml-1" />
                      )}
                    </div>
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Rol
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Estado
                  </th>
                  <th 
                    className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
                    onClick={() => handleSort('last_login')}
                  >
                    <div className="flex items-center">
                      Último Acceso
                      {sortBy === 'last_login' && (
                        sortOrder === 'ASC' ? <ChevronUp className="w-4 h-4 ml-1" /> : <ChevronDown className="w-4 h-4 ml-1" />
                      )}
                    </div>
                  </th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Acciones
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {filteredUsers.length === 0 ? (
                  <tr>
                    <td colSpan="5" className="px-6 py-8 text-center text-gray-500">
                      No se encontraron usuarios
                    </td>
                  </tr>
                ) : (
                  filteredUsers.map((user) => (
                    <React.Fragment key={user.id}>
                      <tr className="hover:bg-gray-50">
                        <td className="px-6 py-4 whitespace-nowrap">
                          <div className="flex items-center">
                            {user.picture ? (
                              <img 
                                src={user.picture} 
                                alt={user.name || user.email} 
                                className="w-10 h-10 rounded-full mr-3"
                              />
                            ) : (
                              <div className="w-10 h-10 rounded-full bg-indigo-500 text-white flex items-center justify-center text-sm font-semibold mr-3">
                                {(user.name || user.email).charAt(0).toUpperCase()}
                              </div>
                            )}
                            <div>
                              <div className="text-sm font-medium text-gray-900">{user.name || user.email}</div>
                              <div className="text-sm text-gray-500 flex items-center">
                                <Mail className="w-3 h-3 mr-1" />
                                {user.email}
                              </div>
                            </div>
                          </div>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <RoleBadge 
                            role={user.role}
                            isEditable={currentUser?.role === 'admin' || currentUser?.role === 'owner'}
                            onRoleChange={updateUserRole}
                            userId={user.id}
                            disabled={user.role === 'owner' && user.id !== currentUser?.id}
                          />
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          <StatusBadge status={user.status} />
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                          {user.last_login ? (
                            <div className="flex items-center">
                              <Clock className="w-3 h-3 mr-1" />
                              {new Date(user.last_login).toLocaleDateString('es-ES', {
                                day: '2-digit',
                                month: '2-digit',
                                year: 'numeric',
                                hour: '2-digit',
                                minute: '2-digit'
                              })}
                            </div>
                          ) : (
                            'Nunca'
                          )}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                          <div className="flex items-center justify-end gap-2">
                            {/* Botón expandir detalles */}
                            <button
                              onClick={() => setExpandedUser(expandedUser === user.id ? null : user.id)}
                              className="text-gray-400 hover:text-indigo-600 p-1"
                              title="Ver detalles"
                            >
                              <Eye className="w-4 h-4" />
                            </button>

                            {(currentUser?.role === 'admin' || currentUser?.role === 'owner') && currentUser.id !== user.id && (
                              <>
                                {/* Suspender/Activar */}
                                <button
                                  onClick={() => confirmActionHandler('toggleStatus', user)}
                                  className={`p-1 ${
                                    user.status === 'active' 
                                      ? 'text-gray-400 hover:text-orange-600' 
                                      : 'text-gray-400 hover:text-green-600'
                                  }`}
                                  title={user.status === 'active' ? 'Suspender' : 'Activar'}
                                >
                                  {user.status === 'active' ? <UserX className="w-4 h-4" /> : <UserCheck className="w-4 h-4" />}
                                </button>

                                {/* Eliminar */}
                                <button
                                  onClick={() => confirmActionHandler('delete', user)}
                                  className="text-gray-400 hover:text-red-600 p-1"
                                  title="Eliminar usuario"
                                >
                                  <Trash2 className="w-4 h-4" />
                                </button>
                              </>
                            )}
                          </div>
                        </td>
                      </tr>

                      {/* Fila expandida con detalles */}
                      {expandedUser === user.id && (
                        <tr className="bg-gray-50">
                          <td colSpan="5" className="px-6 py-4">
                            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
                              <div>
                                <span className="font-medium text-gray-700">ID:</span>
                                <span className="ml-2 text-gray-600">{user.id}</span>
                              </div>
                              <div>
                                <span className="font-medium text-gray-700">Google ID:</span>
                                <span className="ml-2 text-gray-600">{user.google_id || 'No vinculado'}</span>
                              </div>
                              <div>
                                <span className="font-medium text-gray-700">Creado:</span>
                                <span className="ml-2 text-gray-600">
                                  {user.created_at ? new Date(user.created_at).toLocaleDateString('es-ES', {
                                    day: '2-digit',
                                    month: '2-digit',
                                    year: 'numeric',
                                    hour: '2-digit',
                                    minute: '2-digit'
                                  }) : 'No disponible'}
                                </span>
                              </div>
                            </div>
                          </td>
                        </tr>
                      )}
                    </React.Fragment>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Modal de confirmación */}
      <ConfirmDialog />
    </div>
  );
};

export default UserManagement; 