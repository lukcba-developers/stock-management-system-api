const axios = require('axios');
const { Pool } = require('pg');
require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });

const API_URL = process.env.API_URL || `http://localhost:${process.env.PORT || 3001}`;
const HEALTH_ENDPOINT = '/health'; // Asumiendo que tienes un endpoint /health en tu API

async function checkHealth() {
  console.log('🏥 Ejecutando chequeos de salud...\n');
  const results = {
    api: { status: '❌ Fallido', message: 'No se pudo conectar' },
    database: { status: '❌ Fallido', message: 'No se pudo conectar' },
  };
  let allHealthy = true;

  // 1. Chequear API Backend
  try {
    const response = await axios.get(`${API_URL}${HEALTH_ENDPOINT}`, { timeout: 5000 });
    if (response.status === 200 && response.data && response.data.status === 'UP') {
      results.api.status = '✅ Saludable';
      results.api.message = `Respuesta OK (status: ${response.data.status}, timestamp: ${response.data.timestamp})`;
    } else {
      results.api.message = `Respuesta inesperada: ${response.status} - ${JSON.stringify(response.data)}`;
      allHealthy = false;
    }
  } catch (error) {
    results.api.message = `Error conectando a la API: ${error.message}`;
    allHealthy = false;
  }
  console.log(`API Backend (${API_URL}${HEALTH_ENDPOINT}): ${results.api.status} - ${results.api.message}`);

  // 2. Chequear Conexión a Base de Datos PostgreSQL
  const pgPool = new Pool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
    connectionTimeoutMillis: 5000,
  });
  try {
    const client = await pgPool.connect();
    const res = await client.query('SELECT NOW() as now');
    results.database.status = '✅ Saludable';
    results.database.message = `Conexión exitosa. Hora del servidor de BD: ${res.rows[0].now}`;
    client.release();
  } catch (error) {
    results.database.message = `Error conectando a la BD: ${error.message}`;
    allHealthy = false;
  } finally {
    await pgPool.end();
  }
  console.log(`Base de Datos (PostgreSQL - ${process.env.DB_HOST}:${process.env.DB_PORT}/${process.env.DB_NAME}): ${results.database.status} - ${results.database.message}`);

  // Resumen
  console.log('\n📊 Resumen de Salud:');
  if (allHealthy) {
    console.log('🎉 ¡Todos los servicios están saludables!');
    process.exit(0);
  } else {
    console.error('🚨 ¡Al menos un servicio ha fallado el chequeo de salud!');
    process.exit(1);
  }
}

checkHealth(); 