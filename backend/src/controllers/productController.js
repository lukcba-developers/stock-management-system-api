import pool from '../config/database.js';
import { logActivity } from '../middleware/activityLogger.js';

export const getProducts = async (req, res) => {
  try {
    const {
      search,
      category,
      lowStock,
      page = 1,
      limit = 20,
      sortBy = 'name',
      sortOrder = 'ASC'
    } = req.query;

    let query = `
      SELECT
        p.*,
        c.name as category_name,
        c.icon_emoji as category_icon,
        CASE
          WHEN p.stock_quantity = 0 THEN 'out_of_stock'
          WHEN p.stock_quantity <= p.min_stock_alert THEN 'low_stock'
          ELSE 'normal'
        END as stock_status,
        COUNT(*) OVER() as total_count
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.is_available = true
    `;

    const queryParams = [];
    let paramCount = 0;

    if (search) {
      paramCount++;
      query += ` AND (
        p.name ILIKE $${paramCount} OR
        p.brand ILIKE $${paramCount} OR
        p.barcode ILIKE $${paramCount} OR
        p.description ILIKE $${paramCount}
      )`;
      queryParams.push(`%${search}%`);
    }

    if (category) {
      paramCount++;
      query += ` AND p.category_id = $${paramCount}`;
      queryParams.push(category);
    }

    if (lowStock === 'true') {
      query += ` AND p.stock_quantity <= p.min_stock_alert AND p.stock_quantity > 0`;
    } else if (lowStock === 'out_of_stock') {
      query += ` AND p.stock_quantity = 0`;
    }

    const allowedSortFields = ['name', 'price', 'stock_quantity', 'created_at', 'popularity_score'];
    const sortFieldMap = {
      'name': 'p.name',
      'price': 'p.price',
      'stock_quantity': 'p.stock_quantity',
      'created_at': 'p.created_at',
      'popularity_score': 'p.popularity_score'
    };
    const sortField = sortFieldMap[sortBy] || 'p.name';
    const order = sortOrder.toUpperCase() === 'DESC' ? 'DESC' : 'ASC';
    query += ` ORDER BY ${sortField} ${order}`;

    const offset = (parseInt(page) - 1) * parseInt(limit);
    paramCount++;
    query += ` LIMIT $${paramCount}`;
    queryParams.push(limit);
    paramCount++;
    query += ` OFFSET $${paramCount}`;
    queryParams.push(offset);

    const result = await pool.query(query, queryParams);

    const totalCount = result.rows.length > 0 ? parseInt(result.rows[0].total_count) : 0;
    const productsData = result.rows.map(row => {
      const { total_count, ...product } = row;
      return product;
    });

    res.json({
      success: true,
      data: productsData,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: totalCount,
        totalPages: Math.ceil(totalCount / parseInt(limit))
      }
    });

  } catch (error) {
    console.error('Error obteniendo productos:', error);
    res.status(500).json({ error: 'Error al obtener productos' });
  }
};

export const getProductById = async (req, res) => {
  try {
    const { id } = req.params;
    const query = `
      SELECT
        p.*,
        c.name as category_name,
        c.icon_emoji as category_icon,
        (
          SELECT JSON_AGG(
            JSON_BUILD_OBJECT(
              'id', oi.id,
              'order_id', oi.order_id,
              'quantity', oi.quantity,
              'created_at', o.created_at
            ) ORDER BY o.created_at DESC
          )
          FROM order_items oi
          JOIN orders o ON oi.order_id = o.id
          WHERE oi.product_id = p.id
          AND o.created_at > NOW() - INTERVAL '30 days'
        ) as recent_sales,
        (
          SELECT JSON_AGG(
            JSON_BUILD_OBJECT(
              'id', sm.id,
              'movement_type', sm.movement_type,
              'quantity_change', sm.quantity_change,
              'quantity_before', sm.quantity_before,
              'quantity_after', sm.quantity_after,
              'reason', sm.reason,
              'created_at', sm.created_at,
              'user_name', u.name
            ) ORDER BY sm.created_at DESC
          )
          FROM stock_movements sm
          LEFT JOIN admin_users u ON sm.user_id = u.id
          WHERE sm.product_id = p.id
          LIMIT 10
        ) as stock_history
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.id = $1
    `;
    const result = await pool.query(query, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Producto no encontrado' });
    }
    res.json({ success: true, data: result.rows[0] });
  } catch (error) {
    console.error('Error obteniendo producto:', error);
    res.status(500).json({ error: 'Error al obtener producto' });
  }
};

