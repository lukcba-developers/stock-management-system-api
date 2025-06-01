const express = require('express');
const jwt = require('jsonwebtoken');
const router = express.Router();

// Intenta cargar JWT_SECRET desde variables de entorno, con un fallback para desarrollo
// ¡ASEGÚRATE DE TENER UNA VARIABLE DE ENTORNO JWT_SECRET EN PRODUCCIÓN!
const JWT_SECRET = process.env.JWT_SECRET || 'tu_super_secreto_jwt_desarrollo';

router.post('/test-login', (req, res) => {
  try {
    const testUser = {
      // Si tu sistema de JWT o verificación de usuario usa 'id' o 'sub', inclúyelo.
      // Por ejemplo, podrías usar un ID único para el usuario de prueba:
      // userId: 'test-user-001',
      name: 'Usuario de Pruebas Admin',
      email: 'test-admin@example.com',
      role: 'admin', // Puedes cambiar esto a 'editor' o 'viewer' para probar otros roles
      picture: null // O una URL a una imagen placeholder: 'https://via.placeholder.com/150/7871F0/FFFFFF?Text=Test'
    };

    // Generar un token JWT estándar
    // El payload debe contener la información que tu middleware 'verifyToken' (o similar) espera encontrar.
    // Comúnmente se usa 'userId' (o 'id', 'sub'), 'role'.
    const payload = {
      userId: testUser.userId || `test-user-${Date.now()}`, // Asegura un ID único si no está definido
      name: testUser.name,
      email: testUser.email,
      role: testUser.role,
      picture: testUser.picture
    };

    const standardToken = jwt.sign(
      payload,
      JWT_SECRET,
      { expiresIn: '24h' } // Tiempo de expiración para el token de prueba
    );

    // El frontend actual tiene una lógica para parsear tokens que empiezan con "test-jwt-token-"
    // Esto es para extraer datos del usuario directamente del payload sin otra llamada de verificación,
    // lo cual es conveniente para el modo de prueba.
    const prefixedToken = `test-jwt-token-${standardToken}`;
    
    console.log(`[Auth Test Login] Usuario de prueba generado: ${testUser.name} (${testUser.role})`);
    console.log(`[Auth Test Login] Token (prefijado) generado: ${prefixedToken.substring(0, 50)}...`);

    res.json({
      success: true,
      token: prefixedToken, // Enviar el token con prefijo
      user: { // El frontend espera este objeto user
        name: testUser.name,
        email: testUser.email,
        role: testUser.role,
        picture: testUser.picture
      }
    });

  } catch (error) {
    console.error('[Auth Test Login] Error en /test-login:', error);
    res.status(500).json({ success: false, error: 'Error generando token de prueba' });
  }
});

module.exports = router; 