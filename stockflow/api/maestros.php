<?php
// GET: datos maestros para el formulario de venta: clientes activos (con su
// direccion principal), vendedores activos y depositos por sucursal.
require_once '../conexion.php';

try {
    $clientes = $conn->query(
        "SELECT c.ClienteId, CONCAT(c.Apellido, N', ', c.Nombre) AS Cliente,
                CONCAT(c.TipoDoc, N' ', c.NroDoc) AS Documento,
                d.NroDireccion, CONCAT(d.Calle, N' ', d.Numero, N', ', d.Ciudad) AS Direccion
         FROM dbo.Cliente AS c
         LEFT JOIN dbo.ClienteDireccion AS d ON d.ClienteId = c.ClienteId AND d.EsPrincipal = 1
         WHERE c.Activo = 1
         ORDER BY c.Apellido, c.Nombre")->fetchAll();

    $vendedores = $conn->query(
        "SELECT e.EmpleadoId, CONCAT(e.Apellido, N', ', e.Nombre) AS Empleado, e.Rol,
                e.SucursalId, s.Nombre AS Sucursal
         FROM dbo.Empleado AS e
         JOIN dbo.Sucursal AS s ON s.SucursalId = e.SucursalId
         WHERE e.Activo = 1 AND e.Rol IN ('VENDEDOR', 'GERENTE', 'ADMIN')
         ORDER BY s.Nombre, e.Apellido")->fetchAll();

    $depositos = $conn->query(
        "SELECT DepositoId, Nombre, SucursalId FROM dbo.Deposito ORDER BY SucursalId, Nombre")->fetchAll();

    echo json_encode(["status" => "success",
                      "data" => ["clientes" => $clientes, "vendedores" => $vendedores, "depositos" => $depositos]]);
} catch (PDOException $e) {
    respuesta_error($e);
}
?>
