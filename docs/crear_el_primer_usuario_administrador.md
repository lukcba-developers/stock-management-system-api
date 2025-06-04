# 🚀 Guía: Crear el Primer Usuario Administrador

---

## 📝 Situación Actual

Tienes el sistema instalado pero **no hay ningún usuario administrador/propietario creado**.  
Necesitas crear el primer usuario que tendrá control total.

---

## 🛠️ Solución: 3 Opciones

---

### 🎯 Opción 1: Script de Inicialización (Recomendado)

Crea este script que se ejecuta **una sola vez**:

```javascript
// backend/scripts/create-first-admin.js
import { Pool } from 'pg';
import bcrypt from 'bcrypt';
import crypto from 'crypto';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';
import readline from 'readline';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Cargar variables de entorno
dotenv.config({ path: resolve(__dirname, '../.env') });

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false
});

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

const question = (query) => new Promise((resolve) => rl.question(query, resolve));

async function createFirstAdmin() {
  console.log('\n🚀 Creación del Primer Administrador\n');
  
  try {
    // Verificar si ya existe una organización
    const orgCheck = await pool.query('SELECT COUNT(*) FROM saas.organizations');
    if (orgCheck.rows[0].count > 0) {
      console.log('⚠️  Ya existe una organización en el sistema.');
      const continuar = await question('¿Deseas continuar? (s/n): ');
      if (continuar.toLowerCase() !== 's') {
        console.log('Operación cancelada.');
        process.exit(0);
      }
    }

    // Solicitar datos
    console.log('Por favor, ingresa los siguientes datos:\n');
    
    const orgName = await question('Nombre de la organización: ');
    const orgSlug = await question('ID único (ej: mi-supermercado): ');
    const adminEmail = await question('Email del administrador: ');
    const adminName = await question('Nombre del administrador: ');
    
    // Opción de autenticación
    console.log('\n¿Cómo deseas autenticarte?');
    console.log('1. Solo con Google (recomendado)');
    console.log('2. Email y contraseña + Google');
    const authOption = await question('Opción (1 o 2): ');
    
    let passwordHash = null;
    if (authOption === '2') {
      const password = await question('Contraseña: ');
      passwordHash = await bcrypt.hash(password, 10);
    }

    // Seleccionar plan
    console.log('\nPlanes disponibles:');
    console.log('1. Free (2 usuarios, 50 productos)');
    console.log('2. Starter (5 usuarios, 500 productos) - $29/mes');
    console.log('3. Professional (20 usuarios, 5000 productos) - $99/mes');
    console.log('4. Enterprise (ilimitado) - $299/mes');
    const planOption = await question('Selecciona plan (1-4): ');
    
    const plans = ['free', 'starter', 'professional', 'enterprise'];
    const selectedPlan = plans[parseInt(planOption) - 1] || 'free';

    // Confirmar datos
    console.log('\n📋 Resumen:');
    console.log(`Organización: ${orgName} (${orgSlug})`);
    console.log(`Administrador: ${adminName} <${adminEmail}>`);
    console.log(`Plan: ${selectedPlan}`);
    console.log(`Autenticación: ${authOption === '1' ? 'Google' : 'Email + Google'}`);
    
    const confirmar = await question('\n¿Los datos son correctos? (s/n): ');
    if (confirmar.toLowerCase() !== 's') {
      console.log('Operación cancelada.');
      process.exit(0);
    }

    // Iniciar transacción
    const client = await pool.connect();
    
    try {
      await client.query('BEGIN');

      // 1. Crear organización
      console.log('\n✅ Creando organización...');
      const orgResult = await client.query(`
        INSERT INTO saas.organizations (
          name, slug, subscription_plan, subscription_status,
          max_users, max_products, max_monthly_orders,
          settings, features
        ) 
        SELECT 
          $1, $2, $3, 'active',
          max_users, max_products, max_monthly_orders,
          '{"currency": "ARS", "timezone": "America/Argentina/Buenos_Aires"}'::jsonb,
          features
        FROM saas.subscription_plans
        WHERE name = $3
        RETURNING id
      `, [orgName, orgSlug, selectedPlan]);

      const organizationId = orgResult.rows[0].id;
      console.log(`   ID de organización: ${organizationId}`);

      // 2. Crear usuario autorizado
      console.log('✅ Creando usuario administrador...');
      const userResult = await client.query(`
        INSERT INTO saas.authorized_users (
          organization_id, email, name, role, status,
          invitation_accepted_at
        ) VALUES ($1, $2, $3, 'owner', 'active', NOW())
        RETURNING id
      `, [organizationId, adminEmail, adminName]);

      const userId = userResult.rows[0].id;
      console.log(`   ID de usuario: ${userId}`);

      // 3. Si se eligió email+contraseña, crear registro adicional
      if (passwordHash) {
        console.log('✅ Configurando autenticación por contraseña...');
        
        // Verificar si existe la tabla admin_users
        const tableExists = await client.query(`
          SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'stock' 
            AND table_name = 'admin_users'
          )
        `);

        if (tableExists.rows[0].exists) {
          await client.query(`
            INSERT INTO stock.admin_users (
              email, name, role, password_hash, is_active,
              organization_id
            ) VALUES ($1, $2, 'admin', $3, true, $4)
          `, [adminEmail, adminName, passwordHash, organizationId]);
        }
      }

      // 4. Crear datos iniciales
      console.log('✅ Creando datos iniciales...');
      
      // Categorías por defecto
      await client.query(`
        INSERT INTO stock.categories (name, icon_emoji, organization_id, sort_order)
        VALUES 
          ('Lácteos', '🥛', $1, 1),
          ('Frutas y Verduras', '🍎', $1, 2),
          ('Carnes', '🥩', $1, 3),
          ('Panadería', '🍞', $1, 4),
          ('Bebidas', '🥤', $1, 5)
        ON CONFLICT DO NOTHING
      `, [organizationId]);

      await client.query('COMMIT');
      
      console.log('\n🎉 ¡Administrador creado exitosamente!\n');
      console.log('📝 Instrucciones para acceder:');
      console.log('────────────────────────────────');
      console.log(`1. Abre: ${process.env.FRONTEND_URL || 'http://localhost:3001'}`);
      console.log(`2. Haz clic en "Iniciar sesión con Google"`);
      console.log(`3. Usa el email: ${adminEmail}`);
      
      if (authOption === '2') {
        console.log(`\n   O también puedes usar:`);
        console.log(`   - Email: ${adminEmail}`);
        console.log(`   - Contraseña: [la que ingresaste]`);
      }
      
      console.log('\n🔐 Importante:');
      console.log(`- Eres el propietario de "${orgName}"`);
      console.log('- Tienes acceso completo al sistema');
      console.log('- Puedes invitar a otros usuarios desde el panel');
      
      // Generar token de setup (opcional)
      const setupToken = crypto.randomBytes(32).toString('hex');
      await pool.query(`
        INSERT INTO shared.system_config (config_key, config_value, description)
        VALUES ('first_setup_token', $1, 'Token de configuración inicial')
        ON CONFLICT (config_key) DO UPDATE SET config_value = $1
      `, [setupToken]);
      
      console.log(`\n🔑 Token de configuración: ${setupToken}`);
      console.log('   (Guárdalo, es útil para configuraciones futuras)\n');

    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    console.error('Detalles:', error);
  } finally {
    rl.close();
    pool.end();
  }
}

// Ejecutar
createFirstAdmin();
```

