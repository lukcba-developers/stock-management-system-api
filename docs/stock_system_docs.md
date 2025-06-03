# 📦 Sistema de Gestión de Stock para Supermercado

## 📋 Descripción General

El **Sistema de Gestión de Stock** es una aplicación web moderna y completa diseñada para la gestión avanzada de inventario en supermercados. Proporciona herramientas integrales para el control de productos, alertas de stock, reportes en tiempo real y sincronización con sistemas externos como WhatsApp a través de N8N.

### ✨ Características Principales

- **Dashboard Interactivo**: Visualización en tiempo real de métricas clave del inventario
- **Gestión Completa de Productos**: CRUD completo con categorización y filtros avanzados
- **Sistema de Alertas**: Notificaciones automáticas para stock bajo y productos sin stock
- **Autenticación Robusta**: Google OAuth y sistema de login de prueba para desarrollo
- **Reportes y Análisis**: Gráficos interactivos y exportación de datos
- **Integración N8N**: Sincronización automática con sistemas de mensajería (WhatsApp)
- **Arquitectura Escalable**: Contenedores Docker con Redis y PostgreSQL
- **Modo de Pruebas**: Sistema completo funcional sin base de datos externa

---

## 🏗️ Arquitectura del Sistema

### Componentes Principales

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │    Backend      │    │   N8N Workers   │
│   (React)       │◄──►│   (Node.js)     │◄──►│  (Automation)   │
│   Puerto 3001   │    │   Puerto 4000   │    │   Puerto 5678   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   PostgreSQL    │
                    │   Puerto 5432   │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │     Redis       │
                    │   Puerto 6379   │
                    └─────────────────┘
```

### Stack Tecnológico

**Frontend:**
- React 18 con Hooks
- Tailwind CSS para estilos
- Vite como bundler
- Recharts para gráficos
- React Hot Toast para notificaciones
- Date-fns para manejo de fechas

**Backend:**
- Node.js con Express
- PostgreSQL como base de datos principal
- Redis para caché y colas
- JWT para autenticación
- Google OAuth 2.0
- Multer para subida de archivos
- WebSockets para notificaciones en tiempo real

**Infraestructura:**
- Docker y Docker Compose
- N8N para automatización
- Nginx como proxy reverso
- Scripts de backup automático

---

## 🚀 Instalación y Configuración

### Prerequisitos

- Docker y Docker Compose
- Node.js 18+
- PostgreSQL 15+ (opcional, incluido en Docker)
- Cuenta Google Cloud Platform (para OAuth)

### Instalación Rápida

1. **Clonar el repositorio:**
```bash
git clone [URL_DEL_REPOSITORIO]
cd stock-management-system
```

2. **Configurar variables de entorno:**
```bash
# Generar configuración automática
chmod +x generate-env.sh
./generate-env.sh

# O configurar manualmente
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env
```

3. **Iniciar con Docker:**
```bash
docker-compose up -d
```

4. **Iniciar en modo desarrollo:**
```bash
# Usar script automático
chmod +x start-system.sh
./start-system.sh

