const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const envExamplePath = path.resolve(__dirname, '../.env.example');
const envPath = path.resolve(__dirname, '../.env');

function generateRandomString(length) {
  return crypto.randomBytes(Math.ceil(length / 2)).toString('hex').slice(0, length);
}

try {
  if (fs.existsSync(envPath)) {
    console.log(`⚠️  El archivo .env ya existe en ${envPath}. No se sobreescribirá.`);
    console.log("Si necesitas regenerar claves, elimina o renombra el .env actual y vuelve a ejecutar el script.");
    process.exit(0);
  }

  if (!fs.existsSync(envExamplePath)) {
    console.error(`❌ Error: El archivo .env.example no se encuentra en ${envExamplePath}.`);
    console.error("Asegúrate de tener un .env.example en la raíz del backend.");
    process.exit(1);
  }

  let envContent = fs.readFileSync(envExamplePath, 'utf8');

  // Generar JWT_SECRET seguro
  const jwtSecret = generateRandomString(64); // 64 caracteres hexadecimales
  envContent = envContent.replace(/^JWT_SECRET=.*$/m, `JWT_SECRET=${jwtSecret}`);

  fs.writeFileSync(envPath, envContent);

  console.log(`✅ Archivo .env generado exitosamente en ${envPath} a partir de .env.example.`);
  console.log(`   🔑 Se ha generado un nuevo JWT_SECRET.`);
  console.log("\n👉 Por favor, revisa y completa las siguientes variables en tu archivo .env:");
  console.log("   - Credenciales de la Base de Datos (DB_USER, DB_PASSWORD, etc.)");
  console.log("   - Credenciales de Google OAuth (GOOGLE_CLIENT_ID)");
  console.log("   - URL del Frontend (FRONTEND_URL)");
  console.log("   - Y cualquier otra configuración específica de tu entorno.");

} catch (error) {
  console.error('❌ Error generando el archivo .env:', error);
  process.exit(1);
} 