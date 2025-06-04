# 🔐 Sistema de Gestión de Usuarios SaaS

Este documento explica cómo configurar y usar el nuevo sistema de gestión de usuarios con funcionalidades SaaS.

## 📋 Características

### ✅ **Funcionalidades Implementadas**

- **🎯 Sistema de Invitaciones**: Invitar usuarios por email con roles específicos
- **👥 Gestión de Usuarios**: Crear, editar, suspender y eliminar usuarios
- **🔑 Roles Jerárquicos**: `viewer`, `editor`, `admin`, `owner`
- **📧 Notificaciones por Email**: Invitaciones, bienvenida, cambio de roles
- **🏢 Multi-Organización**: Soporte para múltiples organizaciones
- **🔐 Autenticación Google OAuth**: Login seguro con Google
- **📊 Estadísticas de Usuarios**: Métricas y análisis de usuarios
- **🚫 Control de Acceso**: Permisos granulares por rol

### 🎨 **Interfaz de Usuario**

- **🔍 Búsqueda Avanzada**: Por nombre, email, rol, estado
- **📱 Responsive Design**: Optimizado para móviles y desktop
- **✅ Confirmaciones**: Modales para acciones destructivas
- **🎭 Estados Visuales**: Loading, empty states, error handling
- **📈 Filtros Inteligentes**: Multiple filtros combinables

## 🛠️ Configuración del Backend

### 1. **Variables de Entorno**

Crea un archivo `backend/.env` con las siguientes variables:

```bash
# Base de datos PostgreSQL
DB_HOST=localhost
DB_PORT=5432
DB_NAME=stock_management
DB_USER=postgres
DB_PASSWORD=tu_password_aqui

# JWT Secret para autenticación
JWT_SECRET=tu_super_secreto_jwt_muy_seguro_aqui

# Google OAuth
GOOGLE_CLIENT_ID=tu_google_client_id_aqui

# Configuración del servidor
PORT=4000
NODE_ENV=development
FRONTEND_URL=http://localhost:3000

# Configuración de Email (SMTP)
# Para desarrollo (Ethereal Email - emails de prueba)
SMTP_HOST=smtp.ethereal.email
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=tu_usuario_ethereal
SMTP_PASS=tu_password_ethereal
SMTP_FROM=noreply@stockmanager.com

# Para producción (ejemplo con SendGrid)
# SMTP_HOST=smtp.sendgrid.net
# SMTP_PORT=587
# SMTP_SECURE=false
# SMTP_USER=apikey
# SMTP_PASS=tu_sendgrid_api_key

# Uploads
UPLOAD_PATH=uploads
MAX_FILE_SIZE=5242880
```

### 2. **Estructura de Base de Datos SaaS**

El sistema requiere las siguientes tablas en PostgreSQL:

```sql
-- Esquema SaaS
CREATE SCHEMA IF NOT EXISTS saas;

-- Tabla de organizaciones
CREATE TABLE saas.organizations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    subscription_plan VARCHAR(50) DEFAULT 'starter',
    subscription_status VARCHAR(50) DEFAULT 'active',
    max_users INTEGER DEFAULT 10,
    features JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Tabla de usuarios autorizados
CREATE TABLE saas.authorized_users (
    id SERIAL PRIMARY KEY,
    organization_id INTEGER REFERENCES saas.organizations(id),
    email VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    google_id VARCHAR(255),
    picture TEXT,
    role VARCHAR(50) DEFAULT 'viewer',
    status VARCHAR(50) DEFAULT 'pending',
    invitation_token VARCHAR(255),
    invitation_sent_at TIMESTAMP,
    invitation_expires_at TIMESTAMP,
    invitation_accepted_at TIMESTAMP,
    last_login TIMESTAMP,
    login_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(organization_id, email)
);

-- Índices para optimización
CREATE INDEX idx_authorized_users_email ON saas.authorized_users(email);
CREATE INDEX idx_authorized_users_org_id ON saas.authorized_users(organization_id);
CREATE INDEX idx_authorized_users_invitation_token ON saas.authorized_users(invitation_token);
CREATE INDEX idx_organizations_slug ON saas.organizations(slug);
```

### 3. **Configuración de Email**

#### 🔧 **Para Desarrollo - Ethereal Email**

