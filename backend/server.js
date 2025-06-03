import express from 'express';
import cors from 'cors';
import { pool } from './src/db/db.js';
import { OAuth2Client } from 'google-auth-library';
import jwt from 'jsonwebtoken';
import multer from 'multer';
import path from 'path';
import helmet from 'helmet';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import adminLoginRouter from './routes/adminLogin.js';
import reportsRouter from './src/routes/reports.js';
import { subDays, format } from 'date-fns';
import fs from 'fs';
import { setupStockNotifications } from './src/websocket/stockNotifications.js';

// Configuración para ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Explicitamente configurar dotenv para cargar .env desde el directorio del backend
const dotEnvPath = path.resolve(__dirname, '.env');

// ---- INICIO DIAGNÓSTICO FS ----
console.log('[FS DIAGNOSTIC] Intentando verificar existencia de:', dotEnvPath);
try {
  if (fs.existsSync(dotEnvPath)) {
    console.log('[FS DIAGNOSTIC] fs.existsSync dice: El archivo SÍ existe.');
    try {
      const fileContent = fs.readFileSync(dotEnvPath, 'utf8');
      console.log('[FS DIAGNOSTIC] fs.readFileSync leyó el archivo. Primeras 100 chars:', fileContent.substring(0, 100));
    } catch (readErr) {
      console.error('[FS DIAGNOSTIC] fs.readFileSync falló al leer el archivo:', readErr);
    }
  } else {
    console.warn('[FS DIAGNOSTIC] fs.existsSync dice: El archivo NO existe.');
  }
} catch (accessErr) {
  console.error('[FS DIAGNOSTIC] Error general al verificar la existencia del archivo con fs:', accessErr);
}
// ---- FIN DIAGNÓSTICO FS ----

const dotenvResult = dotenv.config({ path: dotEnvPath });

if (dotenvResult.error) {
  console.error('\n[DOTENV ERROR] Error al cargar el archivo .env:');
  console.error(dotenvResult.error);
  console.error('[DOTENV INFO] Se intentó cargar .env desde:', dotEnvPath);
  console.error('Por favor, asegúrate de que el archivo backend/.env exista, no esté vacío y tenga los permisos correctos.\n');
} else if (!dotenvResult.parsed || Object.keys(dotenvResult.parsed).length === 0) {
  console.warn('\n[DOTENV WARNING] El archivo .env se cargó pero está vacío o no contiene asignaciones válidas.');
  console.warn('[DOTENV INFO] Se cargó .env desde:', dotEnvPath);
  console.warn('[DOTENV INFO] Contenido parseado (si lo hay):', dotenvResult.parsed);
  console.warn('Por favor, verifica el contenido de backend/.env.\n');
} else {
  console.log('\n[DOTENV SUCCESS] Archivo .env cargado exitosamente desde:', dotEnvPath);
  // Opcional: listar las variables cargadas (sin contraseñas)
  // const loadedVars = { ...dotenvResult.parsed };
  // delete loadedVars.DB_PASSWORD; // No mostrar la contraseña
  // console.log('[DOTENV INFO] Variables cargadas:', loadedVars, '\n');
}

// DIAGNOSTIC LOGS - INICIO
console.log('[DIAGNÓSTICO ENV] DB_HOST:', process.env.DB_HOST);
console.log('[DIAGNÓSTICO ENV] DB_PORT:', process.env.DB_PORT);
console.log('[DIAGNÓSTICO ENV] DB_NAME:', process.env.DB_NAME);
console.log('[DIAGNÓSTICO ENV] DB_USER:', process.env.DB_USER);
// No imprimimos DB_PASSWORD por seguridad, pero verifica que esté en tu .env
// DIAGNOSTIC LOGS - FIN

const app = express();
const PORT = process.env.PORT || 4000;

// Configuración de Google OAuth
const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// Configuración de multer para subida de imágenes
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadPath = process.env.UPLOAD_PATH || 'uploads';
    cb(null, path.join(uploadPath, 'products/'));
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: parseInt(process.env.MAX_FILE_SIZE) || 5 * 1024 * 1024 }, // 5MB por defecto
  fileFilter: (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|webp/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);

    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error('Solo se permiten imágenes (jpeg, jpg, png, webp)'));
    }
  }
});

// Middleware
app.use(helmet()); // Ayuda a securizar la app con varios headers HTTP
app.use(compression()); // Comprime las respuestas HTTP

