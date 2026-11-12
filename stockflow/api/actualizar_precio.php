<?php
// POST: cambia el precio de venta de un producto con dbo.sp_ActualizarPrecioProducto.
// Cuerpo JSON: { "producto_id": 3, "precio_venta": 12900 }
// El procedimiento cierra el periodo vigente y abre uno nuevo (historial);
// el trigger trg_ProductoPrecio_ProtegerHistorial impide pisar precios.
require_once '../conexion.php';

$d = leer_json();
if (!isset($d['producto_id'], $d['precio_venta'])) {
    http_response_code(400);
    echo json_encode(["status" => "error", "message" => "Se requieren producto_id y precio_venta."]);
    exit;
}

try {
    $stmt = $conn->prepare("EXEC dbo.sp_ActualizarPrecioProducto @ProductoId = ?, @PrecioVenta = ?");
    $stmt->execute([(int)$d['producto_id'], (string)$d['precio_venta']]);
    echo json_encode(["status" => "success", "message" => "Precio actualizado; el periodo anterior quedo cerrado en el historial."]);
} catch (PDOException $e) {
    respuesta_error($e);
}
?>
