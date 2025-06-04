import express from 'express';
import { OAuth2Client } from 'google-auth-library';
import jwt from 'jsonwebtoken';
import pool from '../config/database.js';
import { sendWelcomeEmail } from '../services/emailService.js';
import crypto from 'crypto';

const router = express.Router();

// Configurar Google OAuth Client
const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// Intenta cargar JWT_SECRET desde variables de entorno, con un fallback para desarrollo
// ¡ASEGÚRATE DE TENER UNA VARIABLE DE ENTORNO JWT_SECRET EN PRODUCCIÓN!
const JWT_SECRET = process.env.JWT_SECRET || 'tu_super_secreto_jwt_desarrollo';

// Ruta de login de prueba (mantener para desarrollo)
router.post('/test-login', (req, res) => {
  try {
    const testUser = {
      // Si tu sistema de JWT o verificación de usuario usa 'id' o 'sub', inclúyelo.
      // Por ejemplo, podrías usar un ID único para el usuario de prueba:
      // userId: 'test-user-001',
      name: 'Usuario de Pruebas Admin',
      email: 'test-admin@example.com',
      role: 'admin', // Puedes cambiar esto a 'editor' o 'viewer' para probar otros roles
      picture: null, // O una URL a una imagen placeholder: 'https://via.placeholder.com/150/7871F0/FFFFFF?Text=Test'
      organization_id: 1,
      organization_name: 'Organización de Prueba',
      organization_slug: 'test-org'
    };

    // Generar un token JWT estándar
    // El payload debe contener la información que tu middleware 'verifyToken' (o similar) espera encontrar.
    // Comúnmente se usa 'userId' (o 'id', 'sub'), 'role'.
    const payload = {
      id: `test-user-${Date.now()}`,
      userId: `test-user-${Date.now()}`,
      name: testUser.name,
      email: testUser.email,
      role: testUser.role,
      picture: testUser.picture,
      organization_id: testUser.organization_id,
      organization_name: testUser.organization_name,
      organization_slug: testUser.organization_slug
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
        picture: testUser.picture,
        organization: {
          id: testUser.organization_id,
          name: testUser.organization_name,
          slug: testUser.organization_slug,
          plan: 'starter'
        }
      }
    });

  } catch (error) {
    console.error('[Auth Test Login] Error en /test-login:', error);
    res.status(500).json({ success: false, error: 'Error generando token de prueba' });
  }
});

// Login con Google OAuth
router.post('/google', async (req, res) => {
  const { credential } = req.body;
  
  try {
    // Verificar el token de Google
    const ticket = await googleClient.verifyIdToken({
      idToken: credential,
      audience: process.env.GOOGLE_CLIENT_ID
    });

    const payload = ticket.getPayload();
    const { sub: googleId, email, name, picture } = payload;

    // Verificar si el usuario está autorizado en alguna organización
    const authQuery = `
      SELECT 
        au.*,
        o.id as organization_id,
        o.name as organization_name,
        o.slug as organization_slug,
        o.subscription_plan,
        o.subscription_status,
        o.features
      FROM saas.authorized_users au
      JOIN saas.organizations o ON au.organization_id = o.id
      WHERE au.email = $1 
        AND au.status IN ('active', 'pending')
        AND o.subscription_status = 'active'
    `;
    
    const authResult = await pool.query(authQuery, [email]);
    
    if (authResult.rows.length === 0) {
      return res.status(403).json({ 
        error: 'No estás autorizado para acceder a este sistema. Contacta a tu administrador para obtener una invitación.',
        unauthorized: true 
      });
    }
    
    const authorizedUser = authResult.rows[0];
    
    // Si es la primera vez que se conecta (estado pending), activar la cuenta
    let userStatus = authorizedUser.status;
    if (userStatus === 'pending') {
      const activateQuery = `
        UPDATE saas.authorized_users
        SET 
          status = 'active',
          google_id = $1,
          name = COALESCE($2, name),
          picture = COALESCE($3, picture),
          invitation_accepted_at = NOW(),
          last_login = NOW(),
          login_count = COALESCE(login_count, 0) + 1,
          updated_at = NOW()
        WHERE id = $4
        RETURNING *
      `;
      
      const activateResult = await pool.query(activateQuery, [
        googleId, 
        name, 
        picture, 
        authorizedUser.id
      ]);
      
      const activatedUser = activateResult.rows[0];
      
      // Enviar email de bienvenida
      try {
        await sendWelcomeEmail({
          to: email,
          userName: name || email,
          organizationName: authorizedUser.organization_name
        });
      } catch (emailError) {
        console.error('Error enviando email de bienvenida:', emailError);
      }
      
      userStatus = 'active';
    } else {
      // Usuario ya existente, solo actualizar información
      const updateQuery = `
        UPDATE saas.authorized_users
        SET 
          google_id = COALESCE($1, google_id),
          name = COALESCE($2, name),
          picture = COALESCE($3, picture),
          last_login = NOW(),
          login_count = COALESCE(login_count, 0) + 1,
          updated_at = NOW()
        WHERE id = $4
      `;
      
      await pool.query(updateQuery, [googleId, name, picture, authorizedUser.id]);
    }
    
    // Crear token JWT con información completa
    const token = jwt.sign(
      {
        id: authorizedUser.id,
        email: authorizedUser.email,
        name: name || authorizedUser.name,
        role: authorizedUser.role,
        organization_id: authorizedUser.organization_id,
        organization_name: authorizedUser.organization_name,
        organization_slug: authorizedUser.organization_slug,
        subscription_plan: authorizedUser.subscription_plan,
        features: authorizedUser.features
      },
      JWT_SECRET,
      { expiresIn: '24h' }
    );
    
    res.json({
      success: true,
      token,
      user: {
        id: authorizedUser.id,
        email: authorizedUser.email,
        name: name || authorizedUser.name,
        picture: picture || authorizedUser.picture,
        role: authorizedUser.role,
        status: userStatus,
        organization: {
          id: authorizedUser.organization_id,
          name: authorizedUser.organization_name,
          slug: authorizedUser.organization_slug,
          plan: authorizedUser.subscription_plan,
          status: authorizedUser.subscription_status
        }
      }
    });
    
  } catch (error) {
    console.error('Error en autenticación con Google:', error);
    
    if (error.message && error.message.includes('Token used too early')) {
      return res.status(401).json({ 
        error: 'Token de Google inválido. Intenta nuevamente.',
        code: 'TOKEN_TOO_EARLY'
      });
    }
    
    res.status(401).json({ 
      error: 'Error de autenticación con Google. Verifica tu conexión e intenta nuevamente.',
      code: 'AUTH_FAILED'
    });
  }
});