export const createProduct = async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const {
      name, description, price, stock_quantity, min_stock_alert,
      category_id, brand, barcode,
      weight_unit, weight_value,
      is_featured, meta_keywords, is_available = true
    } = req.body;

    if (!name || !price || !stock_quantity || !category_id) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Campos obligatorios faltantes: nombre, precio, stock, categoría.' });
    }

    const image_url = req.file ? `/uploads/products/${req.file.filename}` : null;

    const insertQuery = `
      INSERT INTO products (
        name, description, price, stock_quantity, min_stock_alert,
        category_id, image_url, barcode, brand, weight_unit, weight_value,
        is_featured, meta_keywords, is_available
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14
      ) RETURNING *
    `;
    const values = [
      name, description, parseFloat(price), parseInt(stock_quantity), parseInt(min_stock_alert) || 0,
      parseInt(category_id), image_url, barcode, brand, weight_unit, parseFloat(weight_value) || null,
      is_featured === 'true' || is_featured === true, meta_keywords, is_available === 'true' || is_available === true
    ];
    const result = await client.query(insertQuery, values);
    const newProduct = result.rows[0];

    // Registrar movimiento de stock inicial
    await client.query(`
      INSERT INTO stock_movements (
        product_id, movement_type, quantity_change,
        quantity_before, quantity_after, reason, user_id, reference_type
      ) VALUES ($1, 'in', $2, 0, $2, 'Creación de producto', $3, 'initial_stock')
    `, [newProduct.id, newProduct.stock_quantity, req.user.id]);

    await logActivity(req.user.id, 'create', 'product', newProduct.id, { name: newProduct.name, ...req.body, image_url }, req.ip, req.headers['user-agent']);
    await client.query('COMMIT');
    res.status(201).json({ success: true, data: newProduct });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error creando producto:', error);
    if (error.message && error.message.startsWith('Solo se permiten imágenes')) {
      return res.status(400).json({ error: error.message });
    }
    res.status(500).json({ error: 'Error al crear producto' });
  } finally {
    client.release();
  }
};

export const updateProduct = async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { id } = req.params;
    const updates = req.body;

    const currentProductQuery = await client.query('SELECT * FROM products WHERE id = $1', [id]);
    if (currentProductQuery.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Producto no encontrado' });
    }
    const oldProductData = currentProductQuery.rows[0];

    if (req.file) {
      updates.image_url = `/uploads/products/${req.file.filename}`;
    }

    const setClause = [];
    const values = [];
    let paramCount = 1;

    const allowedUpdates = [
      'name', 'description', 'price', 'min_stock_alert', 'category_id',
      'brand', 'barcode', 'weight_unit', 'weight_value', 'is_featured',
      'meta_keywords', 'is_available', 'image_url'
    ];

    allowedUpdates.forEach(key => {
      if (updates[key] !== undefined) {
        setClause.push(`${key} = $${paramCount}`);
        if (key === 'price' || key === 'weight_value') values.push(parseFloat(updates[key]));
        else if (key === 'min_stock_alert' || key === 'category_id') values.push(parseInt(updates[key]));
        else if (key === 'is_featured' || key === 'is_available') values.push(updates[key] === 'true' || updates[key] === true);
        else values.push(updates[key]);
        paramCount++;
      }
    });

    if (setClause.length === 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'No hay campos válidos para actualizar' });
    }

    values.push(id);
    const updateQuery = `
      UPDATE products
      SET ${setClause.join(', ')}, updated_at = NOW()
      WHERE id = $${paramCount}
      RETURNING *
    `;

    const result = await client.query(updateQuery, values);
    const updatedProduct = result.rows[0];

    const changesMade = {};
    for (const key in updates) {
      if (allowedUpdates.includes(key) && oldProductData[key] !== updatedProduct[key]) {
        changesMade[key] = { old: oldProductData[key], new: updatedProduct[key] };
      }
    }
    if (req.file && oldProductData.image_url !== updatedProduct.image_url) {
      changesMade.image_url = { old: oldProductData.image_url, new: updatedProduct.image_url };
    }

    await logActivity(req.user.id, 'update', 'product', id, changesMade, req.ip, req.headers['user-agent']);
    await client.query('COMMIT');
    res.json({ success: true, data: updatedProduct });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error actualizando producto:', error);
    if (error.message && error.message.startsWith('Solo se permiten imágenes')) {
      return res.status(400).json({ error: error.message });
    }
    res.status(500).json({ error: 'Error al actualizar producto' });
  } finally {
    client.release();
  }
};

