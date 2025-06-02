FROM node:18-alpine

WORKDIR /app

# Instalar dependencias
COPY package*.json ./
RUN npm install

# Copiar el código fuente manteniendo la estructura de directorios
COPY src/ ./src/
COPY routes/ ./routes/
COPY server.js .
COPY .env .

# Crear directorio para uploads
RUN mkdir -p uploads/products

# Exponer el puerto
EXPOSE 4000

# Comando para iniciar la aplicación
CMD ["npm", "run", "dev"] 