# O manualmente
cd backend && npm install && node server.js &
cd frontend && npm install && npm run dev
```

### URLs de Acceso

- **Frontend**: http://localhost:3001
- **Backend API**: http://localhost:4000
- **N8N Automation**: http://localhost:5678
- **Health Check**: http://localhost:4000/api/health

---

## 🎯 Funcionalidades Principales

### 1. Dashboard Analítico

El dashboard proporciona una vista general completa del estado del inventario:

**Métricas Clave:**
- Total de productos en el sistema
- Productos con stock bajo
- Productos sin stock
- Valor total del inventario
- Órdenes y ingresos del día

**Gráficos Interactivos:**
- Evolución del stock en el tiempo
- Ventas por categoría (gráfico de torta)
- Rotación de inventario por categoría
- Top 5 productos más vendidos

**Filtros de Fecha:**
- Rangos personalizables para análisis temporal
- Vista de últimos 30 días por defecto

### 2. Gestión de Inventario

**Características del Inventario:**
- Lista completa de productos con paginación
- Búsqueda avanzada por nombre, marca, código de barras
- Filtros por categoría y estado de stock
- Ordenamiento por múltiples campos
- Vista detallada de cada producto

**Estados de Stock:**
- 🟢 **Normal**: Stock por encima del mínimo
- 🟡 **Stock Bajo**: Stock igual o menor al mínimo alertado
- 🔴 **Sin Stock**: Stock en cero

**Información por Producto:**
- Datos básicos (nombre, descripción, precio)
- Información de stock (actual, mínimo, historial)
- Categorización con iconos
- Imágenes del producto
- Datos de proveedor y códigos de barras
- Historial de movimientos de stock

### 3. Sistema de Alertas

**Alertas Automáticas:**
- Notificaciones en tiempo real via WebSocket
- Alertas de stock bajo configurables
- Alertas de productos sin stock
- Sistema de notificaciones visuales

**Gestión de Alertas:**
- Vista dedicada para alertas activas
- Funcionalidad de reabastecimiento rápido
- Seguimiento de resolución de alertas
- Historial de alertas por producto

### 4. Gestión de Productos

**CRUD Completo:**
- Crear nuevos productos con formulario avanzado
- Editar productos existentes
- Eliminación suave (marcar como no disponible)
- Actualización de stock con historial

**Campos del Producto:**
- Información básica (nombre, descripción, precio)
- Gestión de stock (cantidad actual, mínimo)
- Categorización y organización
- Información comercial (marca, código de barras)
- Metadatos (peso, palabras clave, destacado)
- Imágenes del producto

**Validaciones:**
- Campos obligatorios validados
- Formatos de imagen permitidos (JPEG, PNG, WebP)
- Validación de precios y cantidades
- Códigos de barras únicos

### 5. Sistema de Categorías

**Organización Jerárquica:**
- Categorías con iconos emoji
- Orden personalizable
- Conteo automático de productos por categoría
- Estadísticas de stock por categoría

**Categorías Predefinidas:**
- 🥛 Lácteos
- 🍎 Frutas y Verduras
- 🥩 Carnes
- 🍞 Panadería
- 🥤 Bebidas

### 6. Reportes y Exportación

**Tipos de Reportes:**
- Reporte de inventario completo
- Productos con stock bajo
- Análisis de rotación
- Tendencias de ventas
- Valor de inventario por categoría

**Formatos de Exportación:**
- CSV para análisis en Excel
- Filtros aplicables a exportaciones
- Datos en tiempo real

---

## 🔐 Sistema de Autenticación

### Métodos de Autenticación

**1. Google OAuth 2.0:**
- Integración completa con Google
- Gestión automática de usuarios
- Roles asignables (admin, editor, viewer)
- Información de perfil automática

**2. Login de Prueba:**
- Usuario de desarrollo integrado
- Acceso inmediato sin configuración
- Ideal para demos y desarrollo
- Funcionalidad completa del sistema

### Roles de Usuario

**Administrador (admin):**
- Acceso completo al sistema
- Gestión de productos y categorías
- Actualización de stock
- Acceso a todos los reportes

**Editor (editor):**
- Gestión de productos
- Actualización de stock
- Visualización de reportes
- Sin acceso a configuración de usuarios

**Visualizador (viewer):**
- Solo lectura del sistema
- Acceso a dashboard y reportes
- Sin permisos de modificación

---

## 🔄 Integración con N8N

### Capacidades de Automatización

**Sincronización con WhatsApp:**
- Recepción de pedidos via WhatsApp
- Actualización automática de stock
- Notificaciones de stock bajo
- Confirmación de pedidos

**Flujos de Trabajo Automatizados:**
- Procesamiento de órdenes
- Sincronización de inventario
- Alertas de reabastecimiento
- Reportes automáticos

**API Endpoints para N8N:**
- `/api/integration/webhook/order` - Recibir pedidos
- `/api/integration/stock/:productId` - Consultar stock
- `/api/integration/sync/inventory` - Sincronizar inventario

### Configuración de Workers

El sistema utiliza una arquitectura de workers N8N:
- **N8N Main**: Coordinador principal (Puerto 5678)
- **N8N Worker 1**: Procesador de tareas
- **N8N Worker 2**: Procesador adicional
- **Redis**: Cola de tareas compartida
- **PostgreSQL**: Base de datos compartida

---

## 📊 Modo de Datos Mock

### Funcionalidad sin Base de Datos

El sistema puede funcionar completamente sin una base de datos PostgreSQL configurada, utilizando datos de prueba integrados:

**Datos de Ejemplo Incluidos:**
- 5 categorías predefinidas
- 8 productos con diferentes estados de stock
- Estadísticas de dashboard simuladas
- Historial de movimientos mock
- Alertas de stock ejemplo

**Características del Modo Mock:**
- Sistema completamente funcional
- Ideal para demos y desarrollo
- No requiere configuración de BD
- Datos realistas para pruebas

**Productos de Ejemplo:**
- Leche Entera (stock normal)
- Yogur Natural (stock bajo)
- Manzanas Rojas (sin stock)
- Bananas (stock normal)
- Carne Molida (stock bajo)
- Pan Lactal (stock normal)
- Coca Cola (stock bajo)
- Agua Mineral (stock normal)

---

## 🛠️ API Endpoints

### Autenticación

```
POST /api/auth/google         # Login con Google OAuth
POST /api/auth/test-login     # Login de prueba
GET  /api/auth/verify         # Verificar token
POST /api/auth/admin-login    # Login de administrador
```

### Productos

```
GET    /api/products          # Lista de productos (con filtros)
GET    /api/products/:id      # Producto específico
POST   /api/products          # Crear producto
PUT    /api/products/:id      # Actualizar producto
DELETE /api/products/:id      # Eliminar producto (soft delete)
PATCH  /api/products/:id/stock # Actualizar stock
GET    /api/products/:id/movements # Historial de movimientos
```

### Categorías

```
GET    /api/categories        # Lista de categorías
POST   /api/categories        # Crear categoría
PUT    /api/categories/:id    # Actualizar categoría
DELETE /api/categories/:id    # Eliminar categoría
```

### Dashboard

```
GET    /api/dashboard/stats           # Estadísticas principales
GET    /api/dashboard/charts/stock-evolution # Evolución de stock
GET    /api/dashboard/inventory-turnover # Análisis de rotación
```

### Reportes

```
GET    /api/reports/inventory-turnover    # Rotación de inventario
GET    /api/reports/top-selling          # Productos más vendidos
GET    /api/reports/inventory-value-by-category # Valor por categoría
GET    /api/reports/sales-trends         # Tendencias de ventas
```

### Integración

```
POST   /api/integration/webhook/order    # Webhook para pedidos
GET    /api/integration/stock/:productId # Consultar stock específico
POST   /api/integration/sync/inventory   # Sincronizar inventario
```

---

## 🔧 Configuración Avanzada

### Variables de Entorno

**Backend (.env):**
```env
# Base de Datos
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=tu_password_seguro
DB_NAME=stock_management
DB_SSL=false

