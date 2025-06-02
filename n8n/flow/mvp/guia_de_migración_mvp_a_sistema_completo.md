# 🚀 Guía de Migración: MVP a Sistema Completo

## 📋 Tabla de Contenidos

1.  [Visión General](#visión-general)
2.  [Arquitectura Comparativa](#arquitectura-comparativa)
3.  [Funcionalidades y Migración](#funcionalidades-y-migración)
4.  [Proceso de Migración](#proceso-de-migración)
5.  [Validación y Testing](#validación-y-testing)
6.  [Rollback Strategy](#rollback-strategy)
7.  [Métricas de Éxito](#métricas-de-éxito)
8.  [Contactos de Emergencia](#contactos-de-emergencia)
9.  [Scripts de Migración](#scripts-de-migración-mvp-a-sistema-completo)

## 🎯 Visión General

Esta guía documenta el proceso de migración desde el MVP de WhatsApp Commerce hasta el sistema completo con todas las optimizaciones y funcionalidades avanzadas.

### Objetivos de la Migración

-   ✅ Mantener el servicio operativo durante la migración
-   ✅ Migrar funcionalidades de forma incremental
-   ✅ Validar cada fase antes de continuar
-   ✅ Mantener compatibilidad con datos existentes

## 🏗️ Arquitectura Comparativa

### MVP Architecture

```mermaid
graph LR
    WA[WhatsApp Webhook] --> N8N_Basic[N8N (Basic)]
    N8N_Basic --> PG_Simple[PostgreSQL (Simple)]
    WA --> StockAPI[Stock Mgmt API]
```

### Sistema Completo Architecture

```mermaid
graph TD
    WA[WhatsApp Webhook] --> N8N_Queue[N8N Queue (Workers)]
    N8N_Queue --> Redis[Redis (Cache)]
    N8N_Queue --> PG_Optimized[PostgreSQL (Optimized)]
    WA --> AI_Providers[AI Providers (Multiple)]
```

## 📊 Funcionalidades y Migración

### 1. **Parseo de Mensajes**

| Aspecto            | MVP               | Sistema Completo        | Impacto   |
| ------------------ | ----------------- | ----------------------- | --------- |
| **Tipos soportados** | text, interactive | Todos + multimedia      | 🟢 Bajo   |
| **Validación**     | Básica            | Avanzada con hash       | 🟡 Medio  |
| **Performance**    | ~50ms             | ~20ms                   | 🟢 Bajo   |

**Nodos a migrar:**

-   Reemplazar: `parse_message_mvp`
-   Por: `parse_message_optimized`

**Consideraciones:**

-   Retrocompatible con mensajes existentes
-   No requiere cambios en BD
-   Mejora automática de performance

### 2. **Rate Limiting**

| Aspecto          | MVP           | Sistema Completo     | Impacto   |
| ---------------- | ------------- | -------------------- | --------- |
| **Implementación** | No incluido   | In-memory + DB       | 🔴 Alto   |
| **Límites**      | N/A           | 5 msg/min, 100/hora  | 🟡 Medio  |
| **Storage**      | N/A           | Redis + PostgreSQL   | 🔴 Alto   |

**Nodos a agregar:**

-   `optimized_rate_limiter` después de parseo
-   `filter_skip_processing` para manejar límites

**Consideraciones:**

-   Requiere Redis operativo
-   Configurar límites según plan de usuario
-   Implementar notificaciones de límite alcanzado

### 3. **Sistema de Sesiones**

| Aspecto       | MVP              | Sistema Completo     | Impacto   |
| ------------- | ---------------- | -------------------- | --------- |
| **Storage**   | PostgreSQL only  | Redis + PostgreSQL   | 🔴 Alto   |
| **TTL**       | 2 horas fijo     | Configurable         | 🟢 Bajo   |
| **Performance** | ~100ms           | ~10ms                | 🟡 Medio  |

**Nodos a migrar:**

-   Reemplazar: `get_session_mvp`
-   Por: `redis_cache_manager_consolidated`

**Script de migración de sesiones:**

```sql
-- Migrar sesiones existentes a formato optimizado
UPDATE customer_sessions
SET
  context_data = jsonb_set(
    COALESCE(context_data, '{}'::jsonb),
    '{migrated_from_mvp}',
    'true'
  ),
  updated_at = NOW()
WHERE context_data IS NULL
   OR NOT (context_data ? 'session_version');
```

### 4. **Detección de Intenciones**

| Aspecto   | MVP            | Sistema Completo    | Impacto      |
|-----------|----------------|---------------------|--------------|
| Método    | Palabras clave | AI Multi-provider   | 🔴 Alto      |
| Precisión | ~70%           | ~95%                | 🟢 Positivo  |
| Latencia  | <10ms          | 50-300ms            | 🟡 Medio     |
| Costo     | $0             | $0.001-0.01/req     | 🔴 Alto      |

**Nodos a migrar:**

-   Reemplazar: `intent_detection_mvp`
-   Por: `ai_provider_ultra_optimized`

**Configuración requerida:**

```javascript
// Providers configuration
const AI_PROVIDERS = {
  deepseek: { enabled: true, apiKey: process.env.DEEPSEEK_API_KEY },
  gemini: { enabled: true, apiKey: process.env.GEMINI_API_KEY },
  openai: { enabled: false, apiKey: process.env.OPENAI_API_KEY }
};
```

### 5. **Gestión de Categorías**

| Aspecto  | MVP    | Sistema Completo      | Impacto   |
|----------|--------|-----------------------|-----------|
| Cache    | No     | Redis 30 min          | 🟡 Medio  |
| Query    | Simple | Optimizada con MV     | 🟢 Bajo   |
| Features | Básicas| Destacados, ofertas   | 🟢 Bajo   |

**Nodos a agregar:**

-   `optimized_category_cache` antes de DB query
-   Actualizar query para usar vista materializada

### 6. **Búsqueda de Productos**

| Aspecto     | MVP         | Sistema Completo        | Impacto     |
|-------------|-------------|-------------------------|-------------|
| Método      | LIKE simple | Full-text + scoring     | 🟡 Medio    |
| Performance | ~200ms      | ~50ms                   | 🟢 Positivo |
| Relevancia  | Básica      | Avanzada con ML         | 🟢 Positivo |

**Nodos a migrar:**

-   Reemplazar: `search_products_mvp`
-   Por: `ultra_optimized_product_search`

**Índices requeridos:**

```sql
-- Crear índices para búsqueda optimizada
CREATE INDEX CONCURRENTLY idx_products_search_vector
ON products USING GIN(to_tsvector('spanish', name || ' ' || COALESCE(description, '')));

CREATE INDEX CONCURRENTLY idx_products_popularity
ON products(popularity_score DESC)
WHERE is_available = true;
```

### 7. **Gestión de Carrito**

| Aspecto    | MVP          | Sistema Completo     | Impacto   |
|------------|--------------|----------------------|-----------|
| Storage    | Session JSON | Redis + validación   | 🔴 Alto   |
| Validación | Mínima       | Stock real-time      | 🟡 Medio  |
| Features   | Add/View     | CRUD completo        | 🟡 Medio  |

**Nodos a agregar:**

-   Flow 5 completo para gestión avanzada
-   Validación de stock en tiempo real
-   Cálculo de envío y descuentos

### 8. **Proceso de Checkout**

| Aspecto      | MVP | Sistema Completo                | Impacto   |
|--------------|-----|---------------------------------|-----------|
| Incluido     | No  | Sí, completo                    | 🔴 Alto   |
| Pasos        | N/A | Dirección, pago, confirmación   | 🔴 Alto   |
| Integraciones| N/A | Pasarelas de pago               | 🔴 Alto   |

**Nodos a implementar:**

-   `optimized_checkout_processor`
-   Integración con pasarelas de pago
-   Validación de dirección
-   Generación de orden

### 9. **Sistema de Métricas**

| Aspecto   | MVP | Sistema Completo    | Impacto   |
|-----------|-----|---------------------|-----------|
| Eventos   | No  | Event sourcing      | 🟡 Medio  |
| Analytics | No  | Real-time           | 🟡 Medio  |
| Reportes  | No  | Dashboard completo  | 🟢 Bajo   |

**Nodos a agregar:**

-   `lightweight_metrics` en cada flujo
-   `record_intent_event` para analytics
-   Integración con sistema de reportes

## 🔄 Proceso de Migración

### Fase 1: Preparación (1-2 días)

-   Backup completo de datos actuales
-   Configurar Redis en ambiente de producción
-   Crear índices requeridos en PostgreSQL
-   Configurar API keys para AI providers
-   Setup monitoring para nueva arquitectura

### Fase 2: Migración de Infraestructura (2-3 días)

-   Deploy Redis cluster
-   Actualizar PostgreSQL con nuevas tablas/vistas
-   Configurar N8N en modo queue
-   Setup workers para procesamiento paralelo

### Fase 3: Migración de Flujos (5-7 días)

-   **Día 1-2**: Parseo y Rate Limiting
-   **Día 3**: Sistema de Sesiones
-   **Día 4**: AI Integration
-   **Día 5**: Búsqueda y Categorías
-   **Día 6-7**: Carrito y Checkout

### Fase 4: Testing y Validación (2-3 días)

-   Testing funcional de cada componente
-   Pruebas de carga con tráfico simulado
-   Validación de métricas
-   User Acceptance Testing

### Fase 5: Go Live (1 día)

-   Migración gradual del tráfico
-   Monitoreo intensivo
-   Rollback plan activo
-   Comunicación a usuarios

## ✅ Validación y Testing

### Checklist de Validación por Componente

-   **Parseo de Mensajes**
    -   ✓ Mensajes de texto procesados correctamente
    -   ✓ Mensajes interactivos funcionando
    -   ✓ Multimedia manejado sin errores
    -   ✓ Hashes únicos generados
-   **Rate Limiting**
    -   ✓ Límites aplicados correctamente
    -   ✓ Mensajes de límite alcanzado
    -   ✓ Reset de contadores funcionando
    -   ✓ Logs de rate limit activos
-   **Sesiones**
    -   ✓ Migración de sesiones existentes
    -   ✓ Cache hit rate > 80%
    -   ✓ TTL funcionando correctamente
    -   ✓ Sincronización Redis-PostgreSQL
-   **AI Integration**
    -   ✓ Fallback a keywords si AI falla
    -   ✓ Circuit breaker activo
    -   ✓ Latencia < 500ms p95
    -   ✓ Precisión > 90%

## 🔄 Rollback Strategy

### Plan de Rollback por Fase

-   **Rollback Inmediato (< 5 min)**
    -   Switch de tráfico a flujo MVP
    -   Mantener datos en ambos sistemas
    -   Alertas automáticas activas
-   **Rollback Parcial (< 30 min)**
    -   Desactivar componentes problemáticos
    -   Fallback a implementación MVP
    -   Mantener features no afectadas
-   **Rollback Completo (< 2 horas)**
    -   Restore de backup pre-migración
    -   Revertir cambios de infraestructura
    -   Comunicación a usuarios afectados

### Comandos de Rollback

```bash
# Rollback inmediato - Switch de tráfico
n8n workflow:deactivate "Sistema Completo"
n8n workflow:activate "MVP WhatsApp Commerce"

# Rollback de sesiones a PostgreSQL only
redis-cli FLUSHDB
UPDATE system_config SET value = 'false' WHERE key = 'use_redis_sessions';

# Rollback de AI a keywords
UPDATE system_config SET value = 'false' WHERE key = 'use_ai_providers';
```

## 📈 Métricas de Éxito

| Métrica                   | Target   | Crítico |
|---------------------------|----------|---------|
| Uptime durante migración  | > 99.9%  | < 99%   |
| Latencia p95              | < 500ms  | > 1000ms|
| Error rate                | < 0.1%   | > 1%    |
| AI accuracy               | > 90%    | < 80%   |
| Cache hit rate            | > 80%    | < 60%   |
| User satisfaction         | > 4.5/5  | < 4.0/5 |

## 🚨 Contactos de Emergencia

-   Technical Lead: `[contacto]`
-   DevOps On-Call: `[contacto]`
-   Business Owner: `[contacto]`
-   Escalation Path: L1 → L2 → L3 → Management

---

## 🛠️ Scripts de Migración: MVP a Sistema Completo

### 📋 Índice de Scripts

1.  [Pre-migración: Validación y Backup](#1-pre-migración-validación-y-backup)
2.  [Migración de Sesiones](#2-migración-de-sesiones)
3.  [Migración de Rate Limiting](#3-migración-de-rate-limiting)
4.  [Configuración de AI Providers](#4-configuración-de-ai-providers)
5.  [Optimización de Búsquedas](#5-optimización-de-búsquedas)
6.  [Migración de Carrito](#6-migración-de-carrito)
7.  [Post-migración: Validación](#7-post-migración-validación)

### 1. Pre-migración: Validación y Backup

#### validate-pre-migration.js

```javascript
/**
 * Script de validación pre-migración
 * Verifica que el sistema esté listo para migrar
 */

const { Pool } = require('pg');
const Redis = require('redis');
const axios = require('axios');

const CONFIG = {
  postgres: {
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD
  },
  redis: {
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379
  },
  ai_providers: {
    deepseek: process.env.DEEPSEEK_API_KEY,
    gemini: process.env.GEMINI_API_KEY
  }
};

async function validatePreMigration() {
  console.log('🔍 Iniciando validación pre-migración...\n');

  const results = {
    postgres: false,
    redis: false,
    ai_providers: false,
    backup: false,
    indices: false
  };

  // 1. Validar PostgreSQL
  try {
    const pool = new Pool(CONFIG.postgres);
    const res = await pool.query('SELECT NOW()');
    console.log('✅ PostgreSQL: Conectado');

    // Verificar tablas requeridas
    const tables = ['customer_sessions', 'products', 'categories', 'message_logs'];
    for (const table of tables) {
      const tableExists = await pool.query(
        "SELECT EXISTS (SELECT FROM pg_tables WHERE tablename = $1)",
        [table]
      );
      if (!tableExists.rows[0].exists) {
        throw new Error(`Tabla ${table} no existe`);
      }
    }
    console.log('✅ PostgreSQL: Todas las tablas existen');
    results.postgres = true;
    await pool.end();
  } catch (error) {
    console.error('❌ PostgreSQL:', error.message);
  }

  // 2. Validar Redis
  try {
    const client = Redis.createClient(CONFIG.redis);
    await client.connect();
    await client.ping();
    console.log('✅ Redis: Conectado y funcionando');
    results.redis = true;
    await client.quit();
  } catch (error) {
    console.error('❌ Redis:', error.message);
  }

  // 3. Validar AI Providers
  try {
    let validProviders = 0;

    if (CONFIG.ai_providers.deepseek) {
      // Validar Deepseek API
      console.log('✅ Deepseek API key configurada');
      validProviders++;
    }

    if (CONFIG.ai_providers.gemini) {
      // Validar Gemini API
      console.log('✅ Gemini API key configurada');
      validProviders++;
    }

    if (validProviders === 0) {
      throw new Error('No hay AI providers configurados');
    }

    results.ai_providers = true;
  } catch (error) {
    console.error('❌ AI Providers:', error.message);
  }

  // 4. Crear backup
  try {
    console.log('\n📦 Creando backup de datos...');
    const pool = new Pool(CONFIG.postgres);

    // Backup de sesiones activas
    const sessions = await pool.query(
      'SELECT * FROM customer_sessions WHERE expires_at > NOW()'
    );

    const fs = require('fs');
    const backupDir = './backups';
    if (!fs.existsSync(backupDir)) {
      fs.mkdirSync(backupDir);
    }

    const backupFile = `${backupDir}/pre_migration_${Date.now()}.json`;
    fs.writeFileSync(backupFile, JSON.stringify({
      timestamp: new Date().toISOString(),
      sessions: sessions.rows,
      session_count: sessions.rows.length
    }, null, 2));

    console.log(`✅ Backup creado: ${backupFile}`);
    results.backup = true;
    await pool.end();
  } catch (error) {
    console.error('❌ Backup:', error.message);
  }

  // Resumen
  console.log('\n📊 Resumen de Validación:');
  console.log('------------------------');
  Object.entries(results).forEach(([key, value]) => {
    console.log(`${key}: ${value ? '✅' : '❌'}`);
  });

  const allPassed = Object.values(results).every(v => v);
  if (allPassed) {
    console.log('\n🎉 Sistema listo para migración!');
    process.exit(0);
  } else {
    console.log('\n❌ Sistema NO está listo para migración. Corrige los errores antes de continuar.');
    process.exit(1);
  }
}

validatePreMigration();
```

### 2. Migración de Sesiones

#### migrate-sessions.js

```javascript
/**
 * Migración de sesiones de PostgreSQL a Redis
 * Mantiene compatibilidad con sistema MVP
 */

const { Pool } = require('pg');
const Redis = require('redis');

async function migrateSessions() {
  console.log('🔄 Iniciando migración de sesiones...\n');

  const pgPool = new Pool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD
  });

  const redisClient = Redis.createClient({
    host: process.env.REDIS_HOST,
    port: process.env.REDIS_PORT
  });

  try {
    await redisClient.connect();

    // 1. Obtener todas las sesiones activas
    const sessions = await pgPool.query(`
      SELECT
        cs.*,
        c.name as customer_name,
        c.total_orders,
        c.customer_tier
      FROM customer_sessions cs
      LEFT JOIN customers c ON cs.customer_phone = c.phone
      WHERE cs.expires_at > NOW()
    `);

    console.log(`📊 Encontradas ${sessions.rows.length} sesiones activas\n`);

    // 2. Migrar cada sesión a Redis
    let migrated = 0;
    let failed = 0;

    for (const session of sessions.rows) {
      try {
        const sessionKey = `session:${session.customer_phone}`;
        const ttl = Math.floor((new Date(session.expires_at) - new Date()) / 1000);

        const sessionData = {
          id: session.id,
          customer_phone: session.customer_phone,
          customer_name: session.customer_name || 'Cliente',
          session_state: session.session_state,
          cart_data: session.cart_data || [],
          context_data: session.context_data || {},
          total_orders: session.total_orders || 0,
          customer_tier: session.customer_tier || 'new',
          last_activity: session.updated_at,
          migrated_at: new Date().toISOString(),
          version: 'v2'
        };

        await redisClient.setEx(
          sessionKey,
          ttl > 0 ? ttl : 7200, // Default 2 horas
          JSON.stringify(sessionData)
        );

        // Marcar como migrada en PostgreSQL
        await pgPool.query(`
          UPDATE customer_sessions
          SET context_data = jsonb_set(
            COALESCE(context_data, '{}'::jsonb),
            '{migrated_to_redis}',
            'true'
          )
          WHERE id = $1
        `, [session.id]);

        migrated++;
        console.log(`✅ Migrada sesión para ${session.customer_phone}`);
      } catch (error) {
        failed++;
        console.error(`❌ Error migrando sesión ${session.id}:`, error.message);
      }
    }

    console.log('\n📊 Resumen de Migración:');
    console.log(`Total: ${sessions.rows.length}`);
    console.log(`Migradas: ${migrated}`);
    console.log(`Fallidas: ${failed}`);

    // 3. Verificar migración
    const keysInRedis = await redisClient.keys('session:*');
    console.log(`\n✅ Sesiones en Redis: ${keysInRedis.length}`);

  } catch (error) {
    console.error('❌ Error fatal:', error);
    process.exit(1);
  } finally {
    await pgPool.end();
    await redisClient.quit();
  }
}

migrateSessions();
```

### 3. Migración de Rate Limiting

#### setup-rate-limiting.js

```javascript
/**
 * Configuración del sistema de rate limiting
 * Crea estructuras necesarias en Redis y PostgreSQL
 */

const { Pool } = require('pg');
const Redis = require('redis');

async function setupRateLimiting() {
  console.log('🚦 Configurando Rate Limiting...\n');

  const pgPool = new Pool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD
  });

  const redisClient = Redis.createClient({
    host: process.env.REDIS_HOST,
    port: process.env.REDIS_PORT
  });

  try {
    await redisClient.connect();

    // 1. Crear tabla de configuración de rate limits si no existe
    await pgPool.query(`
      CREATE TABLE IF NOT EXISTS rate_limit_config (
        id SERIAL PRIMARY KEY,
        customer_tier VARCHAR(50) NOT NULL UNIQUE,
        max_per_minute INTEGER NOT NULL,
        max_per_hour INTEGER NOT NULL,
        max_per_day INTEGER NOT NULL,
        burst_size INTEGER NOT NULL,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);

    // 2. Insertar configuración por defecto
    await pgPool.query(`
      INSERT INTO rate_limit_config (customer_tier, max_per_minute, max_per_hour, max_per_day, burst_size)
      VALUES
        ('new', 5, 60, 500, 10),
        ('regular', 10, 120, 1000, 20),
        ('vip', 20, 300, 2000, 50)
      ON CONFLICT (customer_tier) DO UPDATE
      SET updated_at = NOW()
    `);

    console.log('✅ Configuración de rate limits creada en PostgreSQL');

    // 3. Crear estructura de rate limiting en Redis
    const rateLimitScript = `
      local key = KEYS[1]
      local window = ARGV[1]
      local limit = tonumber(ARGV[2])
      local now = tonumber(ARGV[3])
      local clearBefore = now - window

      redis.call('zremrangebyscore', key, 0, clearBefore)
      local current = redis.call('zcard', key)

      if current < limit then
        redis.call('zadd', key, now, now)
        redis.call('expire', key, window)
        return {1, limit - current - 1}
      else
        return {0, 0}
      end
    `;

    // Registrar script en Redis
    const scriptSha = await redisClient.scriptLoad(rateLimitScript);

    // Guardar SHA del script
    await redisClient.set('rate_limit_script_sha', scriptSha);

    console.log('✅ Script de rate limiting registrado en Redis');

    // 4. Crear índices para message_logs
    await pgPool.query(`
      CREATE INDEX IF NOT EXISTS idx_message_logs_rate_limit
      ON message_logs(customer_phone, message_timestamp DESC)
      WHERE rate_limit_exceeded = false
    `);

    console.log('✅ Índices optimizados creados');

    // 5. Test del rate limiting
    console.log('\n🧪 Testeando rate limiting...');

    const testPhone = '1234567890';
    const testKey = `rate_limit:${testPhone}:minute`;

    // Simular 5 requests
    for (let i = 0; i < 5; i++) {
      const now = Date.now();
      const result = await redisClient.evalSha(
        scriptSha,
        {
          keys: [testKey],
          arguments: ['60', '5', now.toString()]
        }
      );
      console.log(`Request ${i + 1}: ${result[0] === 1 ? 'Permitido' : 'Bloqueado'}`);
    }

    // Limpiar test
    await redisClient.del(testKey);

    console.log('\n✅ Rate limiting configurado exitosamente!');

  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  } finally {
    await pgPool.end();
    await redisClient.quit();
  }
}

setupRateLimiting();
```

### 4. Configuración de AI Providers

#### setup-ai-providers.js

```javascript
/**
 * Configuración y testing de AI providers
 * Configura circuit breakers y fallbacks
 */

const axios = require('axios');
const { Pool } = require('pg');
const Redis = require('redis');

const AI_PROVIDERS = {
  deepseek: {
    name: 'DeepSeek',
    endpoint: 'https://api.deepseek.com/v1/chat/completions',
    model: 'deepseek-chat',
    apiKey: process.env.DEEPSEEK_API_KEY,
    cost: 0.00014,
    timeout: 5000
  },
  gemini: {
    name: 'Gemini',
    endpoint: 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent',
    apiKey: process.env.GEMINI_API_KEY,
    cost: 0.000075,
    timeout: 3000
  }
};

async function setupAIProviders() {
  console.log('🤖 Configurando AI Providers...\n');

  const pgPool = new Pool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    database: process.env.DB_NAME,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD
  });

  const redisClient = Redis.createClient({
    host: process.env.REDIS_HOST,
    port: process.env.REDIS_PORT
  });

  try {
    await redisClient.connect();

    // 1. Crear tabla de configuración de AI
    await pgPool.query(`
      CREATE TABLE IF NOT EXISTS ai_provider_config (
        id SERIAL PRIMARY KEY,
        provider_name VARCHAR(50) UNIQUE NOT NULL,
        is_enabled BOOLEAN DEFAULT true,
        priority INTEGER DEFAULT 100,
        max_tokens INTEGER DEFAULT 150,
        temperature DECIMAL(3,2) DEFAULT 0.7,
        cost_per_request DECIMAL(10,6),
        timeout_ms INTEGER DEFAULT 5000,
        circuit_breaker_threshold INTEGER DEFAULT 5,
        circuit_breaker_timeout INTEGER DEFAULT 300, -- seconds
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);

    // 2. Insertar configuración de providers
    for (const [key, provider] of Object.entries(AI_PROVIDERS)) {
      await pgPool.query(`
        INSERT INTO ai_provider_config
        (provider_name, cost_per_request, timeout_ms, priority)
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (provider_name)
        DO UPDATE SET
          cost_per_request = EXCLUDED.cost_per_request,
          timeout_ms = EXCLUDED.timeout_ms,
          priority = EXCLUDED.priority,
          updated_at = NOW()
      `, [provider.name, provider.cost, provider.timeout, key === 'gemini' ? 90 : 100]); // Gemini higher priority (lower number)
    }
    console.log('✅ Configuración de AI providers insertada/actualizada en PostgreSQL');

    // 3. Testear cada provider (ejemplo básico)
    for (const [key, provider] of Object.entries(AI_PROVIDERS)) {
      if (!provider.apiKey) {
        console.warn(`⚠️ API Key para ${provider.name} no configurada. Saltando test.`);
        continue;
      }

      console.log(`\n🧪 Testeando ${provider.name}...`);
      try {
        let response;
        if (provider.name === 'DeepSeek') {
          response = await axios.post(provider.endpoint, {
            model: provider.model,
            messages: [{ role: 'user', content: 'Hola' }],
            max_tokens: 10,
          }, {
            headers: { Authorization: `Bearer ${provider.apiKey}` },
            timeout: provider.timeout
          });
        } else if (provider.name === 'Gemini') {
          response = await axios.post(`${provider.endpoint}?key=${provider.apiKey}`, {
            contents: [{ parts: [{ text: "Hola" }] }]
          }, { timeout: provider.timeout });
        }

        if (response && response.status === 200) {
          console.log(`✅ ${provider.name}: Conexión exitosa.`);
          // Guardar estado en Redis (ej. circuit breaker)
          await redisClient.set(`ai_provider:${key}:status`, 'ok');
          await redisClient.del(`ai_provider:${key}:failures`);
        } else {
          throw new Error(`Status ${response ? response.status : 'unknown'}`);
        }
      } catch (error) {
        console.error(`❌ ${provider.name}: Error - ${error.message}`);
        // Incrementar contador de fallos para circuit breaker
        const failures = await redisClient.incr(`ai_provider:${key}:failures`);
        await redisClient.expire(`ai_provider:${key}:failures`, 3600); // Expira en 1 hora
        console.warn(`🔥 ${provider.name}: Fallos consecutivos: ${failures}`);
      }
    }

    console.log('\n✅ Configuración y testing básico de AI Providers completado!');

  } catch (error) {
    console.error('❌ Error fatal en configuración de AI:', error);
    process.exit(1);
  } finally {
    await pgPool.end();
    await redisClient.quit();
  }
}

setupAIProviders();
```
