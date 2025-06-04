import nodemailer from 'nodemailer';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configuración del transportador de email
let transporter;

// Inicializar transportador según el entorno
if (process.env.NODE_ENV === 'production') {
  // Configuración para producción (usando un servicio real como SendGrid, AWS SES, etc.)
  transporter = nodemailer.createTransporter({
    host: process.env.SMTP_HOST,
    port: process.env.SMTP_PORT || 587,
    secure: process.env.SMTP_SECURE === 'true',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });
} else {
  // Configuración para desarrollo (usando Ethereal Email para testing)
  transporter = nodemailer.createTransporter({
    host: 'smtp.ethereal.email',
    port: 587,
    auth: {
      user: process.env.ETHEREAL_USER || 'ethereal.user@ethereal.email',
      pass: process.env.ETHEREAL_PASS || 'ethereal.pass',
    },
  });
}

// Plantilla base para emails
const getEmailTemplate = (title, content, buttonText, buttonLink) => {
  return `
    <!DOCTYPE html>
    <html lang="es">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>${title}</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
          line-height: 1.6;
          color: #333;
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
          background-color: #f5f5f5;
        }
        .email-container {
          background-color: white;
          border-radius: 8px;
          padding: 40px;
          box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
          text-align: center;
          margin-bottom: 30px;
        }
        .logo {
          font-size: 24px;
          font-weight: bold;
          color: #4F46E5;
          margin-bottom: 10px;
        }
        .title {
          font-size: 20px;
          font-weight: 600;
          color: #1F2937;
          margin-bottom: 20px;
        }
        .content {
          font-size: 16px;
          color: #4B5563;
          margin-bottom: 30px;
        }
        .button {
          display: inline-block;
          background-color: #4F46E5;
          color: white;
          padding: 12px 24px;
          text-decoration: none;
          border-radius: 6px;
          font-weight: 500;
          margin: 20px 0;
        }
        .footer {
          text-align: center;
          margin-top: 40px;
          padding-top: 20px;
          border-top: 1px solid #E5E7EB;
          font-size: 14px;
          color: #6B7280;
        }
        .warning {
          background-color: #FEF3C7;
          border: 1px solid #F59E0B;
          border-radius: 6px;
          padding: 15px;
          margin: 20px 0;
          font-size: 14px;
          color: #92400E;
        }
      </style>
    </head>
    <body>
      <div class="email-container">
        <div class="header">
          <div class="logo">📦 Stock Manager Pro</div>
          <h1 class="title">${title}</h1>
        </div>
        
        <div class="content">
          ${content}
        </div>
        
        ${buttonText && buttonLink ? `
          <div style="text-align: center;">
            <a href="${buttonLink}" class="button">${buttonText}</a>
          </div>
        ` : ''}
        
        <div class="footer">
          <p>Este email fue enviado desde Stock Manager Pro</p>
          <p>Si no esperabas este email, puedes ignorarlo con seguridad.</p>
        </div>
      </div>
    </body>
    </html>
  `;
};

// Enviar email de invitación
export const sendInvitationEmail = async ({ 
  to, 
  inviterName, 
  organizationName, 
  invitationLink, 
  role 
}) => {
  try {
    const roleNames = {
      viewer: 'Visualizador',
      editor: 'Editor',
      admin: 'Administrador',
      owner: 'Propietario'
    };

    const roleName = roleNames[role] || role;

    const content = `
      <p>¡Hola!</p>
      
      <p><strong>${inviterName}</strong> te ha invitado a unirte a <strong>${organizationName}</strong> en Stock Manager Pro con el rol de <strong>${roleName}</strong>.</p>
      
      <p>Como ${roleName}, podrás:</p>
      <ul>
        ${role === 'viewer' ? `
          <li>Ver el inventario y reportes</li>
          <li>Consultar alertas de stock</li>
          <li>Acceder al dashboard</li>
        ` : ''}
        ${role === 'editor' ? `
          <li>Ver y editar el inventario</li>
          <li>Gestionar productos y categorías</li>
          <li>Generar reportes</li>
          <li>Configurar alertas de stock</li>
        ` : ''}
        ${role === 'admin' ? `
          <li>Gestión completa del inventario</li>
          <li>Administrar usuarios y permisos</li>
          <li>Configurar integraciones</li>
          <li>Acceso a todas las funcionalidades</li>
        ` : ''}
        ${role === 'owner' ? `
          <li>Control total del sistema</li>
          <li>Gestión de la organización</li>
          <li>Administración de suscripciones</li>
          <li>Configuraciones avanzadas</li>
        ` : ''}
      </ul>
      
      <p>Para aceptar esta invitación y configurar tu cuenta, haz clic en el botón de abajo:</p>
      
      <div class="warning">
        <strong>⚠️ Importante:</strong> Este enlace expirará en 7 días por seguridad.
      </div>
    `;

    const mailOptions = {
      from: `"Stock Manager Pro" <${process.env.SMTP_FROM || 'noreply@stockmanager.com'}>`,
      to: to,
      subject: `Invitación a ${organizationName} - Stock Manager Pro`,
      html: getEmailTemplate(
        `Invitación a ${organizationName}`,
        content,
        'Aceptar Invitación',
        invitationLink
      ),
    };

    const info = await transporter.sendMail(mailOptions);
    
    console.log('Email de invitación enviado:', {
      to,
      messageId: info.messageId,
      preview: process.env.NODE_ENV !== 'production' ? nodemailer.getTestMessageUrl(info) : null
    });

    return {
      success: true,
      messageId: info.messageId,
      previewUrl: process.env.NODE_ENV !== 'production' ? nodemailer.getTestMessageUrl(info) : null
    };

  } catch (error) {
    console.error('Error enviando email de invitación:', error);
    throw new Error('Error al enviar email de invitación');
  }
};

