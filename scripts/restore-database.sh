#!/bin/bash

# Cargar variables de entorno
ENV_FILE="$(dirname "$0")/../backend/.env"
if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
else
  echo "Error: Archivo .env no encontrado en $(dirname "$ENV_FILE")"
  exit 1
fi

DB_NAME="${DB_NAME:-stock_management_db}"
DB_USER="${DB_USER:-stock_user}"
DB_PASSWORD="${DB_PASSWORD}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

# Verificar que se proporcionó un archivo de backup
if [ -z "$1" ]; then
  echo "Uso: $0 <ruta_al_archivo_de_backup.sql.gz o .sql o .dump>"
  exit 1
fi

BACKUP_FILE_PATH="$1"

if [ ! -f "$BACKUP_FILE_PATH" ]; then
  echo "Error: Archivo de backup no encontrado en '$BACKUP_FILE_PATH'"
  exit 1
fi

# Confirmación
echo "ADVERTENCIA: Esta acción restaurará la base de datos '$DB_NAME' desde el archivo '$BACKUP_FILE_PATH'."
echo "TODOS LOS DATOS ACTUALES EN '$DB_NAME' SE PERDERÁN."
read -p "¿Está seguro de que desea continuar? (escriba 'si' para confirmar): " CONFIRMATION

if [ "$CONFIRMATION" != "si" ]; then
  echo "Restauración cancelada por el usuario."
  exit 0
fi

echo "Iniciando restauración de la base de datos '$DB_NAME'..."

export PGPASSWORD="$DB_PASSWORD"

# Determinar si el archivo está comprimido y el formato
TEMP_SQL_FILE=""
CLEANUP_TEMP_FILE=false

if [[ "$BACKUP_FILE_PATH" == *.gz ]]; then
  echo "Archivo comprimido detectado. Descomprimiendo..."
  TEMP_SQL_FILE=$(mktemp) # Crear archivo temporal para el SQL descomprimido
  gunzip -c "$BACKUP_FILE_PATH" > "$TEMP_SQL_FILE"
  if [ $? -ne 0 ]; then
    echo "Error al descomprimir el archivo de backup."
    rm -f "$TEMP_SQL_FILE"
    unset PGPASSWORD
    exit 1
  fi
  SOURCE_FILE="$TEMP_SQL_FILE"
  CLEANUP_TEMP_FILE=true
elif [[ "$BACKUP_FILE_PATH" == *.sql ]]; then
  echo "Archivo SQL detectado."
  SOURCE_FILE="$BACKUP_FILE_PATH"
elif [[ "$BACKUP_FILE_PATH" == *.dump ]]; then # Asumimos formato custom de pg_dump (-Fc)
   echo "Archivo en formato custom de pg_dump detectado."
   # Para formato custom, se usa pg_restore
   pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" --clean --if-exists -v "$BACKUP_FILE_PATH"
   RESTORE_STATUS=$?
else
  echo "Formato de archivo de backup no reconocido. Use .sql, .sql.gz o .dump (formato custom)."
  unset PGPASSWORD
  exit 1
fi


if [[ "$BACKUP_FILE_PATH" != *.dump ]]; then # Si no es formato custom, usamos psql
  echo "Restaurando desde archivo SQL..."
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$SOURCE_FILE"
  RESTORE_STATUS=$?
fi


if $CLEANUP_TEMP_FILE; then
  rm -f "$TEMP_SQL_FILE"
  echo "Archivo temporal de SQL eliminado."
fi

unset PGPASSWORD

if [ $RESTORE_STATUS -eq 0 ]; then
  echo "Restauración de la base de datos completada exitosamente."
else
  echo "Error durante la restauración de la base de datos."
  exit 1
fi

echo "Proceso de restauración finalizado." 