1. Ve a [Ethereal Email](https://ethereal.email/)
2. Crea una cuenta de prueba
3. Usa las credenciales en tu `.env`
4. Los emails se capturan y puedes verlos en la interfaz web

#### 🚀 **Para Producción - SendGrid**

1. Crea una cuenta en [SendGrid](https://sendgrid.com/)
2. Genera una API Key
3. Configura tu dominio
4. Actualiza las variables SMTP en `.env`

#### 📧 **Otras Opciones**

- **AWS SES**: Para envíos masivos
- **Mailgun**: API simple y confiable  
- **Gmail SMTP**: Para proyectos pequeños

### 4. **Instalación de Dependencias**

```bash
cd backend
npm install nodemailer google-auth-library
```

## 🎯 Uso del Sistema

### 1. **Crear la Primera Organización**

```javascript
// Script para crear organización inicial
INSERT INTO saas.organizations (name, slug, subscription_plan, max_users) 
VALUES ('Mi Empresa', 'mi-empresa', 'professional', 50);

INSERT INTO saas.authorized_users 
(organization_id, email, name, role, status) 
VALUES (1, 'admin@miempresa.com', 'Administrador Principal', 'owner', 'active');
```

### 2. **Flujo de Invitación de Usuarios**

1. **👨‍💼 Admin/Owner**: Invita usuario desde la interfaz
2. **📧 Sistema**: Envía email con enlace de invitación
3. **👤 Usuario**: Hace click en el enlace
4. **🔐 Google OAuth**: Se autentica con Google
5. **✅ Activación**: Cuenta activada automáticamente

### 3. **Roles y Permisos**

| Rol | Permisos |
|-----|----------|
| **👁️ Viewer** | Solo lectura: inventario, reportes, alertas |
| **✏️ Editor** | Viewer + editar inventario, gestionar productos |
| **👨‍💼 Admin** | Editor + gestionar usuarios, configuraciones |
| **👑 Owner** | Admin + control total, gestión de organización |

### 4. **APIs Disponibles**

#### 🔐 **Autenticación**
- `POST /api/auth/google` - Login con Google
- `GET /api/auth/verify` - Verificar token
- `POST /api/auth/accept-invitation` - Aceptar invitación

#### 👥 **Gestión de Usuarios**
- `GET /api/admin/users` - Listar usuarios
- `POST /api/admin/users/invite` - Invitar usuario
- `PATCH /api/admin/users/:id/role` - Cambiar rol
- `PATCH /api/admin/users/:id/status` - Cambiar estado
- `DELETE /api/admin/users/:id` - Eliminar usuario
- `GET /api/admin/users/stats` - Estadísticas

## 🎨 Frontend - Componente UserManagement

### **Ubicación**: `frontend/src/components/Admin/UserManagement.jsx`

### **Características**:

- ✅ **Tabla Responsiva**: Se adapta a móviles
- 🔍 **Búsqueda en Tiempo Real**: Por nombre y email
- 🎚️ **Filtros Múltiples**: Por rol y estado
- 📊 **Ordenamiento**: Por cualquier columna
- 📱 **Detalles Expandibles**: Información adicional
- ⚠️ **Confirmaciones**: Para acciones peligrosas

### **Integración**:

```jsx
import UserManagement from './components/Admin/UserManagement';

// En tu componente principal
{activeView === 'users' && (
  <UserManagement currentUser={user} />
)}
```

## 🔒 Páginas de Error y Autorización

### **UnauthorizedPage**: `frontend/src/components/UnauthorizedPage.jsx`

Página dedicada para usuarios no autorizados con:

- 🚫 **Mensaje de Error Claro**: Informa al usuario sobre el problema
- 📧 **Contacto Directo**: Botón para email al administrador
- 🔄 **Reintentar**: Opción para probar con otra cuenta
- 📱 **Responsive**: Diseño adaptativo
- 🎨 **UX Amigable**: Guía paso a paso para obtener acceso

**Integración en Router**:
```jsx
import UnauthorizedPage from './components/UnauthorizedPage';

// En tu routing
<Route path="/unauthorized" element={<UnauthorizedPage />} />
```

### **AcceptInvitation**: `frontend/src/components/AcceptInvitation.jsx`

Página para aceptar invitaciones con:

- ✅ **Validación de Token**: Verifica invitaciones automáticamente
- 🏢 **Información de Organización**: Muestra detalles de la invitación
- 🔐 **Google OAuth**: Autenticación segura
- ⏰ **Verificación de Expiración**: Controla tokens vencidos
- 🎯 **Flujo Completo**: Desde invitación hasta dashboard

**Integración en Router**:
```jsx
import AcceptInvitation from './components/AcceptInvitation';

// En tu routing
<Route path="/accept-invitation" element={<AcceptInvitation />} />
```

## 🏢 Middleware de Multi-tenancy

### **Ubicación**: `backend/src/middleware/multitenancy.js`

### **Funcionalidades**:

#### **🔐 injectOrganizationContext**
- Inyecta automáticamente el contexto de organización
- Configura Row Level Security (RLS) en PostgreSQL
- Asegura aislamiento de datos entre organizaciones

#### **✅ validateOrganizationAccess**
- Valida acceso a recursos de organización específica
- Útil para rutas con `organizationId` en parámetros

#### **🛡️ enforceProductOrganization**
- Middleware específico para productos
- Inyecta `organization_id` automáticamente en POST
- Filtra productos por organización en GET/PUT/DELETE

#### **📦 enforceOrderOrganization**
- Similar al de productos pero para órdenes/ventas
- Asegura aislamiento de datos de ventas

#### **📊 checkOrganizationLimits**
- Verifica límites del plan (usuarios, productos, etc.)
- Previene exceder cuotas de suscripción

### **Implementación en Server.js**:

```javascript
import { 
  injectOrganizationContext, 
  enforceProductOrganization, 
  enforceOrderOrganization,
  checkOrganizationLimits
} from './src/middleware/multitenancy.js';

// Aplicar a rutas que requieren aislamiento
app.use('/api/products', authenticateToken, injectOrganizationContext, enforceProductOrganization);
app.use('/api/orders', authenticateToken, injectOrganizationContext, enforceOrderOrganization);
app.use('/api/dashboard', authenticateToken, injectOrganizationContext);
```

### **Helpers Disponibles**:

```javascript
// Agregar filtro de organización a queries
const filteredQuery = addOrganizationFilter(
  'SELECT * FROM products', 
  req.organizationId
);

// Query con filtro automático
const result = await queryWithOrganization(
  'SELECT * FROM products WHERE active = true',
  [],
  req.organizationId
);
```

## 🚨 Seguridad

### **Medidas Implementadas**:

- 🔐 **JWT con Expiración**: Tokens seguros
- 🏢 **Aislamiento por Organización**: Datos separados
- 🔒 **Roles Jerárquicos**: Permisos estrictos
- 📧 **Tokens de Invitación**: Con expiración
- 🚫 **Validaciones**: En frontend y backend
- 🛡️ **Rate Limiting**: Prevención de ataques

### **Mejores Prácticas**:

1. **🔑 JWT_SECRET**: Usa un secret fuerte (32+ caracteres)
2. **📧 SMTP**: Nunca hardcodees credenciales
3. **🏢 Validación**: Siempre verificar organization_id
4. **🔍 Logs**: Monitorear accesos y cambios
5. **⏰ Expiración**: Tokens de invitación limitados en tiempo

## 🧪 Testing

### **Testing de Emails en Desarrollo**:

```javascript
// Los emails se capturan en Ethereal Email
// Verifica la consola para URLs de preview
console.log('Preview URL:', nodemailer.getTestMessageUrl(info));
```

### **Testing de la API**:

```bash
# Invitar usuario
curl -X POST http://localhost:4000/api/admin/users/invite \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"email": "nuevo@usuario.com", "role": "editor"}'

# Listar usuarios
curl -X GET http://localhost:4000/api/admin/users \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## 🐛 Troubleshooting

### **Problemas Comunes**:

#### 📧 **Emails no se envían**
- ✅ Verificar credenciales SMTP
- ✅ Comprobar firewall/puertos
- ✅ Revisar logs del servidor

#### 🔐 **Error de autenticación**
- ✅ Verificar GOOGLE_CLIENT_ID
- ✅ Comprobar JWT_SECRET
- ✅ Validar tokens en JWT.io

#### 🏢 **Usuarios no aparecen**
- ✅ Verificar organization_id
- ✅ Comprobar estado del usuario
- ✅ Revisar filtros aplicados

#### 📱 **Interfaz no responde**
- ✅ Abrir DevTools del navegador
- ✅ Verificar red y consola
- ✅ Comprobar estado de loading

## 🔄 Actualizaciones Futuras

### **Roadmap**:

- 🔔 **Notificaciones Push**: Alertas en tiempo real
- 📊 **Analytics Avanzados**: Métricas de uso
- 🔐 **2FA**: Autenticación de doble factor  
- 📱 **App Móvil**: React Native
- 🤖 **API REST Completa**: Integración externa
- 🔄 **Webhooks**: Eventos automáticos

## 🏢 Dashboard de Administración SaaS

### **OrganizationDashboard**: `frontend/src/components/SaaS/OrganizationDashboard.jsx`

Dashboard completo para administración de organizaciones SaaS con:

#### **🎯 Características Principales:**

- **📊 Métricas en Tiempo Real**: Usuarios, productos, órdenes, almacenamiento
- **📈 Gráficos Interactivos**: Tendencias de órdenes, productos por categoría
- **⚠️ Alertas Inteligentes**: Notificaciones cuando se acerca a límites
- **💳 Información de Facturación**: Costos actuales y próximas facturas
- **🔍 Analytics Detallados**: Métricas de crecimiento y uso

#### **🎨 Componentes Incluidos:**

```jsx
// Integración principal
import OrganizationDashboard from './components/SaaS/OrganizationDashboard';

// En tu router o componente principal
<Route path="/organization" element={<OrganizationDashboard />} />
```

#### **🔧 APIs Utilizadas:**

- `GET /api/organization/profile` - Perfil de la organización
- `GET /api/organization/usage` - Métricas de uso actual
- `GET /api/organization/billing` - Información de facturación
- `GET /api/organization/analytics` - Analytics detallados
- `PATCH /api/organization/settings` - Actualizar configuración

### **SubscriptionPlans**: `frontend/src/components/SaaS/SubscriptionPlans.jsx`

Componente para gestión de planes de suscripción:

#### **✨ Características:**

- **💰 Comparación de Planes**: Starter, Professional, Enterprise
- **🔄 Facturación Mensual/Anual**: Toggle con descuentos
- **✅ Características Detalladas**: Lista completa de funcionalidades
- **🎯 Actualización Inmediata**: Cambio de plan en tiempo real
- **📊 Tabla Comparativa**: Comparación lado a lado

#### **🏷️ Planes Disponibles:**

| Plan | Precio/Mes | Usuarios | Productos | Órdenes/Mes | Almacenamiento |
|------|------------|----------|-----------|-------------|----------------|
| **Starter** | $29 | 5 | 100 | 500 | 1 GB |
| **Professional** | $99 | 20 | 1,000 | 2,000 | 10 GB |
| **Enterprise** | $299 | Ilimitados | Ilimitados | Ilimitadas | 100 GB |

### **🛠️ Backend - API de Organización**

#### **Rutas Implementadas:**

```javascript
// Configuración de rutas
app.use('/api/organization', organizationRouter);

// Middlewares aplicados automáticamente:
// - authenticateToken: Verificar autenticación
// - requireActiveOrganization: Verificar organización activa
// - injectOrganizationContext: Inyectar contexto multi-tenant
```

#### **📋 Endpoints Disponibles:**

**Perfil de Organización:**
```bash
GET /api/organization/profile
# Respuesta: información completa de la organización
{
  "id": 1,
  "name": "Mi Empresa",
  "slug": "mi-empresa",
  "subscription_plan": "professional",
  "subscription_status": "active",
  "max_users": 20,
  "max_products": 1000,
  "active_users_count": 8
}
```

**Métricas de Uso:**
```bash
GET /api/organization/usage
# Respuesta: uso actual y tendencias
{
  "current_users": 8,
  "current_products": 245,
  "monthly_orders": 87,
  "storage_used_gb": 2.3,
  "orders_trend": [...],
  "products_by_category": [...],
  "alerts": [...]
}
```

**Información de Facturación:**
```bash
GET /api/organization/billing
# Respuesta: costos y próxima facturación
{
  "plan_price": 99,
  "extra_users_cost": 0,
  "extra_storage_cost": 0,
  "next_bill_amount": 99,
  "next_billing_date": "2024-02-01T00:00:00.000Z"
}
```

#### **📊 Analytics Avanzados:**

```bash
GET /api/organization/analytics?period=30d&metric=orders
# Métricas: orders, users, products
# Períodos: 7d, 30d, 90d, 1y
```

### **🗄️ Base de Datos SaaS**

#### **Tablas Principales:**

- **`saas.organizations`**: Información de organizaciones y suscripciones
- **`saas.authorized_users`**: Usuarios con sistema de invitaciones
- **`saas.subscription_plans`**: Configuración de planes
- **`saas.billing_history`**: Historial de facturación
- **`saas.usage_metrics`**: Métricas diarias de uso
- **`saas.organization_activity`**: Log de actividades

#### **⚡ Configuración Inicial:**

```bash
# Ejecutar script de configuración
psql -d stock_management -f backend/sql/setup_saas_tables.sql
```

### **🔒 Seguridad Multi-Tenant**

#### **Middleware de Multi-tenancy:**

- **`injectOrganizationContext`**: Inyecta automáticamente el contexto de organización
- **`validateOrganizationAccess`**: Valida acceso a recursos específicos
- **Row Level Security (RLS)**: Aislamiento automático a nivel de base de datos

#### **🛡️ Características de Seguridad:**

- **Aislamiento de Datos**: Cada organización solo ve sus datos
- **Verificación de Límites**: Control automático de cuotas de plan
- **Logging de Actividad**: Registro de todas las acciones
- **Validación de Permisos**: Control granular por rol

### **📱 Componentes de UI/UX**

#### **UsageCard**: Tarjetas de métricas con alertas visuales
```jsx
<UsageCard
  icon={Users}
  title="Usuarios"
  current={8}
  max={20}
  color="blue"
  showProgress={true}
/>
```

#### **PlanFeature**: Características del plan con indicadores
```jsx
<PlanFeature 
  name="Usuarios máximos" 
  value={20}
  current={8}
/>
```

### **🚀 Funcionalidades Avanzadas**

#### **📈 Gráficos Interactivos (Recharts):**

- **Tendencia de Órdenes**: LineChart con datos de 30 días
- **Productos por Categoría**: BarChart responsivo
- **Métricas de Crecimiento**: Cálculo automático de tasas

#### **⚠️ Sistema de Alertas:**

- Alertas cuando uso > 80% del límite
- Notificaciones de próximos vencimientos
- Sugerencias de actualización de plan

#### **💳 Gestión de Facturación:**

- Cálculo automático de costos adicionales
- Proyección de próxima factura
- Historial de pagos (próximamente)

### **🔧 Configuración Requerida**

#### **Variables de Entorno Adicionales:**

```bash
# Configuración de planes SaaS
SAAS_STARTER_PRICE=29
SAAS_PROFESSIONAL_PRICE=99
SAAS_ENTERPRISE_PRICE=299
SAAS_EXTRA_USER_COST=5
SAAS_EXTRA_STORAGE_COST=2

# Configuración de facturación
BILLING_PROVIDER=stripe
STRIPE_PUBLIC_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
```

#### **Dependencias del Frontend:**

```bash
# Instalar recharts para gráficos
npm install recharts --legacy-peer-deps
```

### **📊 Métricas y KPIs**

El dashboard rastrea automáticamente:

- **👥 Engagement de Usuarios**: Logins, actividad
- **📦 Uso de Productos**: Creación, edición, eliminación
- **🛒 Volumen de Órdenes**: Tendencias de ventas
- **💾 Consumo de Almacenamiento**: Uso de recursos
- **⚡ Llamadas API**: Uso de integraciones

### **🎯 Casos de Uso**

#### **Para Administradores de Organización:**
- Monitorear uso y límites del plan
- Tomar decisiones de upgrade
- Gestionar usuarios y permisos
- Analizar tendencias de negocio

#### **Para Usuarios Finales:**
- Ver límites disponibles
- Entender restricciones del plan
- Solicitar acceso adicional

#### **Para Desarrolladores:**
- APIs completas para integraciones
- Webhooks para automatización
- Métricas detalladas para optimización

---

## 📞 Soporte

Si tienes problemas o preguntas:

1. 📖 Revisa esta documentación
2. 🔍 Busca en los logs del servidor
3. 🐛 Abre un issue en el repositorio
4. 💬 Contacta al equipo de desarrollo

**¡El sistema está listo para usar! 🚀** 