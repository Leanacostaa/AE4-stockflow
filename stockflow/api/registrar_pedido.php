<?php
// C:\xampp\htdocs\stockflow\api\registrar_pedido.php
require_once '../conexion.php';

$data = json_decode(file_get_contents("php://input"), true);

if (!isset($data['cliente_id'])) {
    echo json_encode(["status" => "error", "message" => "El ID de cliente es obligatorio."]);
    exit;
}

$clienteId = intval($data['cliente_id']);

try {
    // Ejecutar Stored Procedure con parámetros de salida OUT
    $stmt = $conn->prepare("CALL sp_RegistrarPedido(:clienteId, @nuevoId, @mensaje)");
    $stmt->bindParam(':clienteId', $clienteId, PDO::PARAM_INT);
    $stmt->execute();

    // Obtener los valores OUT
    $output = $conn->query("SELECT @nuevoId AS nuevoId, @mensaje AS mensaje")->fetch();

    echo json_encode([
        "status" => $output['nuevoId'] ? "success" : "error",
        "pedido_id" => $output['nuevoId'],
        "message" => $output['mensaje']
    ]);
} catch (PDOException $e) {
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}
?>