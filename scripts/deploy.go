package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"time"
)

// Config holds deployment configuration
type Config struct {
	RemoteUser    string
	RemoteHost    string
	RemoteAppPath string
	GitBranch     string
}

func main() {
	// Load configuration (in a real scenario, this would come from environment variables or config file)
	config := Config{
		RemoteUser:    "your_ssh_user",
		RemoteHost:    "your_server_ip",
		RemoteAppPath: "/var/www/stock-management",
		GitBranch:     "main",
	}

	fmt.Println("🚀 Iniciando proceso de despliegue...")

	// Run remote command helper
	runRemote := func(cmd string) error {
		sshCmd := fmt.Sprintf("ssh %s@%s '%s'", config.RemoteUser, config.RemoteHost, cmd)
		execCmd := exec.Command("sh", "-c", sshCmd)
		execCmd.Stdout = os.Stdout
		execCmd.Stderr = os.Stderr
		return execCmd.Run()
	}

	// Test connection
	fmt.Printf("🔗 Conectando al servidor %s...\n", config.RemoteHost)
	if err := runRemote("echo 'Conexión exitosa al servidor.'"); err != nil {
		log.Fatalf("Error conectando al servidor: %v", err)
	}

	// Enable maintenance mode
	fmt.Println("🛑 Poniendo la aplicación en modo mantenimiento...")
	if err := runRemote(fmt.Sprintf("touch %s/maintenance.flag", config.RemoteAppPath)); err != nil {
		log.Printf("⚠️ Advertencia: No se pudo activar el modo mantenimiento: %v", err)
	}

	// Update source code
	fmt.Printf("🚚 Actualizando código fuente desde el repositorio (rama %s)...\n", config.GitBranch)
	updateCmd := fmt.Sprintf("cd %s && git fetch origin && git reset --hard origin/%s && git pull origin %s",
		config.RemoteAppPath, config.GitBranch, config.GitBranch)
	if err := runRemote(updateCmd); err != nil {
		log.Fatalf("Error actualizando código: %v", err)
	}

	// Install backend dependencies
	fmt.Println("📦 Instalando/actualizando dependencias del Backend...")
	if err := runRemote(fmt.Sprintf("cd %s/backend && npm ci --only=production", config.RemoteAppPath)); err != nil {
		log.Fatalf("Error instalando dependencias del backend: %v", err)
	}

	// Build frontend
	fmt.Println("🏗️  Construyendo el Frontend...")
	if err := runRemote(fmt.Sprintf("cd %s/frontend && npm ci && npm run build", config.RemoteAppPath)); err != nil {
		log.Fatalf("Error construyendo el frontend: %v", err)
	}

	// Apply database migrations
	fmt.Println("🔄 Aplicando migraciones de base de datos...")
	if err := runRemote(fmt.Sprintf("cd %s/backend && npm run migrate", config.RemoteAppPath)); err != nil {
		log.Printf("⚠️ Advertencia: Error aplicando migraciones: %v", err)
	}

	// Restart services
	fmt.Println("♻️  Reiniciando servicios de la aplicación...")
	if err := runRemote(fmt.Sprintf("cd %s && docker-compose down && docker-compose up -d --build", config.RemoteAppPath)); err != nil {
		log.Fatalf("Error reiniciando servicios: %v", err)
	}

	// Clear caches
	fmt.Println("🧹 Limpiando cachés...")
	if err := runRemote(fmt.Sprintf("cd %s/backend && npm run cache:clear", config.RemoteAppPath)); err != nil {
		log.Printf("⚠️ Advertencia: Error limpiando cachés: %v", err)
	}

	// Disable maintenance mode
	fmt.Println("🏁 Quitando modo mantenimiento...")
	if err := runRemote(fmt.Sprintf("rm -f %s/maintenance.flag", config.RemoteAppPath)); err != nil {
		log.Printf("⚠️ Advertencia: No se pudo desactivar el modo mantenimiento: %v", err)
	}

	// Health check
	fmt.Println("🩺 Realizando chequeo de salud post-despliegue...")
	time.Sleep(5 * time.Second) // Wait for services to start
	healthCheckCmd := fmt.Sprintf("curl -sSf http://%s/api/health", config.RemoteHost)
	if err := runRemote(healthCheckCmd); err != nil {
		log.Fatalf("🚨 Chequeo de salud fallido: %v", err)
	}

	fmt.Println("🎉 ¡Despliegue finalizado!")
}
