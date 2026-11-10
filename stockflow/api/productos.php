<?php
// C:\xampp\htdocs\stockflow\api\productos.php
require_once '../conexion.php';

try {
    $query = "SELECT p.ProductoId, p.Nombre AS Producto, c.Nombre AS Categoria, 
                     pr.RazonSocial AS Proveedor, p.Precio, 
                     COALESCE(SUM(s.CantidadStock), 0) AS StockTotal
              FROM PRODUCTOS p
              INNER JOIN CATEGORIAS c ON p.CategoriaId = c.CategoriaId
              INNER JOIN PROVEEDORES pr ON p.ProveedorId = pr.ProveedorId
              LEFT JOIN STOCK_DEPOSITO s ON p.ProductoId = s.ProductoId
              GROUP BY p.ProductoId, p.Nombre, c.Nombre, pr.RazonSocial, p.Precio
              ORDER BY p.ProductoId ASC";
              
    $stmt = $conn->prepare($query);
    $stmt->execute();
    $productos = $stmt->fetchAll();

    echo json_encode(["status" => "success", "data" => $productos]);
} catch (PDOException $e) {
    echo json_encode(["status" => "error", "message" => $e->getMessage()]);
}
?>