**Para ejecutarlo:**

```bash
cd backend
node scripts/create-first-admin.js
```

---

### 💾 Opción 2: Comando SQL Directo

Si prefieres hacerlo directamente en la base de datos:

```sql
-- 1. Crear la organización
INSERT INTO saas.organizations (
    name, 
    slug, 
    subscription_plan,
    subscription_status,
    max_users,
    max_products,
    max_monthly_orders
) VALUES (
    'Mi Supermercado',          -- Cambia esto
    'mi-supermercado',          -- Cambia esto (sin espacios, minúsculas)
    'professional',             -- o 'free', 'starter', 'enterprise'
    'active',
    20,
    5000,
    10000
) RETURNING id;

-- Supongamos que retorna id = 1

-- 2. Crear el usuario autorizado
INSERT INTO saas.authorized_users (
    organization_id,
    email,
    name,
    role,
    status,
    invitation_accepted_at
) VALUES (
    1,                          -- El ID de la organización creada
    'tu-email@gmail.com',       -- TU EMAIL DE GOOGLE
    'Tu Nombre',                -- Tu nombre
    'owner',                    -- Rol de propietario
    'active',                   -- Estado activo
    NOW()                       -- Ya aceptado
);

---

### 🌐 Opción 3: API de Setup Inicial

Agrega esta ruta especial que solo funciona si no hay organizaciones:

```javascript
// backend/src/routes/setup.js
import express from 'express';
import bcrypt from 'bcrypt';
import crypto from 'crypto';