# Autenticación
JWT_SECRET=tu_jwt_secret_muy_seguro
GOOGLE_CLIENT_ID=tu_google_client_id

# Configuración del Servidor
PORT=4000
NODE_ENV=development
FRONTEND_URL=http://localhost:3001

# N8N Integration
N8N_WEBHOOK_URL=http://localhost:5678
N8N_API_TOKEN=tu_n8n_api_token

# Redis
REDIS_URL=redis://localhost:6379

# Archivos
UPLOAD_PATH=uploads
MAX_FILE_SIZE=5242880
```

**Frontend (.env):**
```env
# API Configuration
VITE_API_URL=http://localhost:4000/api

# Google OAuth
VITE_GOOGLE_CLIENT_ID=tu_google_client_id

# App Configuration
VITE_APP_NAME=Stock Management System
VITE_APP_DESCRIPTION=Sistema de Gestión de Stock para Supermercado
```

### Configuración de Docker

El sistema incluye configuración completa de Docker con:
- Servicios optimizados para producción
- Volúmenes persistentes para datos
- Red interna para comunicación entre servicios
- Health checks para todos los servicios
- Configuración de límites de recursos

### Backup y Restauración

**Backup Automático:**
```bash
# Ejecutar backup manual
./scripts/backup-database.sh /ruta/destino/backup.sql

