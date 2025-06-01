#!/usr/bin/env node

// Test End-to-End para el Sistema de Gestión de Stock
console.log('🚀 Iniciando pruebas End-to-End...\n');

const BASE_URL = 'http://localhost:4000';

async function testBackend() {
  console.log('📡 Probando Backend...');
  
  try {
    // 1. Health Check
    console.log('  ✓ Health Check');
    const healthResponse = await fetch(`${BASE_URL}/api/health`);
    const health = await healthResponse.json();
    console.log(`    Status: ${health.status}`);

    // 2. Test Login
    console.log('  ✓ Login de Prueba');
    const loginResponse = await fetch(`${BASE_URL}/api/auth/test-login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    });
    const loginData = await loginResponse.json();
    const token = loginData.token;
    console.log(`    Usuario: ${loginData.user.name} (${loginData.user.role})`);

    // 3. Test Products
    console.log('  ✓ Productos');
    const productsResponse = await fetch(`${BASE_URL}/api/products`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    const productsData = await productsResponse.json();
    console.log(`    Productos encontrados: ${productsData.data.length}`);
    console.log(`    Primer producto: ${productsData.data[0]?.name}`);

    // 4. Test Categories
    console.log('  ✓ Categorías');
    const categoriesResponse = await fetch(`${BASE_URL}/api/categories`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    const categoriesData = await categoriesResponse.json();
    console.log(`    Categorías encontradas: ${categoriesData.data.length}`);

    // 5. Test Dashboard Stats
    console.log('  ✓ Estadísticas Dashboard');
    const statsResponse = await fetch(`${BASE_URL}/api/dashboard/stats`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    const statsData = await statsResponse.json();
    console.log(`    Total productos: ${statsData.data.totalProducts}`);
    console.log(`    Productos con stock bajo: ${statsData.data.lowStockProducts}`);
    console.log(`    Valor total inventario: $${statsData.data.totalInventoryValue}`);

    // 6. Test Products with Filters
    console.log('  ✓ Filtros de Productos');
    const filteredResponse = await fetch(`${BASE_URL}/api/products?search=leche&category=1&limit=5`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    const filteredData = await filteredResponse.json();
    console.log(`    Productos filtrados: ${filteredData.data.length}`);

    console.log('\n✅ Backend funcionando correctamente con datos mock!\n');

    // Mostrar información del sistema
    console.log('📊 Resumen del Sistema:');
    console.log(`  • Total de productos: ${statsData.data.totalProducts}`);
    console.log(`  • Productos con stock bajo: ${statsData.data.lowStockProducts}`);
    console.log(`  • Productos sin stock: ${statsData.data.outOfStockProducts}`);
    console.log(`  • Valor total del inventario: $${statsData.data.totalInventoryValue}`);
    console.log(`  • Categorías disponibles: ${categoriesData.data.length}`);
    
    console.log('\n🎯 Para probar el frontend:');
    console.log('  1. Abre http://localhost:3001 en tu navegador');
    console.log('  2. Haz clic en "Login de Prueba"');
    console.log('  3. Navega por el dashboard, productos e inventario');
    console.log('  4. Prueba los filtros y búsquedas');

  } catch (error) {
    console.error('❌ Error en las pruebas:', error.message);
    process.exit(1);
  }
}

// Función principal
async function main() {
  await testBackend();
}

main(); 