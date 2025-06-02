import { Server } from 'socket.io';

export const setupStockNotifications = (server) => {
  const io = new Server(server, {
    cors: { origin: process.env.FRONTEND_URL }
  });

  io.on('connection', (socket) => {
    socket.on('subscribe_stock_alerts', (userId) => {
      socket.join(`user_${userId}`);
    });
  });

  // Función para enviar alertas
  const sendStockAlert = (productId, currentStock, minStock) => {
    io.emit('stock_alert', {
      productId,
      currentStock,
      minStock,
      timestamp: new Date().toISOString()
    });
  };

  return { io, sendStockAlert };
}; 