
# 📚 Documentación del Sistema de Control de Acceso y Multi-Organización

---

## 🎯 ¿Qué es esta funcionalidad?

El sistema permite que cada empresa/organización tenga su propio espacio aislado, donde solo los usuarios autorizados pueden acceder.  
Es como tener múltiples supermercados independientes en una sola plataforma, donde cada uno gestiona sus propios productos, inventarios y usuarios.

---

## 🔑 Conceptos Clave

### **Organización**
- Es tu empresa/negocio en el sistema.
- Tiene su propio inventario, productos y datos.
- Completamente aislada de otras organizaciones.

### **Usuarios Autorizados**
- Solo pueden acceder personas específicamente invitadas.
- Cada usuario tiene un rol con permisos definidos.
- El acceso se controla por email.

### **Roles Disponibles**
- 👑 **Propietario:** Control total del sistema.
- 🛡️ **Administrador:** Gestiona usuarios y configuraciones.
- ✏️ **Editor:** Puede crear/editar productos e inventario.
- 👀 **Visualizador:** Solo puede ver información.

---

## 📋 Casos de Uso Detallados

---

### **Caso 1: Configuración Inicial 🚀**

**Situación:** Juan acaba de contratar el sistema para su supermercado "La Esquina".

**Pasos:**
1. Juan recibe sus credenciales de acceso como **Propietario**.
2. Hace login con su Google (`juan@laesquina.com`).
3. El sistema detecta que es su primer acceso y lo guía:
   ```
   Bienvenido a Stock Manager Pro
   ┌─────────────────────────────────┐
   │ 1. Nombre: La Esquina           │
   │ 2. Tipo: Supermercado           │
   │ 3. Tamaño: 500-1000 productos   │
   │ 4. Plan: Professional           │
   └─────────────────────────────────┘
   ```
4. Se crea automáticamente su organización.

**Resultado:** Juan ahora tiene su espacio privado en el sistema.

---

### **Caso 2: Invitar al Gerente de Inventario 👥**

**Situación:** Juan necesita que María, su gerente de inventario, acceda al sistema.

**Pasos:**
1. Juan va a **Configuración → Gestión de Usuarios**.
2. Hace clic en "Invitar Usuario".
3. Ingresa:
   - Email: `maria@laesquina.com`
   - Rol: **Editor** (puede modificar inventario)
4. María recibe un email:
   ```
   Asunto: Invitación a Stock Manager Pro

   Hola María,

   Juan te ha invitado a acceder al sistema de inventario de La Esquina.

   Rol asignado: Editor

   [Aceptar Invitación]
   ```
5. María hace clic en el botón y se autentica con Google.
6. ¡Acceso concedido! María puede gestionar el inventario.

**Pantalla de Juan:**
```
┌──────────────────────────────────────┐
│ Gestión de Usuarios                  │
├──────────────────────────────────────┤
│ ✉️ maria@laesquina.com              │
│    Rol: Editor                       │
│    Estado: ✅ Activo                 │
│    Último acceso: Hace 5 min         │
└──────────────────────────────────────┘
```

---

### **Caso 3: Empleado No Autorizado Intenta Acceder 🚫**

**Situación:** Pedro, un exempleado, intenta acceder al sistema.

**Pasos:**
1. Pedro intenta hacer login con `pedro@gmail.com`.
2. Google lo autentica correctamente.
3. El sistema verifica y no encuentra autorización.

**Pedro ve:**
```
┌────────────────────────────────────┐
│      ⛔ Acceso No Autorizado       │
├────────────────────────────────────┤
│ Tu email pedro@gmail.com no está   │
│ autorizado para acceder.           │
│                                    │
│ Contacta al administrador si       │
│ necesitas acceso.                  │
│                                    │
│ [Contactar Admin] [Volver]         │
└────────────────────────────────────┘
```
**Resultado:** Pedro no puede ver ningún dato del sistema.

---

### **Caso 4: Cambiar Permisos de un Usuario 🔄**

**Situación:** Carlos (cajero) necesita temporalmente editar precios.

**Pasos:**
1. Juan accede a **Gestión de Usuarios**.
2. Encuentra a Carlos (actualmente Visualizador).
3. Cambia su rol:
   - `carlos@laesquina.com`
   - Rol: `[Visualizador ▼] → [Editor ▼]`
4. Carlos recibe notificación instantánea.
5. Ahora Carlos puede editar productos.

**Registro de Auditoría:**
```
📋 Actividad Reciente
- Juan cambió rol de Carlos: Visualizador → Editor
- Fecha: 15/03/2024 10:30 AM
- IP: 192.168.1.100
```

---

### **Caso 5: Alcanzar Límite de Usuarios 📊**

**Situación:** La Esquina tiene plan "Starter" (máx 5 usuarios) y Juan intenta invitar al 6to usuario.

**Pasos:**
1. Juan intenta invitar a otro empleado.
2. El sistema muestra:
   ```
   ┌─────────────────────────────────────┐
   │    ⚠️ Límite de Plan Alcanzado     │
   ├─────────────────────────────────────┤
   │ Tu plan actual: Starter             │
   │ Usuarios permitidos: 5              │
   │ Usuarios actuales: 5                │
   │                                     │
   │ Para agregar más usuarios:          │
   │ • Elimina un usuario existente      │
   │ • Actualiza a Plan Professional     │
   │                                     │
   │ [Ver Planes] [Cancelar]             │
   └─────────────────────────────────────┘
   ```