# Configurar backup automático (cron)
0 2 * * * /ruta/al/proyecto/backend/scripts/auto-backup.sh
```

**Restauración:**
```bash
# Restaurar desde backup
./scripts/restore-database.sh /ruta/al/backup.sql
```

---

## 🧪 Testing y Desarrollo

### Modo de Desarrollo

**Inicio Rápido para Desarrollo:**
```bash
# Script automático que configura todo
./start-system.sh

# Accesos:
# Frontend: http://localhost:3001
# Backend: http://localhost:4000
# N8N: http://localhost:5678
```

**Testing End-to-End:**
```bash
# Ejecutar tests automatizados
node test-e2e.js

# Verifica:
# - Conectividad del backend
# - Login de prueba
# - Endpoints principales
# - Datos mock
```

### Casos de Prueba Sugeridos

**Frontend:**
1. Login de prueba funciona correctamente
2. Dashboard carga con estadísticas
3. Navegación entre secciones
4. Búsqueda y filtros de productos
5. Creación y edición de productos
6. Gestión de alertas de stock
7. Exportación de reportes

**Backend:**
1. Autenticación y autorización
2. CRUD de productos
3. Sistema de filtros
4. Validaciones de datos
5. Subida de imágenes
6. API de estadísticas
7. Integración con N8N

**Integración:**
1. Sincronización de stock
2. Webhooks de pedidos
3. Notificaciones en tiempo real
4. Backup y restauración

---

## 📈 Roadmap y Mejoras Futuras

### Características Planificadas

**Corto Plazo:**
- [ ] Sistema de proveedores completo
- [ ] Órdenes de compra automatizadas
- [ ] Códigos QR para productos
- [ ] App móvil para inventario

**Mediano Plazo:**
- [ ] Integración con sistemas de punto de venta
- [ ] Predicción de demanda con IA
- [ ] Sistema de promociones y descuentos
- [ ] Multi-sucursal

**Largo Plazo:**
- [ ] Marketplace integrado
- [ ] Sistema de fidelización
- [ ] Analytics avanzados con machine learning
- [ ] API pública para terceros

### Optimizaciones Técnicas

- [ ] Implementación de GraphQL
- [ ] Cache distribuido con Redis Cluster
- [ ] Microservicios con Kubernetes
- [ ] CI/CD con GitHub Actions
- [ ] Monitoreo con Prometheus y Grafana

---

## 🤝 Contribución

### Guías para Desarrolladores

**Estructura del Proyecto:**
```
stock-management-system/
├── backend/                 # API Node.js
│   ├── src/                # Código fuente
│   ├── routes/             # Rutas de la API
│   ├── scripts/            # Scripts de utilidad
│   └── uploads/            # Archivos subidos
├── frontend/               # Aplicación React
│   ├── src/                # Código fuente
│   └── public/             # Archivos estáticos
├── nginx/                  # Configuración proxy
├── scripts/                # Scripts del sistema
└── docker-compose.yml     # Configuración Docker
```

**Estándares de Código:**
- ESLint para JavaScript
- Prettier para formateo
- Conventional Commits
- Testing con Jest
- Documentación inline

### Proceso de Contribución

1. Fork del repositorio
2. Crear rama feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit con mensaje descriptivo
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Crear Pull Request con descripción detallada

---

## 📞 Soporte y Contacto

### Recursos de Ayuda

- **Documentación Técnica**: Este documento
- **Health Check**: http://localhost:4000/api/health
- **Logs del Sistema**: `docker-compose logs -f`
- **Estado de Servicios**: `docker-compose ps`

### Solución de Problemas Comunes

**Backend no inicia:**
```bash
# Verificar puerto libre
lsof -i :4000
# Revisar logs
cd backend && npm run dev
```

**Frontend no conecta:**
```bash
# Verificar configuración de proxy en vite.config.js
# Verificar variables de entorno en .env
```

**Error de base de datos:**
```bash
# El sistema funcionará con datos mock automáticamente
# Para usar PostgreSQL, verificar conexión:
docker-compose up postgres
```

### Contacto del Equipo

Para soporte técnico o consultas sobre el sistema:
- Crear issue en el repositorio
- Revisar documentación de troubleshooting
- Contactar al equipo de desarrollo

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE.md` para más detalles.

---

*Documentación actualizada: Junio 2025*
*Versión del Sistema: 1.0.0*
*Última revisión: Sistema completamente funcional con datos mock*