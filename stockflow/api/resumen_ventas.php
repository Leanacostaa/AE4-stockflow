<?php
// GET: cartera de clientes (vista vw_ResumenVentasCliente, que usa fn_TotalCompradoCliente).
require_once '../conexion.php';

try {
    $stmt = $conn->query(
        "SELECT ClienteId, Cliente, Documento, Email, CantidadPedidos, TotalComprado,
                UltimaCompra, CAST(SaldoPendiente AS DECIMAL(16,2)) AS SaldoPendiente
         FROM dbo.vw_ResumenVentasCliente
         ORDER BY TotalComprado DESC");
    echo json_encode(["status" => "success", "data" => $stmt->fetchAll()]);
} catch (PDOException $e) {
    respuesta_error($e);
}
?>