const router = express.Router();

// Endpoint de setup inicial (solo funciona si no hay organizaciones)
router.post('/initial-setup', async (req, res) => {
  const {
    // Datos de la organización
    organizationName,
    organizationSlug,
    
    // Datos del admin
    adminEmail,
    adminName,
    adminPassword, // Opcional
    
    // Plan
    plan = 'starter',
    
    // Token de seguridad (opcional)
    setupToken
  } = req.body;

  try {
    // Verificar que no existan organizaciones
    const checkOrg = await pool.query('SELECT COUNT(*) as count FROM saas.organizations');
    if (checkOrg.rows[0].count > 0) {
      
      // Si hay un token de setup válido, permitir
      if (setupToken) {
        const tokenCheck = await pool.query(
          'SELECT config_value FROM shared.system_config WHERE config_key = $1',
          ['first_setup_token']
        );
        
        if (!tokenCheck.rows[0] || tokenCheck.rows[0].config_value !== setupToken) {
          return res.status(403).json({ 
            error: 'Setup ya realizado. Token inválido.' 
          });
        }
      } else {
        return res.status(403).json({ 
          error: 'El sistema ya fue configurado. Contacta al administrador.' 
        });
      }
    }

    // Validaciones
    if (!organizationName || !organizationSlug || !adminEmail || !adminName) {
      return res.status(400).json({ 
        error: 'Faltan datos requeridos' 
      });
    }

    // Validar formato de email
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(adminEmail)) {
      return res.status(400).json({ 
        error: 'Email inválido' 
      });
    }

    // Iniciar transacción
    const client = await pool.connect();
    
    try {
      await client.query('BEGIN');

      // 1. Obtener configuración del plan
      const planQuery = await client.query(
        'SELECT * FROM saas.subscription_plans WHERE name = $1',
        [plan]
      );
      
      if (planQuery.rows.length === 0) {
        throw new Error('Plan inválido');
      }

      const planConfig = planQuery.rows[0];

      // 2. Crear organización
      const orgResult = await client.query(`
        INSERT INTO saas.organizations (
          name, slug, subscription_plan, subscription_status,
          max_users, max_products, max_monthly_orders,
          features, settings
        ) VALUES ($1, $2, $3, 'active', $4, $5, $6, $7, $8)
        RETURNING *
      `, [
        organizationName,
        organizationSlug,
        plan,
        planConfig.max_users,
        planConfig.max_products,
        planConfig.max_monthly_orders,
        planConfig.features,
        {
          currency: 'ARS',
          timezone: 'America/Argentina/Buenos_Aires',
          dateFormat: 'DD/MM/YYYY'
        }
      ]);

      const organization = orgResult.rows[0];

      // 3. Crear usuario autorizado
      const userResult = await client.query(`
        INSERT INTO saas.authorized_users (
          organization_id, email, name, role, status,
          invitation_accepted_at
        ) VALUES ($1, $2, $3, 'owner', 'active', NOW())
        RETURNING *
      `, [organization.id, adminEmail, adminName]);

      const user = userResult.rows[0];

      // 4. Si se proporcionó contraseña, crear en admin_users
      if (adminPassword) {
        const passwordHash = await bcrypt.hash(adminPassword, 10);
        
        await client.query(`
          INSERT INTO stock.admin_users (
            email, name, role, password_hash, is_active,
            organization_id
          ) VALUES ($1, $2, 'admin', $3, true, $4)
          ON CONFLICT (email) DO UPDATE SET
            password_hash = $3,
            organization_id = $4
        `, [adminEmail, adminName, passwordHash, organization.id]);
      }

      // 5. Crear datos iniciales
      await client.query(`
        INSERT INTO stock.categories (name, icon_emoji, organization_id, sort_order)
        VALUES 
          ('Lácteos', '🥛', $1, 1),
          ('Frutas y Verduras', '🍎', $1, 2),
          ('Carnes', '🥩', $1, 3),
          ('Panadería', '🍞', $1, 4),
          ('Bebidas', '🥤', $1, 5)
      `, [organization.id]);

      // 6. Generar token para futuros setups
      const newSetupToken = crypto.randomBytes(32).toString('hex');
      await client.query(`
        INSERT INTO shared.system_config (config_key, config_value)
        VALUES ('first_setup_token', $1)
        ON CONFLICT (config_key) DO UPDATE SET config_value = $1
      `, [newSetupToken]);

      await client.query('COMMIT');

      res.json({
        success: true,
        message: 'Sistema configurado exitosamente',
        data: {
          organization: {
            id: organization.id,
            name: organization.name,
            slug: organization.slug,
            plan: organization.subscription_plan
          },
          admin: {
            id: user.id,
            email: user.email,
            name: user.name,
            role: user.role
          },
          setupToken: newSetupToken,
          loginUrl: `${process.env.FRONTEND_URL}/login`
        }
      });

    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }

  } catch (error) {
    console.error('Error en setup inicial:', error);
    res.status(500).json({ 
      error: 'Error al configurar el sistema',
      details: error.message 
    });
  }
});

