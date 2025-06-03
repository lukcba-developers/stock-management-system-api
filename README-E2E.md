# 🏪 Sistema de Gestión de Stock - Pruebas End-to-End

## ✅ Estado Actual: **FUNCIONANDO**

El sistema está completamente funcional para pruebas End-to-End con datos mock. **NO requiere base de datos PostgreSQL** para las pruebas.

## 🚀 Inicio Rápido

### Opción 1: Script Automático (Recomendado)
```bash
./start-system.sh
```

### Opción 2: Manual

**Terminal 1 - Backend:**
```bash
cd backend
export JWT_SECRET="test_secret"
export FRONTEND_URL="http://localhost:3001"
node server.js
```

**Terminal 2 - Frontend:**
```bash
cd frontend
npm run dev -- --port 3001 --host
```

## 🌐 URLs del Sistema

- **Frontend:** http://localhost:3001
- **Backend API:** http://localhost:4000
- **Health Check:** http://localhost:4000/api/health

## 🧪 Cómo Hacer Pruebas E2E

### 1. **Acceso al Sistema**
1. Abre http://localhost:3001
2. Haz clic en **"Login de Prueba"**
3. Serás autenticado como: `Usuario de Prueba (Admin)`

### 2. **Funcionalidades a Probar**

#### 📊 **Dashboard**
- ✅ Estadísticas en tiempo real
- ✅ Productos con stock bajo/sin stock
- ✅ Valor total del inventario
- ✅ Gráficos y métricas

#### 🏷️ **Gestión de Productos**
- ✅ Lista de productos (8 productos de ejemplo)
- ✅ Búsqueda por nombre, marca, código de barras
- ✅ Filtros por categoría
- ✅ Filtros por estado de stock
- ✅ Paginación
- ✅ Ordenamiento

#### 📦 **Gestión de Inventario**
- ✅ Estados de stock: Normal, Bajo, Sin Stock
- ✅ Alertas automáticas
- ✅ Información detallada por producto

#### 🔐 **Sistema de Autenticación**
- ✅ Login de prueba (sin Google OAuth)
- ✅ Verificación de tokens JWT
- ✅ Roles de usuario (Admin)

## 📊 Datos de Prueba Incluidos

### **Categorías (5)**
- 🥛 Lácteos (8 productos)
- 🍎 Frutas y Verduras (15 productos)
- 🥩 Carnes (12 productos)
- 🍞 Panadería (6 productos)
- 🥤 Bebidas (10 productos)

### **Productos de Ejemplo (8 visibles)**
- **Leche Entera** - Stock normal
- **Yogur Natural** - Stock bajo ⚠️
- **Manzanas Rojas** - Sin stock ❌
- **Bananas** - Stock normal
- **Carne Molida** - Stock bajo ⚠️
- **Pan Lactal** - Stock normal
- **Coca Cola** - Stock bajo ⚠️
- **Agua Mineral** - Stock normal

### **Estadísticas Mock**
- Total productos: 51
- Productos con stock bajo: 8
- Productos sin stock: 3
- Valor total inventario: $12,450.75

## 🔧 Scripts de Prueba

### Verificar Backend
```bash
node test-e2e.js
```

### Probar API Manualmente
```bash
# Login de prueba
curl -X POST http://localhost:4000/api/auth/test-login

# Obtener productos (requiere token)
TOKEN="tu_token_aqui"
curl -H "Authorization: Bearer $TOKEN" http://localhost:4000/api/products

# Filtrar productos
curl -H "Authorization: Bearer $TOKEN" "http://localhost:4000/api/products?search=leche&category=1"
```

## 🎯 Casos de Prueba Sugeridos

### **Frontend**
1. **Login y Navegación**
   - Login de prueba funciona
   - Dashboard carga con estadísticas
   - Navegación entre secciones

2. **Gestión de Productos**
   - Lista de productos se muestra
   - Búsqueda por texto funciona
   - Filtros por categoría funcionan
   - Filtros por stock funcionan
   - Paginación funciona

3. **Responsive Design**
   - Probar en diferentes tamaños de pantalla
   - Menú móvil funciona
   - Tablas son responsive

### **Backend**
1. **Autenticación**
   - Login de prueba genera token válido
   - Rutas protegidas requieren token
   - Token inválido es rechazado

2. **API Endpoints**
   - `/api/products` devuelve productos mock
   - `/api/categories` devuelve categorías mock
   - `/api/dashboard/stats` devuelve estadísticas mock
   - Filtros y búsquedas funcionan

## 🐛 Solución de Problemas

### Backend no inicia
```bash
# Verificar que puerto 4000 esté libre
lsof -i :4000
# Si está ocupado, matar proceso
pkill -f "node.*server.js"
```

### Frontend no inicia
```bash
# Verificar que puerto 3001 esté libre
lsof -i :3001
# Si está ocupado, matar proceso
pkill -f "vite"
```

### Error de CORS
- El backend está configurado para aceptar `http://localhost:3001`
- Verificar que el frontend esté en el puerto correcto

## 📝 Notas Técnicas

- **Sin PostgreSQL:** El sistema detecta que no hay BD y usa datos mock automáticamente
- **Sin Google OAuth:** Se usa un sistema de login de prueba
- **JWT Secret:** Se usa `test_jwt_secret` para las pruebas
- **Datos Persistentes:** Los datos mock no se guardan entre reinicios
- **Roles:** El usuario de prueba tiene rol `admin` con todos los permisos

## 🔄 Próximos Pasos

Para convertir en un sistema de producción:
1. Configurar PostgreSQL con las tablas necesarias
2. Configurar Google OAuth con credenciales reales
3. Configurar variables de entorno de producción
4. Añadir más funcionalidades (CRUD completo, reportes, etc.)

---

**✨ El sistema está listo para demostraciones y pruebas end-to-end completas!** 