#!/bin/bash

# Configuración
DB_HOST=${DB_HOST:-localhost}
DB_USER=${DB_USER:-postgres}
DB_NAME=${DB_NAME:-stock_management}
BACKUP_DIR="/backups/$(date +%Y%m%d)"
LOG_FILE="/var/log/backup.log"

# Función para logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Crear directorio de backup
mkdir -p "$BACKUP_DIR"
log "Iniciando backup en $BACKUP_DIR"

# Backup de productos y categorías
log "Realizando backup de productos y categorías..."
pg_dump -h "$DB_HOST" -U "$DB_USER" -t products -t categories --data-only \
    "$DB_NAME" > "$BACKUP_DIR/inventory_$(date +%H%M).sql"

if [ $? -eq 0 ]; then
    log "Backup de inventario completado exitosamente"
else
    log "ERROR: Falló el backup de inventario"
    exit 1
fi

# Backup completo semanal (los lunes)
if [ $(date +%u) -eq 1 ]; then
    log "Iniciando backup completo semanal..."
    pg_dump -h "$DB_HOST" -U "$DB_USER" "$DB_NAME" > "$BACKUP_DIR/full_backup.sql"
    
    if [ $? -eq 0 ]; then
        log "Backup completo realizado exitosamente"
    else
        log "ERROR: Falló el backup completo"
        exit 1
    fi
fi

# Backup de configuraciones y archivos importantes
log "Realizando backup de archivos de configuración..."
cp -r /etc/stock-management "$BACKUP_DIR/config_backup"

# Comprimir backups
log "Comprimiendo archivos de backup..."
cd "$BACKUP_DIR"
tar -czf "backup_$(date +%Y%m%d_%H%M).tar.gz" *.sql config_backup
rm -f *.sql
rm -rf config_backup

# Limpieza de backups antiguos (mantener 30 días)
log "Limpiando backups antiguos..."
find /backups -type d -mtime +30 -exec rm -rf {} \;

# Verificar espacio en disco
DISK_USAGE=$(df -h /backups | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    log "ADVERTENCIA: El uso del disco está por encima del 80% ($DISK_USAGE%)"
fi

log "Proceso de backup completado" 