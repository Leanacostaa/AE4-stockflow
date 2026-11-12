<?php
// POST: registra una venta mediante dbo.sp_RegistrarPedido.
// Cuerpo JSON esperado:
// { "cliente_id": 1, "empleado_id": 3, "sucursal_id": 1, "deposito_id": 1,
//   "canal": "WEB", "nro_direccion": 1,
//   "items": [ { "ProductoId": 6, "Cantidad": 2, "DescuentoPct": 0 } ] }
// Todas las validaciones de negocio (cliente activo, sucursal del vendedor,
// stock, precio vigente, etc.) las hace el procedimiento; si alguna falla,
// la transaccion se revierte completa y se devuelve el mensaje del THROW.
require_once '../conexion.php';

$d = leer_json();
foreach (['cliente_id', 'empleado_id', 'sucursal_id', 'deposito_id', 'canal', 'items'] as $campo) {
    if (!isset($d[$campo])) {
        http_response_code(400);
        echo json_encode(["status" => "error", "message" => "Falta el campo obligatorio: $campo"]);
        exit;
    }
}

$nroDireccion = isset($d['nro_direccion']) && $d['nro_direccion'] !== '' ? (int)$d['nro_direccion'] : null;
$items = json_encode(array_map(function ($i) {
    return [
        "ProductoId"   => (int)($i['ProductoId'] ?? 0),
        "Cantidad"     => (float)($i['Cantidad'] ?? 0),
        "DescuentoPct" => (float)($i['DescuentoPct'] ?? 0),
    ];
}, is_array($d['items']) ? $d['items'] : []));

$sql = "SET NOCOUNT ON;
        DECLARE @PedidoId INT, @NroPedido NVARCHAR(16);
        EXEC dbo.sp_RegistrarPedido
             @ClienteId = ?, @EmpleadoId = ?, @SucursalId = ?, @DepositoId = ?,
             @Canal = ?, @NroDireccion = ?, @ItemsJson = ?,
             @PedidoId = @PedidoId OUTPUT, @NroPedido = @NroPedido OUTPUT;
        SELECT @PedidoId AS PedidoId, @NroPedido AS NroPedido;";

try {
    $stmt = $conn->prepare($sql);
    $stmt->execute([
        (int)$d['cliente_id'], (int)$d['empleado_id'], (int)$d['sucursal_id'], (int)$d['deposito_id'],
        (string)$d['canal'], $nroDireccion, $items,
    ]);
    $r = $stmt->fetch();
    echo json_encode([
        "status"     => "success",
        "pedido_id"  => (int)$r['PedidoId'],
        "nro_pedido" => $r['NroPedido'],
        "message"    => "Pedido " . $r['NroPedido'] . " registrado y stock descontado.",
    ]);
} catch (PDOException $e) {
    respuesta_error($e);
}
?>
