<?php
// GET: catalogo de productos activos (vista vw_CatalogoProductos).
require_once '../conexion.php';

try {
    $stmt = $conn->query(
        "SELECT ProductoId, Sku, Producto, Categoria, Marca, PrecioVigente, StockTotal, ProveedorPreferido
         FROM dbo.vw_CatalogoProductos
         WHERE Activo = 1
         ORDER BY Categoria, Producto");
    echo json_encode(["status" => "success", "data" => $stmt->fetchAll()]);
} catch (PDOException $e) {
    respuesta_error($e);
}
?>