**Opciones de Juan:**
- Actualizar al plan Professional (20 usuarios)
- Desactivar un usuario que ya no trabaja

---

### **Caso 6: Suspender Usuario Temporalmente ⏸️**

**Situación:** Ana está de vacaciones por 1 mes.

**Pasos:**
1. Juan suspende temporalmente a Ana:
   - `ana@laesquina.com`
   - Estado: `[Activo] → [Suspendido]`
2. Ana intenta acceder durante sus vacaciones.
3. Ve mensaje:
   ```
   Tu cuenta está temporalmente suspendida.
   Contacta a tu administrador.
   ```
4. Cuando Ana regresa, Juan reactiva su cuenta.

---

### **Caso 7: Empleado Cambia de Email 📧**

**Situación:** María ahora usa `maria.garcia@laesquina.com`.

**Pasos:**
1. Juan elimina el acceso del email antiguo.
2. Envía nueva invitación al email nuevo.
3. María acepta con su nuevo email.
4. Mantiene el mismo rol y permisos.

---

## 🛠️ Guía Rápida de Administración

### **Panel de Control del Propietario**
```
┌─────────────────────────────────────────────┐
│ 👥 Gestión de Usuarios                      │
├─────────────────────────────────────────────┤
│ [+ Invitar Usuario]  [🔍 Buscar]  [Filtros] │
│                                             │
│ Email              Rol         Estado       │
│ ─────────────────────────────────────────── │
│ juan@laesquina     Propietario ✅ Activo    │
│ maria@laesquina    Editor      ✅ Activo    │
│ carlos@laesquina   Visualizador ✅ Activo   │
│ ana@laesquina      Editor      ⏸️ Suspendido│
│ pedro@gmail.com    -           ❌ Eliminado │
│                                             │
│ Mostrando 5 de 5 usuarios                   │
└─────────────────────────────────────────────┘
```

---

### 📊 **Tabla de Permisos por Rol**

| Acción                   | Propietario | Admin | Editor | Visualizador |
|--------------------------|:-----------:|:-----:|:------:|:------------:|
| Ver productos            | ✅          | ✅    | ✅     | ✅           |
| Crear/Editar productos   | ✅          | ✅    | ✅     | ❌           |
| Eliminar productos       | ✅          | ✅    | ❌     | ❌           |
| Ver reportes             | ✅          | ✅    | ✅     | ✅           |
| Gestionar usuarios       | ✅          | ✅    | ❌     | ❌           |
| Cambiar plan             | ✅          | ❌    | ❌     | ❌           |
| Ver facturación          | ✅          | ✅    | ❌     | ❌           |

---

## 🔒 Seguridad y Privacidad

**¿Qué garantiza el sistema?**
- **Aislamiento Total:** Cada organización es independiente.
- **Autenticación Segura:** Usa Google OAuth 2.0.
- **Control Granular:** Permisos específicos por rol.
- **Auditoría Completa:** Todo cambio queda registrado.
- **Sin Acceso Público:** Solo usuarios invitados.

**¿Qué NO pueden hacer los usuarios?**
- ❌ Ver datos de otras organizaciones.
- ❌ Invitar usuarios sin ser Admin/Propietario.
- ❌ Cambiar su propio rol.
- ❌ Acceder sin invitación previa.

---

## 💡 Preguntas Frecuentes

- **¿Puedo usar cualquier email?**  
  Sí, pero debe ser un email válido con cuenta de Google.

- **¿Qué pasa si pierdo acceso a mi email?**  
  El propietario puede eliminar el email antiguo e invitarte con el nuevo.

- **¿Puedo tener múltiples organizaciones?**  
  Sí, un mismo email puede ser invitado a diferentes organizaciones.

- **¿Los usuarios ven solo nuestra información?**  
  Correcto, cada organización está completamente aislada.

- **¿Qué pasa al eliminar un usuario?**  
  Pierde acceso inmediatamente pero sus acciones quedan en el historial.

---

## 📱 Notificaciones del Sistema

Los usuarios reciben notificaciones por:
- 📧 **Email:** Invitaciones y cambios importantes.
- 🔔 **En la App:** Cambios de rol o estado.
- 📊 **Dashboard:** Alertas de límites del plan.

---

## 🎯 Mejores Prácticas

- Asigna roles mínimos necesarios: No todos necesitan ser administradores.
- Revisa usuarios regularmente: Elimina accesos no utilizados.
- Usa emails corporativos: Más fácil de gestionar.
- Documenta los roles: Que cada uno sepa sus responsabilidades.
- Suspende, no elimines: Para ausencias temporales.

---

## 🆘 Soporte

Si tienes problemas con el acceso:
- Verifica que tu email esté invitado.
- Confirma que usas el email correcto en Google.
- Contacta a tu administrador.
- Si eres propietario, contacta soporte técnico.

