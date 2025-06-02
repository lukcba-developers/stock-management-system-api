import { pool } from '../config/database.js';

export const addSupplier = async ({
  productId,
  supplierName,
  supplierContact,
  costPrice,
  leadTimeDays,
  isPrimary
}) => {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');

    // Si el nuevo proveedor es primario, desactivar otros proveedores primarios
    if (isPrimary) {
      await client.query(
        'UPDATE product_suppliers SET is_primary = false WHERE product_id = $1',
        [productId]
      );
    }

    // Insertar el nuevo proveedor
    const query = `
      INSERT INTO product_suppliers (
        product_id, supplier_name, supplier_contact,
        cost_price, lead_time_days, is_primary
      )
      VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `;

    const result = await client.query(query, [
      productId,
      supplierName,
      supplierContact,
      costPrice,
      leadTimeDays,
      isPrimary
    ]);

    await client.query('COMMIT');
    return result.rows[0];
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error al agregar proveedor:', error);
    throw error;
  } finally {
    client.release();
  }
};

export const getProductSuppliers = async (productId) => {
  try {
    const query = `
      SELECT 
        ps.*,
        p.name as product_name
      FROM product_suppliers ps
      JOIN products p ON ps.product_id = p.id
      WHERE ps.product_id = $1
      ORDER BY ps.is_primary DESC, ps.created_at DESC
    `;
    
    const result = await pool.query(query, [productId]);
    return result.rows;
  } catch (error) {
    console.error('Error al obtener proveedores del producto:', error);
    throw error;
  }
};

export const updateSupplier = async (supplierId, updateData) => {
  const client = await pool.connect();
  
  try {
    await client.query('BEGIN');

    // Si se está actualizando a proveedor primario
    if (updateData.isPrimary) {
      const supplierQuery = await client.query(
        'SELECT product_id FROM product_suppliers WHERE id = $1',
        [supplierId]
      );
      
      if (supplierQuery.rows.length > 0) {
        await client.query(
          'UPDATE product_suppliers SET is_primary = false WHERE product_id = $1 AND id != $2',
          [supplierQuery.rows[0].product_id, supplierId]
        );
      }
    }

    // Construir la consulta de actualización dinámicamente
    const updateFields = [];
    const values = [];
    let paramCount = 1;

    Object.entries(updateData).forEach(([key, value]) => {
      if (value !== undefined) {
        updateFields.push(`${key} = $${paramCount}`);
        values.push(value);
        paramCount++;
      }
    });

    if (updateFields.length === 0) {
      throw new Error('No hay campos para actualizar');
    }

    values.push(supplierId);
    const query = `
      UPDATE product_suppliers 
      SET ${updateFields.join(', ')}
      WHERE id = $${paramCount}
      RETURNING *
    `;

    const result = await client.query(query, values);
    await client.query('COMMIT');
    
    return result.rows[0];
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Error al actualizar proveedor:', error);
    throw error;
  } finally {
    client.release();
  }
}; 