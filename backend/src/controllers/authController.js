import { OAuth2Client } from 'google-auth-library';
import jwt from 'jsonwebtoken';
import pool from '../config/database.js';
import { logActivity } from '../middleware/activityLogger.js';

const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

export const googleAuth = async (req, res) => {
  const { credential } = req.body;
  try {
    const ticket = await googleClient.verifyIdToken({
      idToken: credential,
      audience: process.env.GOOGLE_CLIENT_ID
    });

    const payload = ticket.getPayload();
    const { sub: googleId, email, name, picture } = payload;

    const userQuery = `SELECT * FROM admin_users WHERE email = $1`;
    let result = await pool.query(userQuery, [email]);
    let user;

    if (result.rows.length === 0) {
      // Si el usuario no existe, se crea como viewer
      const insertQuery = `
        INSERT INTO admin_users (google_id, email, name, picture, role, is_active, last_login)
        VALUES ($1, $2, $3, $4, $5, true, NOW())
        RETURNING *
      `;
      const newUserResult = await pool.query(insertQuery, [googleId, email, name, picture, 'viewer']);
      user = newUserResult.rows[0];
      await logActivity(user.id, 'register_google', 'user', user.id, { name: user.name }, req.ip, req.headers['user-agent']);
    } else {
      user = result.rows[0];
      if (!user.is_active) {
        return res.status(403).json({ error: 'Usuario inactivo. Contacte al administrador.' });
      }
      // Actualizar datos si es necesario
      const updateQuery = `
        UPDATE admin_users
        SET google_id = COALESCE($1, google_id), picture = COALESCE($2, picture), last_login = NOW()
        WHERE id = $3
        RETURNING *
      `;
      const updatedUserResult = await pool.query(updateQuery, [googleId, picture, user.id]);
      user = updatedUserResult.rows[0];
      await logActivity(user.id, 'login_google', 'user', user.id, { name: user.name }, req.ip, req.headers['user-agent']);
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, name: user.name, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.json({
      success: true,
      token,
      user: { 
        id: user.id, 
        email: user.email, 
        name: user.name, 
        picture: user.picture, 
        role: user.role 
      }
    });

  } catch (error) {
    console.error('Error en autenticación con Google:', error);
    res.status(401).json({ error: 'Autenticación fallida con Google' });
  }
};

export const verifyToken = async (req, res) => {
  // El middleware authenticateToken ya hizo la verificación
  res.json({
    success: true,
    user: {
      id: req.user.id,
      email: req.user.email,
      name: req.user.name,
      picture: req.user.picture,
      role: req.user.role
    }
  });
}; 