// Endpoint para verificar si necesita setup
router.get('/needs-setup', async (req, res) => {
  try {
    const result = await pool.query('SELECT COUNT(*) as count FROM saas.organizations');
    const needsSetup = result.rows[0].count === 0;
    
    res.json({
      needsSetup,
      message: needsSetup ? 'El sistema requiere configuración inicial' : 'Sistema configurado'
    });
    
  } catch (error) {
    console.error('Error verificando setup:', error);
    res.status(500).json({ error: 'Error al verificar estado del sistema' });
  }
});

export default router;
```

Luego agrega la ruta en el servidor principal:

```javascript
// backend/server.js
import setupRouter from './src/routes/setup.js';
app.use('/api/setup', setupRouter);
```

---

### 🖥️ Frontend: Página de Setup Inicial

```jsx
// frontend/src/components/InitialSetup.jsx
import React, { useState, useEffect } from 'react';
import { Building2, User, Mail, Lock, Rocket } from 'lucide-react';
import axios from 'axios';

const InitialSetup = ({ onSetupComplete }) => {
  const [formData, setFormData] = useState({
    organizationName: '',
    organizationSlug: '',
    adminEmail: '',
    adminName: '',
    adminPassword: '',
    plan: 'starter'
  });
  
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const response = await axios.post('/api/setup/initial-setup', formData);
      
      if (response.data.success) {
        alert(`
          ✅ Sistema configurado exitosamente!
          
          Organización: ${response.data.data.organization.name}
          Admin: ${response.data.data.admin.email}
          
          Ahora puedes iniciar sesión con Google usando el email registrado.
          
          Token de setup: ${response.data.data.setupToken}
          (Guárdalo en un lugar seguro)
        `);
        
        onSetupComplete(response.data.data);
      }
    } catch (error) {
      setError(error.response?.data?.error || 'Error al configurar el sistema');
    } finally {
      setLoading(false);
    }
  };

  const generateSlug = (name) => {
    return name.toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '');
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-xl p-8 max-w-2xl w-full">
        <div className="text-center mb-8">
          <Rocket className="w-16 h-16 text-indigo-600 mx-auto mb-4" />
          <h1 className="text-3xl font-bold text-gray-900 mb-2">
            Configuración Inicial
          </h1>
          <p className="text-gray-600">
            Configura tu primera organización y usuario administrador
          </p>
        </div>

        {error && (
          <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg text-red-700">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-6">
          {/* Datos de la Organización */}
          <div>
            <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
              <Building2 className="w-5 h-5" />
              Datos de la Organización
            </h3>
            
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Nombre de la Organización *
                </label>
                <input
                  type="text"
                  value={formData.organizationName}
                  onChange={(e) => {
                    setFormData({
                      ...formData,
                      organizationName: e.target.value,
                      organizationSlug: generateSlug(e.target.value)
                    });
                  }}
                  className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-indigo-500"
                  placeholder="Mi Supermercado"
                  required
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  ID Único (slug) *
                </label>
                <input
                  type="text"
                  value={formData.organizationSlug}
                  onChange={(e) => setFormData({...formData, organizationSlug: e.target.value})}
                  className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-indigo-500"
                  placeholder="mi-supermercado"
                  pattern="[a-z0-9-]+"
                  required
                />
                <p className="text-xs text-gray-500 mt-1">
                  Solo letras minúsculas, números y guiones
                </p>
              </div>
            </div>
          </div>

          {/* Datos del Administrador */}
          <div>
            <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
              <User className="w-5 h-5" />
              Datos del Administrador
            </h3>
            
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Nombre Completo *
                </label>
                <input
                  type="text"
                  value={formData.adminName}
                  onChange={(e) => setFormData({...formData, adminName: e.target.value})}
                  className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-indigo-500"
                  placeholder="Juan Pérez"
                  required
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Email (debe ser cuenta de Google) *
                </label>
                <input
                  type="email"
                  value={formData.adminEmail}
                  onChange={(e) => setFormData({...formData, adminEmail: e.target.value})}
                  className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-indigo-500"
                  placeholder="admin@miempresa.com"
                  required
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Contraseña (opcional)
                </label>
                <input
                  type="password"
                  value={formData.adminPassword}
                  onChange={(e) => setFormData({...formData, adminPassword: e.target.value})}
                  className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-indigo-500"
                  placeholder="Dejar vacío para usar solo Google"
                />
                <p className="text-xs text-gray-500 mt-1">
                  Si no ingresas contraseña, solo podrás acceder con Google
                </p>
              </div>
            </div>
          </div>

          {/* Selección de Plan */}
          <div>
            <h3 className="text-lg font-semibold mb-4">Plan Inicial</h3>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {[
                { value: 'free', name: 'Gratis', users: 2, products: 50 },
                { value: 'starter', name: 'Starter', users: 5, products: 500 },
                { value: 'professional', name: 'Professional', users: 20, products: 5000 },
                { value: 'enterprise', name: 'Enterprise', users: '∞', products: '∞' }
              ].map(plan => (
                <label
                  key={plan.value}
                  className={`
                    p-4 border rounded-lg cursor-pointer transition-all
                    ${formData.plan === plan.value ? 'border-indigo-500 bg-indigo-50' : 'border-gray-300'}
                  `}
                >
                  <input
                    type="radio"
                    name="plan"
                    value={plan.value}
                    checked={formData.plan === plan.value}
                    onChange={(e) => setFormData({...formData, plan: e.target.value})}
                    className="sr-only"
                  />
                  <div className="font-semibold">{plan.name}</div>
                  <div className="text-sm text-gray-600">
                    {plan.users} usuarios • {plan.products} productos
                  </div>
                </label>
              ))}
            </div>
          </div>

          {/* Botón de Submit */}
          <button
            type="submit"
            disabled={loading}
            className={`
              w-full py-3 px-4 rounded-lg font-semibold text-white
              ${loading 
                ? 'bg-gray-400 cursor-not-allowed' 
                : 'bg-indigo-600 hover:bg-indigo-700'}
            `}
          >
            {loading ? 'Configurando...' : 'Completar Configuración'}
          </button>
        </form>
      </div>
    </div>
  );
};

export default InitialSetup;
```

---

## 🔄 Flujo Completo de Primer Acceso

1. Detectar si necesita setup:
    ```javascript
    // En App.jsx principal
    useEffect(() => {
      checkNeedsSetup();
    }, []);

    const checkNeedsSetup = async () => {
      try {
        const response = await axios.get('/api/setup/needs-setup');
        if (response.data.needsSetup) {
          setShowSetupWizard(true);
        }
      } catch (error) {
        console.error('Error checking setup:', error);
      }
    };
    ```
2. Usuario completa el setup.
3. Sistema crea organización y admin.
4. Redirige al login normal.
5. Admin hace login con Google.
6. ¡Listo! Ahora puede invitar más usuarios.

---

## ✅ Resumen

La **Opción 1 (Script)** es la más segura y recomendada porque:

- ✅ Valida todo antes de crear
- ✅ Muestra confirmaciones
- ✅ Genera token de seguridad
- ✅ Crea datos iniciales

**Solo ejecuta:**

```bash
cd backend
node scripts/create-first-admin.js
```