export const updateStock = async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { id } = req.params;
    const { stock_quantity, reason } = req.body;

    if (stock_quantity === undefined || isNaN(parseInt(stock_quantity))) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Cantidad de stock no válida.' });
    }
    const newStockQuantity = parseInt(stock_quantity);

    const currentStockQuery = await client.query('SELECT stock_quantity FROM products WHERE id = $1 FOR UPDATE', [id]);
    if (currentStockQuery.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Producto no encontrado' });
    }
    const oldStock = currentStockQuery.rows[0].stock_quantity;

    const updateResult = await client.query(
      'UPDATE products SET stock_quantity = $1, updated_at = NOW() WHERE id = $2 RETURNING *',
      [newStockQuantity, id]
    );

    const quantityChange = newStockQuantity - oldStock;
    const movementType = quantityChange > 0 ? 'in' : (quantityChange < 0 ? 'out' : 'adjustment');

    if (quantityChange !== 0) {
      await client.query(`
        INSERT INTO stock_movements (
          product_id, movement_type, quantity_change,
          quantity_before, quantity_after, reason, user_id, reference_type
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'manual_adjustment')
      `, [
        id,
        movementType,
        Math.abs(quantityChange),
        oldStock,
        newStockQuantity,
        reason || 'Ajuste manual de stock',
        req.user.id
      ]);
    }

    await logActivity(req.user.id, 'stock_update', 'product', id, { old_stock: oldStock, new_stock: newStockQuantity, reason }, req.ip, req.headers['user-agent']);
    await client.query('COMMIT');
    res.json({ success: true, data: updateResult.rows[0] });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error actualizando stock:', error);
    res.status(500).json({ error: 'Error al actualizar stock' });
  } finally {
    client.release();
  }
};

export const deleteProduct = async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { id } = req.params;

    const productQuery = await client.query('SELECT name, is_available FROM products WHERE id = $1', [id]);
    if (productQuery.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Producto no encontrado' });
    }

    if (!productQuery.rows[0].is_available) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'El producto ya está marcado como no disponible.' });
    }

    const result = await client.query(
      'UPDATE products SET is_available = false, updated_at = NOW() WHERE id = $1 RETURNING *',
      [id]
    );

    await logActivity(req.user.id, 'delete', 'product', id, { name: result.rows[0].name, new_status: 'unavailable' }, req.ip, req.headers['user-agent']);
    await client.query('COMMIT');
    res.json({ success: true, message: 'Producto marcado como no disponible.', data: result.rows[0] });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error eliminando producto (soft delete):', error);
    res.status(500).json({ error: 'Error al marcar producto como no disponible' });
  } finally {
    client.release();
  }
}; 