// Verificar token de usuario
router.get('/verify', async (req, res) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({ error: 'Token no proporcionado' });
    }

    // Manejar tokens de prueba
    if (token.startsWith('test-jwt-token-')) {
      try {
        const actualToken = token.replace('test-jwt-token-', '');
        const decoded = jwt.verify(actualToken, JWT_SECRET);
        
        return res.json({
          success: true,
          user: {
            id: decoded.id,
            email: decoded.email,
            name: decoded.name,
            picture: decoded.picture,
            role: decoded.role,
            organization: {
              id: decoded.organization_id,
              name: decoded.organization_name,
              slug: decoded.organization_slug,
              plan: 'starter'
            }
          }
        });
      } catch (e) {
        return res.status(403).json({ error: 'Token de prueba inválido' });
      }
    }

    // Verificar token normal
    const decoded = jwt.verify(token, JWT_SECRET);
    
    // Verificar que el usuario sigue existiendo y está activo
    const userQuery = `
      SELECT 
        au.*,
        o.id as organization_id,
        o.name as organization_name,
        o.slug as organization_slug,
        o.subscription_plan,
        o.subscription_status
      FROM saas.authorized_users au
      JOIN saas.organizations o ON au.organization_id = o.id
      WHERE au.id = $1 
        AND au.status = 'active'
        AND o.subscription_status = 'active'
    `;
    
    const userResult = await pool.query(userQuery, [decoded.id]);
    
    if (userResult.rows.length === 0) {
      return res.status(403).json({ 
        error: 'Usuario no autorizado o suscripción inactiva',
        unauthorized: true 
      });
    }
    
    const user = userResult.rows[0];
    
    res.json({
      success: true,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        picture: user.picture,
        role: user.role,
        organization: {
          id: user.organization_id,
          name: user.organization_name,
          slug: user.organization_slug,
          plan: user.subscription_plan,
          status: user.subscription_status
        }
      }
    });
    
  } catch (error) {
    console.error('Error verificando token:', error);
    res.status(403).json({ error: 'Token inválido' });
  }
});

