<?php
// C:\xampp\htdocs\stockflow\api\resumen_ventas.php
require_once '../conexion.php';

try {
    $stmt = $conn->prepare("SELECT * FROM vw_ResumenVentasClientes");
    $stmt->execute();
    $resumen = $stmt->fetchAll();

    echo json_encode(["status" => "success", "data" => $resumen]);
} catch (PDOException $e) {
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}
?>