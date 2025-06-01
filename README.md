# Sistema de Gestión de Stock para Supermercado

Sistema web moderno para la gestión de inventario de supermercados, con integración de autenticación Google y sincronización con chatbot de WhatsApp.

## Características Principales

- Gestión completa de inventario
- Autenticación mediante Google OAuth
- Dashboard con estadísticas en tiempo real
- Alertas de stock bajo
- Generación de reportes
- Integración con WhatsApp
- Interfaz moderna y responsiva

## Requisitos Previos

- Docker y Docker Compose
- Node.js 18+
- PostgreSQL 15+
- Cuenta de Google Cloud Platform (para OAuth)

## Instalación

1. Clonar el repositorio:
```bash
git clone [URL_DEL_REPOSITORIO]
cd stock-management-system
```

2. Configurar variables de entorno:
```bash
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env
```

3. Iniciar el proyecto:
```bash
docker-compose up -d
```

## Estructura del Proyecto

```
stock-management/
├── backend/          # API REST con Node.js y Express
├── frontend/         # SPA con React y Tailwind CSS
├── scripts/          # Scripts de utilidad
└── docker-compose.yml
```

## Desarrollo

### Backend
- API REST con Node.js y Express
- Base de datos PostgreSQL
- Autenticación JWT y Google OAuth
- Manejo de archivos con Multer

### Frontend
- React 18 con Vite
- Tailwind CSS para estilos
- Gráficos con Recharts
- Notificaciones con React Hot Toast

## Despliegue

El proyecto está configurado para ser desplegado usando Docker y Docker Compose. Para producción:

1. Configurar las variables de entorno de producción
2. Construir las imágenes:
```bash
docker-compose -f docker-compose.prod.yml build
```

3. Iniciar los servicios:
```bash
docker-compose -f docker-compose.prod.yml up -d
```

## Contribución

1. Fork el proyecto
2. Crear una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abrir un Pull Request

## Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE.md](LICENSE.md) para más detalles. 