// Aceptar invitación
router.post('/accept-invitation', async (req, res) => {
  const { token: invitationToken, credential } = req.body;
  
  try {
    if (!invitationToken) {
      return res.status(400).json({ error: 'Token de invitación requerido' });
    }
    
    // Buscar la invitación
    const inviteQuery = `
      SELECT 
        au.*,
        o.name as organization_name,
        o.slug as organization_slug,
        o.subscription_plan
      FROM saas.authorized_users au
      JOIN saas.organizations o ON au.organization_id = o.id
      WHERE au.invitation_token = $1 
        AND au.status = 'pending'
        AND au.invitation_expires_at > NOW()
    `;
    
    const inviteResult = await pool.query(inviteQuery, [invitationToken]);
    
    if (inviteResult.rows.length === 0) {
      return res.status(400).json({ 
        error: 'Invitación inválida o expirada. Solicita una nueva invitación a tu administrador.',
        code: 'INVALID_INVITATION'
      });
    }
    
    const invitation = inviteResult.rows[0];
    
    // Si se proporciona credential de Google, verificarlo
    let googleData = null;
    if (credential) {
      try {
        const ticket = await googleClient.verifyIdToken({
          idToken: credential,
          audience: process.env.GOOGLE_CLIENT_ID
        });
        
        const payload = ticket.getPayload();
        googleData = {
          googleId: payload.sub,
          email: payload.email,
          name: payload.name,
          picture: payload.picture
        };
        
        // Verificar que el email coincide con la invitación
        if (googleData.email !== invitation.email) {
          return res.status(400).json({ 
            error: 'El email de Google no coincide con la invitación. Usa la cuenta correcta.',
            code: 'EMAIL_MISMATCH'
          });
        }
      } catch (error) {
        console.error('Error verificando Google credential:', error);
        return res.status(400).json({ 
          error: 'Error verificando credenciales de Google',
          code: 'GOOGLE_VERIFICATION_FAILED'
        });
      }
    }
    
    // Activar la cuenta
    const activateQuery = `
      UPDATE saas.authorized_users
      SET 
        status = 'active',
        google_id = COALESCE($1, google_id),
        name = COALESCE($2, name),
        picture = COALESCE($3, picture),
        invitation_accepted_at = NOW(),
        invitation_token = NULL,
        last_login = NOW(),
        login_count = 1,
        updated_at = NOW()
      WHERE id = $4
      RETURNING *
    `;
    
    const activateResult = await pool.query(activateQuery, [
      googleData?.googleId,
      googleData?.name,
      googleData?.picture,
      invitation.id
    ]);
    
    const activatedUser = activateResult.rows[0];
    
    // Enviar email de bienvenida
    try {
      await sendWelcomeEmail({
        to: activatedUser.email,
        userName: activatedUser.name || activatedUser.email,
        organizationName: invitation.organization_name
      });
    } catch (emailError) {
      console.error('Error enviando email de bienvenida:', emailError);
    }
    
    // Crear token JWT
    const token = jwt.sign(
      {
        id: activatedUser.id,
        email: activatedUser.email,
        name: activatedUser.name,
        role: activatedUser.role,
        organization_id: activatedUser.organization_id,
        organization_name: invitation.organization_name,
        organization_slug: invitation.organization_slug,
        subscription_plan: invitation.subscription_plan
      },
      JWT_SECRET,
      { expiresIn: '24h' }
    );
    
    res.json({
      success: true,
      message: '¡Bienvenido! Tu cuenta ha sido activada exitosamente.',
      token,
      user: {
        id: activatedUser.id,
        email: activatedUser.email,
        name: activatedUser.name,
        picture: activatedUser.picture,
        role: activatedUser.role,
        organization: {
          id: activatedUser.organization_id,
          name: invitation.organization_name,
          slug: invitation.organization_slug,
          plan: invitation.subscription_plan
        }
      }
    });
    
  } catch (error) {
    console.error('Error aceptando invitación:', error);
    res.status(500).json({ error: 'Error procesando la invitación' });
  }
});

// Validar token de invitación (sin aceptar)
router.get('/validate-invitation/:token', async (req, res) => {
  const { token: invitationToken } = req.params;
  
  try {
    const inviteQuery = `
      SELECT 
        au.email,
        au.role,
        au.invitation_expires_at,
        o.name as organization_name
      FROM saas.authorized_users au
      JOIN saas.organizations o ON au.organization_id = o.id
      WHERE au.invitation_token = $1 
        AND au.status = 'pending'
    `;
    
    const inviteResult = await pool.query(inviteQuery, [invitationToken]);
    
    if (inviteResult.rows.length === 0) {
      return res.status(404).json({ 
        error: 'Invitación no encontrada',
        code: 'INVITATION_NOT_FOUND'
      });
    }
    
    const invitation = inviteResult.rows[0];
    
    // Verificar si expiró
    if (new Date(invitation.invitation_expires_at) < new Date()) {
      return res.status(400).json({ 
        error: 'La invitación ha expirado',
        code: 'INVITATION_EXPIRED'
      });
    }
    
    res.json({
      success: true,
      invitation: {
        email: invitation.email,
        role: invitation.role,
        organizationName: invitation.organization_name,
        expiresAt: invitation.invitation_expires_at
      }
    });
    
  } catch (error) {
    console.error('Error validando invitación:', error);
    res.status(500).json({ error: 'Error validando invitación' });
  }
});

export default router; 