// Configuración de CORS con múltiples orígenes permitidos
const allowedOrigins = [
  'http://localhost:3001',
  'http://localhost:3002',
  'http://localhost:3003',
  'http://192.168.68.52:3001',
  'http://192.168.68.52:3002',
  'http://192.168.68.52:3003'
];

app.use(cors({
  origin: function (origin, callback) {
    // Permitir solicitudes sin origen (como Postman) o si el origen está en la lista
    if (!origin || allowedOrigins.indexOf(origin) !== -1) {
      callback(null, true);
    } else {
      callback(new Error('No permitido por CORS'));
    }
  },
  credentials: true
}));

app.use(express.json());
app.use('/uploads', express.static(process.env.UPLOAD_PATH || 'uploads'));

// Rate Limiting
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: 100, // Limita cada IP a 100 peticiones por ventana
  standardHeaders: true,
  legacyHeaders: false,
  message: 'Demasiadas peticiones desde esta IP, por favor intente de nuevo después de 15 minutos',
});
app.use('/api', apiLimiter);

// Middleware de autenticación
const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  let token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Token no proporcionado' });
  }

  const testTokenPrefix = 'test-jwt-token-';
  let isTestUserToken = false;

  if (token.startsWith(testTokenPrefix)) {
    token = token.substring(testTokenPrefix.length);
    isTestUserToken = true;
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    // Permitir ambos campos: id y userId
    const userId = decoded.userId || decoded.id;
    
    // Si es el usuario de prueba (identificado por el prefijo O por el ID en el token)
    if (isTestUserToken && userId === TEST_USER.id) {
      req.user = { ...TEST_USER, id: userId };
      console.log('[Auth Middleware] Test user authenticated:', req.user.name);
      next();
      return;
    } else if (userId === TEST_USER.id) {
      req.user = { ...TEST_USER, id: userId };
      console.warn('[Auth Middleware] Test user authenticated by ID match (prefix might have been lost):', req.user.name);
      next();
      return;
    }

    // Verificar si el usuario sigue activo o si su rol ha cambiado
    try {
      const userQuery = await pool.query('SELECT id, email, role, is_active FROM admin_users WHERE id = $1', [userId]);
      if (userQuery.rows.length === 0 || !userQuery.rows[0].is_active) {
          console.log('[Auth Middleware] User not found or inactive:', userId);
          return res.status(403).json({ error: 'Usuario no válido o inactivo.' });
      }
      req.user = userQuery.rows[0];
      console.log('[Auth Middleware] Real user authenticated:', req.user.email);
    } catch (dbError) {
      // Si falla la conexión a BD, usar datos del token para pruebas
      console.warn('Database connection failed, using token data for testing:', dbError.message);
      if ((decoded.email === TEST_USER.email) && (userId === TEST_USER.id)) {
         console.warn('[Auth Middleware] DB Error, but token matches TEST_USER structure. Treating as test user.');
         req.user = { ...TEST_USER, id: userId };
      } else {
        req.user = { id: userId, email: decoded.email, role: decoded.role, is_active: true };
      }
    }
    next();
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
        return res.status(401).json({ error: 'Token expirado' });
    }
    return res.status(403).json({ error: 'Token inválido' });
  }
};

// Middleware para verificar rol de admin
const requireAdmin = (req, res, next) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Acceso denegado. Se requiere rol de administrador.' });
  }
  next();
};

// Middleware para verificar rol de editor o admin
const requireEditorOrAdmin = (req, res, next) => {
  if (req.user.role !== 'admin' && req.user.role !== 'editor') {
    return res.status(403).json({ error: 'Acceso denegado. Se requiere rol de editor o administrador.' });
  }
  next();
};