// Enviar email de confirmación de registro
export const sendWelcomeEmail = async ({ 
  to, 
  userName, 
  organizationName 
}) => {
  try {
    const content = `
      <p>¡Bienvenido a Stock Manager Pro, <strong>${userName}</strong>!</p>
      
      <p>Tu cuenta ha sido activada exitosamente en <strong>${organizationName}</strong>.</p>
      
      <p>Ya puedes comenzar a utilizar todas las funcionalidades disponibles para tu rol. Si tienes alguna pregunta o necesitas ayuda, no dudes en contactar a tu administrador.</p>
      
      <p>¡Esperamos que tengas una excelente experiencia usando Stock Manager Pro!</p>
    `;

    const mailOptions = {
      from: `"Stock Manager Pro" <${process.env.SMTP_FROM || 'noreply@stockmanager.com'}>`,
      to: to,
      subject: `¡Bienvenido a ${organizationName}!`,
      html: getEmailTemplate(
        '¡Cuenta Activada!',
        content,
        'Ir a Stock Manager Pro',
        process.env.FRONTEND_URL || 'http://localhost:3000'
      ),
    };

    const info = await transporter.sendMail(mailOptions);
    
    console.log('Email de bienvenida enviado:', {
      to,
      messageId: info.messageId
    });

    return {
      success: true,
      messageId: info.messageId
    };

  } catch (error) {
    console.error('Error enviando email de bienvenida:', error);
    throw new Error('Error al enviar email de bienvenida');
  }
};

// Enviar notificación de cambio de rol
export const sendRoleChangeEmail = async ({ 
  to, 
  userName, 
  newRole, 
  organizationName, 
  changedBy 
}) => {
  try {
    const roleNames = {
      viewer: 'Visualizador',
      editor: 'Editor', 
      admin: 'Administrador',
      owner: 'Propietario'
    };

    const roleName = roleNames[newRole] || newRole;

    const content = `
      <p>Hola <strong>${userName}</strong>,</p>
      
      <p>Tu rol en <strong>${organizationName}</strong> ha sido actualizado por <strong>${changedBy}</strong>.</p>
      
      <p>Tu nuevo rol es: <strong>${roleName}</strong></p>
      
      <p>Este cambio es efectivo inmediatamente. Cierra sesión y vuelve a ingresar para que los cambios tomen efecto.</p>
    `;

    const mailOptions = {
      from: `"Stock Manager Pro" <${process.env.SMTP_FROM || 'noreply@stockmanager.com'}>`,
      to: to,
      subject: `Cambio de rol en ${organizationName}`,
      html: getEmailTemplate(
        'Cambio de Rol',
        content,
        'Ir a Stock Manager Pro',
        process.env.FRONTEND_URL || 'http://localhost:3000'
      ),
    };

    const info = await transporter.sendMail(mailOptions);
    
    console.log('Email de cambio de rol enviado:', {
      to,
      messageId: info.messageId
    });

    return {
      success: true,
      messageId: info.messageId
    };

  } catch (error) {
    console.error('Error enviando email de cambio de rol:', error);
    throw new Error('Error al enviar email de cambio de rol');
  }
};

export default {
  sendInvitationEmail,
  sendWelcomeEmail,
  sendRoleChangeEmail
}; 