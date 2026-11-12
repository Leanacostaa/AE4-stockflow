<?php
// GET: existencias por deposito con semaforo de reposicion (vw_StockPorDeposito).
require_once '../conexion.php';

try {
    $stmt = $conn->query(
        "SELECT v.DepositoId, v.Deposito, v.Sucursal, v.CapacidadMaxima,
                o.OcupacionActual, v.ProductoId, v.Sku, v.Producto,
                v.Cantidad, v.StockMinimo, v.EstadoStock
         FROM dbo.vw_StockPorDeposito AS v
         JOIN dbo.vw_DepositoOcupacion AS o ON o.DepositoId = v.DepositoId
         ORDER BY v.DepositoId, v.Producto");
    echo json_encode(["status" => "success", "data" => $stmt->fetchAll()]);
} catch (PDOException $e) {
    respuesta_error($e);
}
?>
