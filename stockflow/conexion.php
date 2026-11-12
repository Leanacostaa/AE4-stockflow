<?php
// StockFlow - conexion a SQL Server 2022 (base StockFlow, AE4)
// Requiere la extension pdo_sqlsrv (Microsoft Drivers for PHP for SQL Server)
// y el ODBC Driver 17 u 18 for SQL Server.
//
// Autenticacion:
//   - Windows: dejar $usuario y $clave vacios. El proceso de PHP (por ejemplo
//     Apache de XAMPP) debe ejecutarse con un usuario de Windows que tenga
//     acceso a la base.
//   - SQL Server: completar $usuario y $clave con un login SQL (requiere que
//     la instancia tenga habilitada la autenticacion mixta).
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");

$servidor = "localhost\\SQLEXPRESS";
$base     = "StockFlow";
$usuario  = "";
$clave    = "";

try {
    $conn = new PDO("sqlsrv:Server=$servidor;Database=$base;TrustServerCertificate=1", $usuario, $clave);
    $conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $conn->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["status" => "error", "message" => "Error de conexion: " . $e->getMessage()]);
    exit;
}

// Los procedimientos almacenados informan sus errores con THROW (codigos
// 50001-50199). El driver los entrega como PDOException: se extrae el codigo
// y el texto del mensaje, sin el prefijo del driver ODBC.
function respuesta_error(PDOException $e) {
    $codigo  = isset($e->errorInfo[1]) ? (int)$e->errorInfo[1] : 0;
    $mensaje = isset($e->errorInfo[2]) ? $e->errorInfo[2] : $e->getMessage();
    $pos = strrpos($mensaje, ']');
    if ($pos !== false) {
        $mensaje = trim(substr($mensaje, $pos + 1));
    }
    http_response_code($codigo >= 50000 ? 422 : 500);
    echo json_encode(["status" => "error", "code" => $codigo, "message" => $mensaje]);
}

function leer_json() {
    $datos = json_decode(file_get_contents("php://input"), true);
    return is_array($datos) ? $datos : [];
}
?>