// Helper para registrar actividad
const logActivity = async (userId, action, entityType, entityId, details, ipAddress, userAgent) => {
  try {
    await pool.query(
      `INSERT INTO activity_logs (user_id, action, entity_type, entity_id, entity_name, changes, ip_address, user_agent)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [userId, action, entityType, entityId, details?.name, details, ipAddress, userAgent]
    );
  } catch (error) {
    console.error('Error logging activity:', error);
  }
};

// ======================
// DATOS MOCK PARA PRUEBAS
// ======================
const MOCK_DATA = {
  categories: [
    { id: 1, name: 'Lácteos', icon_emoji: '🥛', is_active: true, sort_order: 1, product_count: 8, low_stock_count: 2, out_of_stock_count: 0 },
    { id: 2, name: 'Frutas y Verduras', icon_emoji: '🍎', is_active: true, sort_order: 2, product_count: 15, low_stock_count: 3, out_of_stock_count: 1 },
    { id: 3, name: 'Carnes', icon_emoji: '🥩', is_active: true, sort_order: 3, product_count: 12, low_stock_count: 1, out_of_stock_count: 0 },
    { id: 4, name: 'Panadería', icon_emoji: '🍞', is_active: true, sort_order: 4, product_count: 6, low_stock_count: 0, out_of_stock_count: 0 },
    { id: 5, name: 'Bebidas', icon_emoji: '🥤', is_active: true, sort_order: 5, product_count: 10, low_stock_count: 2, out_of_stock_count: 1 }
  ],
  products: [
    { id: 1, name: 'Leche Entera', description: 'Leche entera pasteurizada 1L', price: 2.50, stock_quantity: 25, min_stock_alert: 10, category_id: 1, category_name: 'Lácteos', category_icon: '🥛', brand: 'La Serenísima', barcode: '7790001234567', stock_status: 'normal', is_available: true, created_at: '2024-01-15T10:00:00Z' },
    { id: 2, name: 'Yogur Natural', description: 'Yogur natural sin azúcar 500g', price: 1.80, stock_quantity: 8, min_stock_alert: 15, category_id: 1, category_name: 'Lácteos', category_icon: '🥛', brand: 'Danone', barcode: '7790001234568', stock_status: 'low_stock', is_available: true, created_at: '2024-01-15T10:00:00Z' },
    { id: 3, name: 'Manzanas Rojas', description: 'Manzanas rojas frescas por kg', price: 3.20, stock_quantity: 0, min_stock_alert: 5, category_id: 2, category_name: 'Frutas y Verduras', category_icon: '🍎', brand: 'Local', barcode: '7790001234569', stock_status: 'out_of_stock', is_available: true, created_at: '2024-01-15T10:00:00Z' },
    { id: 4, name: 'Bananas', description: 'Bananas maduras por kg', price: 2.10, stock_quantity: 12, min_stock_alert: 8, category_id: 2, category_name: 'Frutas y Verduras', category_icon: '🍎', brand: 'Local', barcode: '7790001234570', stock_status: 'normal', is_available: true, created_at: '2024-01-15T10:00:00Z' },
    { id: 5, name: 'Carne Molida', description: 'Carne molida especial por kg', price: 8.50, stock_quantity: 6, min_stock_alert: 8, category_id: 3, category_name: 'Carnes', category_icon: '🥩', brand: 'Premium', barcode: '7790001234571', stock_status: 'low_stock', is_available: true, created_at: '2024-01-15T10:00:00Z' },
    { id: 6, name: 'Pan Lactal', description: 'Pan de molde integral 500g', price: 1.45, stock_quantity: 20, min_stock_alert: 5, category_id: 4, category_name: 'Panadería', category_icon: '🍞', brand: 'Bimbo', barcode: '7790001234572', stock_status: 'normal', is_available: true, created_at: '2024-01-15T10:00:00Z' },
    { id: 7, name: 'Coca Cola', description: 'Coca Cola 2L', price: 2.80, stock_quantity: 3, min_stock_alert: 10, category_id: 5, category_name: 'Bebidas', category_icon: '🥤', brand: 'Coca Cola', barcode: '7790001234573', stock_status: 'low_stock', is_available: true, created_at: '2024-01-15T10:00:00Z' },
    { id: 8, name: 'Agua Mineral', description: 'Agua mineral sin gas 1.5L', price: 1.20, stock_quantity: 50, min_stock_alert: 20, category_id: 5, category_name: 'Bebidas', category_icon: '🥤', brand: 'Villavicencio', barcode: '7790001234574', stock_status: 'normal', is_available: true, created_at: '2024-01-15T10:00:00Z' }
  ],
  stats: {
    totalProducts: 51,
    lowStockProducts: 8,
    outOfStockProducts: 3,
    totalInventoryValue: 12450.75,
    ordersToday: 15,
    revenueToday: 347.80,
    topSellingProducts: [
      { id: 1, name: 'Leche Entera', image_url: null, total_sold: 45 },
      { id: 6, name: 'Pan Lactal', image_url: null, total_sold: 38 },
      { id: 8, name: 'Agua Mineral', image_url: null, total_sold: 32 },
      { id: 4, name: 'Bananas', image_url: null, total_sold: 28 },
      { id: 7, name: 'Coca Cola', image_url: null, total_sold: 25 }
    ],
    stockAlerts: [
      { id: 3, product_name: 'Manzanas Rojas', current_stock: 0, minimum_stock: 5, category_name: 'Frutas y Verduras', image_url: null },
      { id: 2, product_name: 'Yogur Natural', current_stock: 8, minimum_stock: 15, category_name: 'Lácteos', image_url: null },
      { id: 5, product_name: 'Carne Molida', current_stock: 6, minimum_stock: 8, category_name: 'Carnes', image_url: null },
      { id: 7, product_name: 'Coca Cola', current_stock: 3, minimum_stock: 10, category_name: 'Bebidas', image_url: null }
    ]
  }
};

// Usuario de prueba
const TEST_USER = {
  id: 999,
  email: 'test@example.com',
  name: 'Usuario de Prueba',
  picture: 'https://via.placeholder.com/40',
  role: 'admin',
  is_active: true
};

// ======================
// RUTAS DE AUTENTICACIÓN
// ======================

// Ruta de login de prueba para testing
app.post('/api/auth/test-login', async (req, res) => {
  try {
    // Datos del usuario de prueba (puedes ajustarlos según necesidad)
    const testUserData = {
      userId: TEST_USER.id || 'test-user-001', // Asegúrate de que TEST_USER.id exista o usa un fallback
      name: TEST_USER.name || 'Usuario de Pruebas',
      email: TEST_USER.email || 'test@example.com',
      role: TEST_USER.role || 'admin',
      picture: TEST_USER.picture || null
    };

    const standardToken = jwt.sign(
      // Payload del token
      { 
        userId: testUserData.userId, // Es importante que este campo (userId) coincida con lo que espera tu middleware de autenticación general
        name: testUserData.name,
        email: testUserData.email,
        role: testUserData.role,
        picture: testUserData.picture
      },
      process.env.JWT_SECRET, // Usar siempre process.env.JWT_SECRET sin fallback
      { expiresIn: '24h' } // Tiempo de expiración del token
    );

    // **Añadir el prefijo esperado por el frontend para parseo especial del token de prueba**
    const prefixedToken = `test-jwt-token-${standardToken}`;

    console.log(`[Auth Test Login] Test user login successful for: ${testUserData.name} (${testUserData.role})`);

    res.json({
      success: true,
      token: prefixedToken, // Enviar el token con el prefijo
      user: { // El objeto user que espera el frontend
        id: testUserData.userId, // El frontend podría esperar 'id' aquí
        name: testUserData.name,
        email: testUserData.email,
        role: testUserData.role,
        picture: testUserData.picture
      }
    });
  } catch (error) {
    console.error('Error en login de prueba (/api/auth/test-login):', error);
    res.status(500).json({ success: false, error: 'Error interno en login de prueba' });
  }
});

app.post('/api/auth/google', async (req, res) => {
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
      user: { id: user.id, email: user.email, name: user.name, picture: user.picture, role: user.role }
    });

  } catch (error) {
    console.error('Error en autenticación con Google:', error);
    res.status(401).json({ error: 'Autenticación fallida con Google' });
  }
});

app.get('/api/auth/verify', authenticateToken, (req, res) => {
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
});

app.use('/api/auth', adminLoginRouter);
app.use('/api/reports', reportsRouter);

// ======================
// RUTAS DE PRODUCTOS
// ======================
app.get('/api/products', authenticateToken, async (req, res) => {
  try {
    const {
       search,
       category,
       lowStock,
       page = 1,
       limit = 20,
       sortBy = 'name',
       sortOrder = 'ASC'
    } = req.query;

    try {
      // Intentar usar la base de datos primero
      let query = `
        SELECT
          p.*,
          c.name as category_name,
          c.icon_emoji as category_icon,
          CASE
            WHEN p.stock_quantity = 0 THEN 'out_of_stock'
            WHEN p.stock_quantity <= p.min_stock_alert THEN 'low_stock'
            ELSE 'normal'
          END as stock_status,
          COUNT(*) OVER() as total_count
        FROM products p
        LEFT JOIN categories c ON p.category_id = c.id
        WHERE p.is_available = true
      `;

      const queryParams = [];
      let paramCount = 0;

      if (search) {
        paramCount++;
        query += ` AND (
          p.name ILIKE $${paramCount} OR
          p.brand ILIKE $${paramCount} OR
          p.barcode ILIKE $${paramCount} OR
          p.description ILIKE $${paramCount}
        )`;
        queryParams.push(`%${search}%`);
      }

      if (category) {
        paramCount++;
        query += ` AND p.category_id = $${paramCount}`;
        queryParams.push(category);
      }

      if (lowStock === 'true') {
        query += ` AND p.stock_quantity <= p.min_stock_alert AND p.stock_quantity > 0`;
      } else if (lowStock === 'out_of_stock') {
        query += ` AND p.stock_quantity = 0`;
      }

      const sortFieldMap = {
          'name': 'p.name',
          'price': 'p.price',
          'stock_quantity': 'p.stock_quantity',
          'created_at': 'p.created_at',
          'popularity_score': 'p.popularity_score'
      };
      const sortField = sortFieldMap[sortBy] || 'p.name';
      const order = sortOrder.toUpperCase() === 'DESC' ? 'DESC' : 'ASC';
      query += ` ORDER BY ${sortField} ${order}`;

      const offset = (parseInt(page) - 1) * parseInt(limit);
      paramCount++;
      query += ` LIMIT $${paramCount}`;
      queryParams.push(limit);
      paramCount++;
      query += ` OFFSET $${paramCount}`;
      queryParams.push(offset);

      const result = await pool.query(query, queryParams);

      const totalCount = result.rows.length > 0 ? parseInt(result.rows[0].total_count) : 0;
      const productsData = result.rows.map(row => {
        const { total_count, ...product } = row;
        return product;
      });

      res.json({
        success: true,
        data: productsData,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total: totalCount,
          totalPages: Math.ceil(totalCount / parseInt(limit))
        }
      });

    } catch (dbError) {
      // Si falla la BD, usar datos mock
      console.error('[Products Route DB Error] Fallo al conectar/consultar la base de datos:', dbError);
      console.warn('Database error, using mock data:', dbError.message);
      
      let filteredProducts = [...MOCK_DATA.products];

      // Aplicar filtros a datos mock
      if (search) {
        const searchLower = search.toLowerCase();
        filteredProducts = filteredProducts.filter(p => 
          p.name.toLowerCase().includes(searchLower) ||
          p.brand.toLowerCase().includes(searchLower) ||
          p.barcode.includes(search) ||
          p.description.toLowerCase().includes(searchLower)
        );
      }

      if (category) {
        filteredProducts = filteredProducts.filter(p => p.category_id == category);
      }

      if (lowStock === 'true') {
        filteredProducts = filteredProducts.filter(p => p.stock_status === 'low_stock');
      } else if (lowStock === 'out_of_stock') {
        filteredProducts = filteredProducts.filter(p => p.stock_status === 'out_of_stock');
      }

      // Ordenar
      if (sortBy === 'name') {
        filteredProducts.sort((a, b) => sortOrder === 'DESC' ? b.name.localeCompare(a.name) : a.name.localeCompare(b.name));
      } else if (sortBy === 'price') {
        filteredProducts.sort((a, b) => sortOrder === 'DESC' ? b.price - a.price : a.price - b.price);
      } else if (sortBy === 'stock_quantity') {
        filteredProducts.sort((a, b) => sortOrder === 'DESC' ? b.stock_quantity - a.stock_quantity : a.stock_quantity - b.stock_quantity);
      }

      // Paginación
      const startIndex = (parseInt(page) - 1) * parseInt(limit);
      const endIndex = startIndex + parseInt(limit);
      const paginatedProducts = filteredProducts.slice(startIndex, endIndex);

      res.json({
        success: true,
        data: paginatedProducts,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total: filteredProducts.length,
          totalPages: Math.ceil(filteredProducts.length / parseInt(limit))
        }
      });
    }

  } catch (error) {
    console.error('Error obteniendo productos:', error);
    res.status(500).json({ error: 'Error al obtener productos' });
  }
});

// ======================
// RUTAS DE CATEGORÍAS
// ======================
app.get('/api/categories', authenticateToken, async (req, res) => {
  try {
    try {
      // Intentar usar la base de datos primero
      const query = `
        SELECT
          c.*,
          COUNT(p.id) as product_count,
          COUNT(p.id) FILTER (WHERE p.is_available = true AND p.stock_quantity <= p.min_stock_alert AND p.stock_quantity > 0) as low_stock_count,
          COUNT(p.id) FILTER (WHERE p.is_available = true AND p.stock_quantity = 0) as out_of_stock_count
        FROM categories c
        LEFT JOIN products p ON c.id = p.category_id AND p.is_available = true
        WHERE c.is_active = true
        GROUP BY c.id
        ORDER BY c.sort_order ASC, c.name ASC
      `;
      const result = await pool.query(query);
      res.json({ success: true, data: result.rows });
    } catch (dbError) {
      // Si falla la BD, usar datos mock
      console.error('[Categories Route DB Error] Fallo al conectar/consultar la base de datos:', dbError);
      console.warn('Database error, using mock data:', dbError.message);
      res.json({ success: true, data: MOCK_DATA.categories });
    }
  } catch (error) {
    console.error('Error obteniendo categorías:', error);
    res.status(500).json({ error: 'Error al obtener categorías' });
  }
});

// ======================
// RUTAS DE DASHBOARD
// ======================
app.get('/api/dashboard/stats', authenticateToken, async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    const start = startDate ? new Date(startDate) : subDays(new Date(), 30);
    const end = endDate ? new Date(endDate) : new Date();

    try {
      // Intentar usar la base de datos primero
      const statsQuery = `
        WITH product_stats AS (
          SELECT
            COUNT(*) as total_products,
            COUNT(*) FILTER (WHERE is_available = true AND stock_quantity <= min_stock_alert AND stock_quantity > 0) as low_stock_products,
            COUNT(*) FILTER (WHERE is_available = true AND stock_quantity = 0) as out_of_stock_products,
            SUM(CASE WHEN is_available = true THEN stock_quantity * price ELSE 0 END) as total_inventory_value
          FROM products
        ),
        sales_stats AS (
          SELECT
            COUNT(DISTINCT o.id) as orders_today,
            SUM(oi.subtotal) as revenue_today
          FROM orders o
          JOIN order_items oi ON o.id = oi.order_id
          WHERE DATE(o.created_at) = CURRENT_DATE
          AND o.order_status IN ('delivered', 'completed', 'paid')
        ),
        stock_evolution AS (
          SELECT
            DATE(sm.created_at) as date,
            SUM(CASE WHEN sm.movement_type = 'in' THEN sm.quantity_change ELSE -sm.quantity_change END) as stock_change
          FROM stock_movements sm
          WHERE sm.created_at BETWEEN $1 AND $2
          GROUP BY DATE(sm.created_at)
          ORDER BY date
        ),
        sales_by_category AS (
          SELECT
            c.name,
            SUM(oi.quantity) as value
          FROM order_items oi
          JOIN products p ON oi.product_id = p.id
          JOIN categories c ON p.category_id = c.id
          JOIN orders o ON oi.order_id = o.id
          WHERE o.created_at BETWEEN $1 AND $2
          AND o.order_status IN ('delivered', 'completed', 'paid')
          GROUP BY c.name
        ),
        inventory_turnover AS (
          SELECT
            c.name as category,
            ROUND(AVG(COALESCE(s.units_sold_30d, 0) / NULLIF(p.stock_quantity, 0)), 2) as turnover
          FROM products p
          JOIN categories c ON p.category_id = c.id
          LEFT JOIN (
            SELECT
              oi.product_id,
              SUM(oi.quantity) as units_sold_30d
            FROM order_items oi
            JOIN orders o ON oi.order_id = o.id
            WHERE o.created_at >= CURRENT_DATE - INTERVAL '30 days'
            AND o.order_status IN ('delivered', 'completed', 'paid')
            GROUP BY oi.product_id
          ) s ON p.id = s.product_id
          WHERE p.is_available = true
          GROUP BY c.name
        ),
        top_selling_products AS (
          SELECT
            p.name,
            SUM(oi.quantity) as total_sold
          FROM order_items oi
          JOIN products p ON oi.product_id = p.id
          JOIN orders o ON oi.order_id = o.id
          WHERE o.created_at BETWEEN $1 AND $2
          AND o.order_status IN ('delivered', 'completed', 'paid')
          GROUP BY p.name
          ORDER BY total_sold DESC
          LIMIT 5
        )
        SELECT
          (SELECT total_products FROM product_stats) as "totalProducts",
          (SELECT low_stock_products FROM product_stats) as "lowStockProducts",
          (SELECT out_of_stock_products FROM product_stats) as "outOfStockProducts",
          (SELECT total_inventory_value FROM product_stats) as "totalInventoryValue",
          (SELECT orders_today FROM sales_stats) as "ordersToday",
          (SELECT revenue_today FROM sales_stats) as "revenueToday",
          (SELECT JSON_AGG(ROW_TO_JSON(se)) FROM stock_evolution se) as "stockEvolution",
          (SELECT JSON_AGG(ROW_TO_JSON(sc)) FROM sales_by_category sc) as "salesByCategory",
          (SELECT JSON_AGG(ROW_TO_JSON(it)) FROM inventory_turnover it) as "inventoryTurnover",
          (SELECT JSON_AGG(ROW_TO_JSON(tsp)) FROM top_selling_products tsp) as "topSellingProducts"
      `;

      const result = await pool.query(statsQuery, [start, end]);
      res.json({ success: true, data: result.rows[0] });
    } catch (dbError) {
      // Si falla la BD, usar datos mock
      console.error('[Dashboard Route DB Error] Fallo al conectar/consultar la base de datos:', dbError);
      console.warn('Database error, using mock data:', dbError.message);
      
      // Generar datos mock para las gráficas
      const mockStockEvolution = Array.from({ length: 30 }, (_, i) => ({
        date: format(subDays(new Date(), 29 - i), 'yyyy-MM-dd'),
        stock: Math.floor(Math.random() * 100) + 50
      }));

      const mockSalesByCategory = [
        { name: 'Lácteos', value: 150 },
        { name: 'Frutas y Verduras', value: 200 },
        { name: 'Carnes', value: 120 },
        { name: 'Panadería', value: 80 },
        { name: 'Bebidas', value: 180 }
      ];

      const mockInventoryTurnover = [
        { category: 'Lácteos', turnover: 2.5 },
        { category: 'Frutas y Verduras', turnover: 3.2 },
        { category: 'Carnes', turnover: 1.8 },
        { category: 'Panadería', turnover: 4.0 },
        { category: 'Bebidas', turnover: 2.8 }
      ];

      const mockTopSellingProducts = [
        { name: 'Leche Entera', total_sold: 45 },
        { name: 'Pan Lactal', total_sold: 38 },
        { name: 'Agua Mineral', total_sold: 32 },
        { name: 'Bananas', total_sold: 28 },
        { name: 'Coca Cola', total_sold: 25 }
      ];

      res.json({
        success: true,
        data: {
          ...MOCK_DATA.stats,
          stockEvolution: mockStockEvolution,
          salesByCategory: mockSalesByCategory,
          inventoryTurnover: mockInventoryTurnover,
          topSellingProducts: mockTopSellingProducts
        }
      });
    }
  } catch (error) {
    console.error('Error obteniendo estadísticas del dashboard:', error);
    res.status(500).json({ error: 'Error al obtener estadísticas' });
  }
});

// ======================
// RUTA HEALTH CHECK
// ======================
app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'UP', timestamp: new Date().toISOString() });
});

// ======================
// MANEJO DE ERRORES GLOBAL
// ======================
app.use((req, res, next) => {
  res.status(404).json({ error: 'Ruta no encontrada' });
});

app.use((err, req, res, next) => {
  console.error('Error no manejado:', err.stack);
  res.status(err.status || 500).json({
    error: 'Error interno del servidor',
    message: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

// ======================
// INICIO DEL SERVIDOR
// ======================
const server = app.listen(PORT, () => {
  console.log(`Servidor corriendo en puerto ${PORT}`);
  console.log(`Entorno: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Frontend URL: ${process.env.FRONTEND_URL}`);
  console.log(`Uploads path: ${path.resolve(process.env.UPLOAD_PATH || 'uploads')}`);
});

// Configurar WebSocket
const { sendStockAlert } = setupStockNotifications(server);

// Exportar sendStockAlert para uso en otros módulos
export { sendStockAlert };

// Graceful Shutdown
process.on('SIGTERM', () => {
  console.info('SIGTERM signal received: closing HTTP server')
  server.close(() => {
    console.log('HTTP server closed')
    pool.end(() => {
        console.log('Database pool closed');
        process.exit(0);
    });
  })
});

process.on('SIGINT', () => {
  console.info('SIGINT signal received: closing HTTP server')
  server.close(() => {
    console.log('HTTP server closed')
    pool.end(() => {
        console.log('Database pool closed');
        process.exit(0);
    });
  })
}); 