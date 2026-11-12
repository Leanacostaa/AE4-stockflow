<?php
// GET: historial de precios (dbo.ProductoPrecio), los periodos mas recientes primero.
require_once '../conexion.php';

try {
    $stmt = $conn->query(
        "SELECT TOP (30) pp.ProductoId, p.Sku, p.Nombre AS Producto,
                pp.FechaDesde, pp.FechaHasta, pp.PrecioVenta,
                CASE WHEN pp.FechaHasta IS NULL THEN 'VIGENTE' ELSE 'CERRADO' END AS Situacion
         FROM dbo.ProductoPrecio AS pp
         JOIN dbo.Producto AS p ON p.ProductoId = pp.ProductoId
         ORDER BY pp.FechaDesde DESC, pp.ProductoId");
    echo json_encode(["status" => "success", "data" => $stmt->fetchAll()]);
} catch (PDOException $e) {
    respuesta_error($e);
}
?>
