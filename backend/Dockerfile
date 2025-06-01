FROM node:18-alpine

WORKDIR /app

# Instalar dependencias
COPY package*.json ./
RUN npm install

# Copiar el código fuente
COPY . .

# Crear directorio para uploads
RUN mkdir -p uploads/products

# Exponer el puerto
EXPOSE 4000

# Comando para iniciar la aplicación
CMD ["npm", "run", "dev"] 