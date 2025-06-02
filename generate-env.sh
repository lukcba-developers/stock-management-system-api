#!/bin/bash

# Generar contraseñas aleatorias
POSTGRES_PASSWORD=$(openssl rand -base64 12)
N8N_PASSWORD=$(openssl rand -base64 12)
JWT_SECRET=$(openssl rand -base64 32)
STOCK_API_TOKEN=$(openssl rand -base64 24)
N8N_API_TOKEN=$(openssl rand -base64 24)

# Crear archivo .env
cat > .env << EOL
# Database Configuration
POSTGRES_DB=stock_management
POSTGRES_USER=postgres
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# JWT & Auth
JWT_SECRET=${JWT_SECRET}
GOOGLE_CLIENT_ID=your_google_client_id_here

# N8N Configuration
N8N_PASSWORD=${N8N_PASSWORD}
N8N_WEBHOOK_URL=http://localhost:5678
N8N_API_TOKEN=${N8N_API_TOKEN}

# Stock Management API
STOCK_API_TOKEN=${STOCK_API_TOKEN}
EOL

echo "Archivo .env generado exitosamente"
echo "Por favor, configura tu GOOGLE_CLIENT_ID manualmente en el archivo .env" 