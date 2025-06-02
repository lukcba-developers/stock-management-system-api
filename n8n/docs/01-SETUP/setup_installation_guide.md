# 🚀 Setup e Instalación - WhatsApp Commerce

## 📋 **OVERVIEW**

Guía completa para configurar el sistema WhatsApp Commerce con N8N en modo Queue Worker, optimizado para alta concurrencia y performance.

### **Arquitectura del Sistema**
- **N8N Main**: Coordinador de Queue + UI
- **N8N Workers**: Procesamiento distribuido (2 workers)
- **PostgreSQL**: Base de datos compartida optimizada
- **Redis**: Queue + Cache distribuido
- **Stock Backend**: API REST para gestión de inventario
- **Stock Frontend**: Interface web de administración

## 🏗️ **REQUISITOS DEL SISTEMA**

### **Hardware Mínimo**
- **CPU**: 4 cores
- **RAM**: 8GB
- **Storage**: 50GB SSD
- **Network**: 100Mbps

### **Software**
- Docker 20.10+
- Docker Compose 2.0+
- Git
- Certificado SSL válido

## 📁 **ESTRUCTURA DEL PROYECTO**

```
whatsapp-commerce/
├── docker-compose.yml           # Configuración principal
├── .env                        # Variables de entorno
├── init-scripts/               # Scripts de inicialización BD
│   ├── 01_create_schemas.sql
│   ├── init-db.sql
│   ├── init-tables.sql
│   └── additional_sql_tables.sql
├── flow/                       # Workflows N8N
│   ├── whatsapp_flow_1.json
│   ├── whatsapp_flow_2.json
│   ├── whatsapp_flow_3.json
│   ├── whatsapp_flow_4.json
│   ├── whatsapp_flow_5.json
│   └── whatsapp_flow_6.json
├── frontend/                   # React Frontend
├── backend/                    # Node.js API
├── postgres/                   # Configuración PostgreSQL
│   ├── postgresql.conf
│   └── pg_hba.conf
└── redis/                      # Configuración Redis
    └── redis.conf
```

## 🔧 **CONFIGURACIÓN DE ENTORNO**

### **Archivo .env Requerido**
```bash
# N8N Configuration
N8N_PASSWORD=tu_password_seguro_aqui
N8N_WEBHOOK_URL=https://tu-dominio.com
N8N_API_TOKEN=tu_api_token_aqui

# Database Configuration
POSTGRES_DB=supermarket_whatsapp
POSTGRES_USER=n8n_user
POSTGRES_PASSWORD=tu_password_db_seguro

# WhatsApp Business API
WHATSAPP_ACCESS_TOKEN=tu_whatsapp_token
WHATSAPP_PHONE_NUMBER_ID=tu_phone_id
WHATSAPP_VERIFY_TOKEN=tu_verify_token

# AI/LLM APIs
OPENAI_API_KEY=sk-tu-openai-key-aqui
GEMINI_API_KEY=tu-gemini-key-aqui

# Stock Management
STOCK_API_TOKEN=tu_stock_api_token
JWT_SECRET=tu_jwt_secret
GOOGLE_CLIENT_ID=tu_google_client_id

# Monitoring (opcional)
SENTRY_DSN=tu_sentry_dsn
DATADOG_API_KEY=tu_datadog_key
```

## 🚀 **INSTALACIÓN PASO A PASO**

### **1. Clonar y Configurar**
```bash
# Clonar repositorio
git clone https://github.com/tu-repo/whatsapp-commerce.git
cd whatsapp-commerce

# Copiar y configurar variables de entorno
cp .env.example .env
nano .env  # Editar con tus valores reales

# Verificar permisos de scripts
chmod +x init-scripts/*.sql
```

### **2. Configurar WhatsApp Business API**
```bash
# Configurar webhook en Meta Developer Console
# URL: https://tu-dominio.com/webhook/whatsapp-webhook
# Verify Token: tu_verify_token (del .env)
# Eventos: messages, message_status
```

### **3. Ejecutar el Sistema**
```bash
# Iniciar todos los servicios
docker-compose up -d

# Verificar estado de servicios
docker-compose ps

# Ver logs en tiempo real
docker-compose logs -f
```

### **4. Verificar Instalación**
```bash
# Health checks
curl http://localhost:5678/healthz  # N8N Main
curl http://localhost:4000/api/health  # Stock Backend
curl http://localhost:3001          # Stock Frontend

# Verificar base de datos
docker exec -it shared_postgres psql -U n8n_user -d supermarket_whatsapp -c "\dt"
```

## 🔧 **CONFIGURACIÓN AVANZADA**

### **N8N Queue Mode Setup**
```yaml
# Docker Compose - Configuración de Queue
n8n-main:
  environment:
    - EXECUTIONS_MODE=queue
    - QUEUE_BULL_REDIS_HOST=redis
    - QUEUE_BULL_REDIS_PORT=6379
    - QUEUE_HEALTH_CHECK_ACTIVE=true
    - QUEUE_RECOVERY_INTERVAL=30

n8n-worker-1:
  command: worker
  environment:
    - EXECUTIONS_MODE=queue
    - WORKER_ID=worker-1
```

### **PostgreSQL Optimizations**
```sql
-- Configuraciones para alta concurrencia
max_connections = 200
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
```

### **Redis Configuration**
```redis
# redis.conf optimizations
maxmemory 1gb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
tcp-keepalive 300
```

## 📦 **IMPORTAR WORKFLOWS**

