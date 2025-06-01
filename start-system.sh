#!/bin/bash

echo "🚀 Iniciando Sistema de Gestión de Stock..."
echo ""

# Configurar variables de entorno
export JWT_SECRET="test_jwt_secret"
export GOOGLE_CLIENT_ID="test_client_id"
export DB_HOST="localhost"
export DB_PORT="5432"
export DB_NAME="stock_management"
export DB_USER="postgres"
export DB_PASSWORD="postgres"
export FRONTEND_URL="http://localhost:3001"

# Función para matar procesos
cleanup() {
    echo ""
    echo "🛑 Deteniendo servicios..."
    pkill -f "node.*server.js" 2>/dev/null || true
    pkill -f "vite" 2>/dev/null || true
    echo "✅ Servicios detenidos"
    exit 0
}

# Capturar Ctrl+C
trap cleanup SIGINT

echo "📡 Iniciando Backend (Puerto 4000)..."
cd backend && node server.js &
BACKEND_PID=$!

echo "🎨 Iniciando Frontend (Puerto 3001)..."
cd ../frontend && npm run dev -- --port 3001 --host &
FRONTEND_PID=$!

# Esperar a que los servicios estén listos
echo ""
echo "⏳ Esperando servicios..."
sleep 5

# Verificar servicios
echo ""
echo "🔍 Verificando servicios..."

# Verificar backend
if curl -s http://localhost:4000/api/health > /dev/null; then
    echo "✅ Backend: http://localhost:4000 ✅"
else
    echo "❌ Backend: No responde"
fi

# Verificar frontend
if curl -s http://localhost:3001 > /dev/null; then
    echo "✅ Frontend: http://localhost:3001 ✅"
else
    echo "❌ Frontend: No responde"
fi

echo ""
echo "🎯 Sistema listo para pruebas End-to-End!"
echo ""
echo "📋 Instrucciones:"
echo "  1. Abre http://localhost:3001 en tu navegador"
echo "  2. Haz clic en 'Login de Prueba'"
echo "  3. Navega por el sistema:"
echo "     • Dashboard con estadísticas reales"
echo "     • Gestión de Productos (8 productos de ejemplo)"
echo "     • Gestión de Inventario"
echo "     • Alertas de stock bajo"
echo "     • Filtros y búsquedas"
echo ""
echo "🗂️  Datos de Prueba Incluidos:"
echo "  • 5 Categorías (Lácteos, Frutas, Carnes, Panadería, Bebidas)"
echo "  • 8 Productos con diferentes estados de stock"
echo "  • Usuario admin de prueba"
echo "  • Estadísticas del dashboard"
echo ""
echo "⚡ Para detener el sistema: Ctrl+C"
echo ""

# Mantener el script corriendo
wait 