### **1. Acceder a N8N**
```bash
# URL: http://localhost:5678
# Usuario: admin
# Contraseña: [valor de N8N_PASSWORD en .env]
```

### **2. Importar Flows**
```bash
# Desde la interfaz web N8N:
# 1. Settings → Import from JSON
# 2. Importar en orden:
#    - whatsapp_flow_1.json (Entry & Validation)
#    - whatsapp_flow_2.json (Session & AI)
#    - whatsapp_flow_3.json (Intent Processing)
#    - whatsapp_flow_4.json (Product Search)
#    - whatsapp_flow_5.json (Cart & Checkout)
#    - whatsapp_flow_6.json (Final Response)
```

### **3. Configurar Credenciales**
```javascript
// Credenciales requeridas en N8N:
{
  "whatsappBusinessApi": {
    "accessToken": "WHATSAPP_ACCESS_TOKEN",
    "phoneNumberId": "WHATSAPP_PHONE_NUMBER_ID"
  },
  "postgres": {
    "host": "postgres",
    "database": "supermarket_whatsapp",
    "user": "n8n_user",
    "password": "POSTGRES_PASSWORD"
  },
  "openAiApi": {
    "apiKey": "OPENAI_API_KEY"
  },
  "geminiApi": {
    "apiKey": "GEMINI_API_KEY"
  }
}
```

## 📊 **VERIFICACIÓN DE BASE DE DATOS**

### **Verificar Esquemas y Tablas**
```sql
-- Conectar a PostgreSQL
docker exec -it shared_postgres psql -U n8n_user -d supermarket_whatsapp

-- Verificar esquemas
\dn

-- Verificar tablas principales
\dt stock.*
\dt shared.*

-- Verificar datos de ejemplo
SELECT * FROM stock.categories;
SELECT * FROM stock.products LIMIT 5;
SELECT * FROM shared.customer_sessions LIMIT 3;
```

### **Queries de Verificación**
```sql
-- Productos disponibles por categoría
SELECT c.name, COUNT(p.id) as product_count
FROM stock.categories c
LEFT JOIN stock.products p ON c.id = p.category_id
WHERE p.is_available = true
GROUP BY c.name;

-- Estado del sistema
SELECT 
  COUNT(*) as total_products,
  COUNT(CASE WHEN stock_quantity > 0 THEN 1 END) as in_stock,
  COUNT(CASE WHEN stock_quantity = 0 THEN 1 END) as out_of_stock
FROM stock.products 
WHERE is_available = true;
```

## 🔍 **MONITOREO INICIAL**

### **Health Checks Automáticos**
```bash
# Script de verificación
#!/bin/bash
echo "🔍 Verificando servicios..."

# N8N Main
curl -f http://localhost:5678/healthz || echo "❌ N8N Main down"

# Stock Backend
curl -f http://localhost:4000/api/health || echo "❌ Stock Backend down"

# PostgreSQL
docker exec shared_postgres pg_isready -U n8n_user || echo "❌ PostgreSQL down"

# Redis
docker exec shared_redis redis-cli ping || echo "❌ Redis down"

echo "✅ Verificación completada"
```

### **Logs Importantes**
```bash
# Logs por servicio
docker-compose logs n8n-main       # Coordinador principal
docker-compose logs n8n-worker-1   # Worker de procesamiento
docker-compose logs postgres       # Base de datos
docker-compose logs redis          # Cache y queue
docker-compose logs stock-backend  # API de inventario
```

## 🚨 **TROUBLESHOOTING**

### **Problemas Comunes**

#### 1. N8N no inicia
```bash
# Verificar variables de entorno
docker-compose config

# Verificar logs
docker-compose logs n8n-main

# Posible causa: PostgreSQL no ready
docker-compose up postgres
# Esperar que esté ready, luego:
docker-compose up n8n-main
```

#### 2. Workers no se conectan
```bash
# Verificar Redis
docker exec shared_redis redis-cli ping

# Verificar configuración de queue
docker-compose logs n8n-worker-1 | grep -i queue

# Reiniciar workers
docker-compose restart n8n-worker-1 n8n-worker-2
```

#### 3. Base de datos sin tablas
```bash
# Verificar que los scripts se ejecutaron
docker-compose logs postgres | grep "init-db.sql"

# Re-ejecutar inicialización si es necesario
docker-compose down -v  # ⚠️ BORRA DATOS
docker-compose up -d
```

#### 4. WhatsApp Webhook no responde
```bash
# Verificar webhook URL
curl -X POST https://tu-dominio.com/webhook/whatsapp-webhook \
  -H "Content-Type: application/json" \
  -d '{"test": true}'

# Verificar certificado SSL
curl -I https://tu-dominio.com

# Verificar configuración en Meta Developer Console
```

## 🎯 **SIGUIENTES PASOS**

1. **Configurar SSL Certificate** para producción
2. **Setup monitoring** con Prometheus/Grafana
3. **Configurar backups** automáticos
4. **Implementar CI/CD** pipeline
5. **Setup staging environment**

## 📚 **REFERENCIAS**

- [N8N Queue Mode Documentation](https://docs.n8n.io/hosting/scaling/queue-mode/)
- [WhatsApp Business Platform](https://developers.facebook.com/docs/whatsapp)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Redis Configuration](https://redis.io/topics/config)

---

**Status**: 📋 Ready for Production  
**Complexity**: 🔧 Medium  
**Time to Setup**: ⏱️ 30-45 minutos  
**Prerequisites**: 🔑 SSL Certificate + WhatsApp Business Account