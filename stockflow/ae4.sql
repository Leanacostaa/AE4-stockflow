-- =============================================================================
-- TRABAJO FINAL INTEGRADOR (AE4) - STOCKFLOW / TIENDA SIMPLE DB
-- SGBD: MySQL 8.0+
-- =============================================================================

-- 0. CREACIÓN Y CONFIGURACIÓN DE LA BASE DE DATOS
DROP DATABASE IF EXISTS TiendaSimpleDB;
CREATE DATABASE TiendaSimpleDB DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE TiendaSimpleDB;

-- =============================================================================
-- 1. TABLAS INDEPENDIENTES (Sin Claves Foráneas)
-- =============================================================================

CREATE TABLE CATEGORIAS (
    CategoriaId INT AUTO_INCREMENT PRIMARY KEY,
    Nombre VARCHAR(50) NOT NULL,
    Descripcion VARCHAR(200) NULL,
    CONSTRAINT UQ_Categorias_Nombre UNIQUE (Nombre)
) ENGINE=InnoDB;

CREATE TABLE DEPOSITOS (
    DepositoId INT AUTO_INCREMENT PRIMARY KEY,
    Nombre VARCHAR(50) NOT NULL,
    Ubicacion VARCHAR(100) NOT NULL,
    CapacidadMaxima INT NULL,
    CONSTRAINT UQ_Depositos_Nombre UNIQUE (Nombre),
    CONSTRAINT CHK_Depositos_Capacidad CHECK (CapacidadMaxima IS NULL OR CapacidadMaxima > 0)
) ENGINE=InnoDB;

CREATE TABLE PROVEEDORES (
    ProveedorId INT AUTO_INCREMENT PRIMARY KEY,
    RazonSocial VARCHAR(100) NOT NULL,
    CUIT VARCHAR(13) NOT NULL,
    Telefono VARCHAR(20) NULL,
    CONSTRAINT UQ_Proveedores_CUIT UNIQUE (CUIT)
) ENGINE=InnoDB;

CREATE TABLE CLIENTES (
    ClienteId INT AUTO_INCREMENT PRIMARY KEY,
    Nombre VARCHAR(50) NOT NULL,
    Apellido VARCHAR(50) NOT NULL,
    Email VARCHAR(100) NOT NULL,
    FechaAlta DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT UQ_Clientes_Email UNIQUE (Email)
) ENGINE=InnoDB;

-- Atributo Multivaluado de Clientes (Teléfonos)
CREATE TABLE TELEFONOS_CLIENTE (
    ClienteId INT NOT NULL,
    Telefono VARCHAR(20) NOT NULL,
    PRIMARY KEY (ClienteId, Telefono),
    CONSTRAINT FK_TelefonosCliente_Clientes FOREIGN KEY (ClienteId)
        REFERENCES CLIENTES (ClienteId) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =============================================================================
-- 2. TABLAS DEPENDIENTES
-- =============================================================================

CREATE TABLE PRODUCTOS (
    ProductoId INT AUTO_INCREMENT PRIMARY KEY,
    CategoriaId INT NOT NULL,
    ProveedorId INT NOT NULL,
    Nombre VARCHAR(100) NOT NULL,
    Precio DECIMAL(10,2) NOT NULL,
    CONSTRAINT CHK_Productos_Precio CHECK (Precio > 0),
    CONSTRAINT FK_Productos_Categorias FOREIGN KEY (CategoriaId)
        REFERENCES CATEGORIAS (CategoriaId) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT FK_Productos_Proveedores FOREIGN KEY (ProveedorId)
        REFERENCES PROVEEDORES (ProveedorId) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE PEDIDOS (
    PedidoId INT AUTO_INCREMENT PRIMARY KEY,
    ClienteId INT NOT NULL,
    FechaPedido DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT FK_Pedidos_Clientes FOREIGN KEY (ClienteId)
        REFERENCES CLIENTES (ClienteId) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =============================================================================
-- 3. TABLAS ASOCIATIVAS (Claves Primarias Compuestas - Relaciones N:M)
-- =============================================================================

-- Inventario distribuido por depósito (Relación N:M Productos - Depósitos)
CREATE TABLE STOCK_DEPOSITO (
    ProductoId INT NOT NULL,
    DepositoId INT NOT NULL,
    CantidadStock INT NOT NULL,
    PRIMARY KEY (ProductoId, DepositoId),
    CONSTRAINT CHK_StockDeposito_Cantidad CHECK (CantidadStock >= 0),
    CONSTRAINT FK_StockDeposito_Productos FOREIGN KEY (ProductoId)
        REFERENCES PRODUCTOS (ProductoId) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_StockDeposito_Depositos FOREIGN KEY (DepositoId)
        REFERENCES DEPOSITOS (DepositoId) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Detalle del pedido / Renglones (Relación N:M Pedidos - Productos)
CREATE TABLE DETALLE_PEDIDO (
    PedidoId INT NOT NULL,
    ProductoId INT NOT NULL,
    Cantidad INT NOT NULL,
    PrecioUnitarioHistorico DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (PedidoId, ProductoId),
    CONSTRAINT CHK_DetallePedido_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CHK_DetallePedido_Precio CHECK (PrecioUnitarioHistorico > 0),
    CONSTRAINT FK_DetallePedido_Pedidos FOREIGN KEY (PedidoId)
        REFERENCES PEDIDOS (PedidoId) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_DetallePedido_Productos FOREIGN KEY (ProductoId)
        REFERENCES PRODUCTOS (ProductoId) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Tabla de Auditoría para Cambios de Precios (Requerida para Triggers)
CREATE TABLE AUDITORIA_PRECIOS (
    AuditoriaId INT AUTO_INCREMENT PRIMARY KEY,
    ProductoId INT NOT NULL,
    PrecioAnterior DECIMAL(10,2) NOT NULL,
    PrecioNuevo DECIMAL(10,2) NOT NULL,
    FechaModificacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Usuario VARCHAR(100) NOT NULL DEFAULT (CURRENT_USER())
) ENGINE=InnoDB;

-- =============================================================================
-- 4. CARGA DE DATOS DE PRUEBA (DML INICIAL)
-- =============================================================================

INSERT INTO CATEGORIAS (Nombre, Descripcion) VALUES 
('Almacenamiento', 'Discos SSD, HDD y memorias externas'),
('Procesadores', 'Unidades centrales de procesamiento CPU'),
('Periféricos', 'Teclados, mouse y auriculares gamer');

INSERT INTO DEPOSITOS (Nombre, Ubicacion, CapacidadMaxima) VALUES 
('Depósito Central', 'Av. Corrientes 1234, Posadas', 5000),
('Depósito Norte', 'Ruta 12 Km 7.5, Garupá', 3000);

INSERT INTO PROVEEDORES (RazonSocial, CUIT, Telefono) VALUES 
('TechSupply S.A.', '30-71112223-4', '3794112233'),
('Global Hardware SRL', '30-68889991-9', '01145556677');

INSERT INTO CLIENTES (Nombre, Apellido, Email) VALUES 
('Leandro', 'Acosta', 'leandro.acosta@uCP.edu.ar'),
('Nahuel', 'Villegas', 'nahuel.villegas@ucp.edu.ar');

INSERT INTO TELEFONOS_CLIENTE (ClienteId, Telefono) VALUES 
(1, '3764556677'),
(2, '3794889900');

INSERT INTO PRODUCTOS (CategoriaId, ProveedorId, Nombre, Precio) VALUES 
(1, 1, 'Disco SSD NVMe 1TB', 45000.00),
(2, 2, 'Procesador AMD Ryzen 7', 180000.00),
(3, 1, 'Teclado Mecánico RGB', 25000.00);

INSERT INTO STOCK_DEPOSITO (ProductoId, DepositoId, CantidadStock) VALUES 
(1, 1, 50),
(2, 1, 20),
(3, 2, 100);

INSERT INTO PEDIDOS (ClienteId, FechaPedido) VALUES 
(1, '2026-10-10 14:30:00'),
(2, '2026-10-12 09:15:00');

INSERT INTO DETALLE_PEDIDO (PedidoId, ProductoId, Cantidad, PrecioUnitarioHistorico) VALUES 
(1, 1, 2, 45000.00),
(2, 3, 1, 25000.00);

-- =============================================================================
-- 5. PROGRAMACIÓN EN BASE DE DATOS (FUNCIONES, PROCEDIMIENTOS Y TRIGGERS)
-- =============================================================================

DELIMITER //

-- Función 1: Calcular el gasto total acumulado de un cliente
CREATE FUNCTION fn_CalcularTotalGastoCliente(p_ClienteId INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_TotalGasto DECIMAL(10,2);
    SELECT COALESCE(SUM(dp.Cantidad * dp.PrecioUnitarioHistorico), 0.00)
    INTO v_TotalGasto
    FROM PEDIDOS p
    INNER JOIN DETALLE_PEDIDO dp ON p.PedidoId = dp.PedidoId
    WHERE p.ClienteId = p_ClienteId;
    RETURN v_TotalGasto;
END //

-- Procedimiento Almacenado 1: Registrar un pedido de forma transaccional y controlada
CREATE PROCEDURE sp_RegistrarPedido(
    IN p_ClienteId INT,
    OUT p_NuevoPedidoId INT,
    OUT p_Mensaje VARCHAR(255)
)
PROC_BODY: BEGIN
    DECLARE v_ExisteCliente INT DEFAULT 0;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_NuevoPedidoId = NULL;
        SET p_Mensaje = 'ERROR: Transacción abortada por fallo en el servidor.';
    END;

    SELECT COUNT(*) INTO v_ExisteCliente FROM CLIENTES WHERE ClienteId = p_ClienteId;
    IF v_ExisteCliente = 0 THEN
        SET p_NuevoPedidoId = NULL;
        SET p_Mensaje = 'ERROR: El cliente no existe.';
        LEAVE PROC_BODY;
    END IF;

    START TRANSACTION;
        INSERT INTO PEDIDOS (ClienteId, FechaPedido) VALUES (p_ClienteId, CURRENT_TIMESTAMP);
        SET p_NuevoPedidoId = LAST_INSERT_ID();
    COMMIT;

    SET p_Mensaje = CONCAT('ÉXITO: Pedido N° ', p_NuevoPedidoId, ' registrado correctamente.');
END //

-- Trigger 1: Auditoría automática de cambios de precios en productos
CREATE TRIGGER trg_AuditarCambioPrecioProducto
AFTER UPDATE ON PRODUCTOS
FOR EACH ROW
BEGIN
    IF OLD.Precio <> NEW.Precio THEN
        INSERT INTO AUDITORIA_PRECIOS (ProductoId, PrecioAnterior, PrecioNuevo, FechaModificacion, Usuario)
        VALUES (OLD.ProductoId, OLD.Precio, NEW.Precio, NOW(), USER());
    END IF;
END //

-- Trigger 2: Validación de cantidad y asignación de precio histórico en detalles
CREATE TRIGGER trg_ValidarYAsignarPrecioHistorico
BEFORE INSERT ON DETALLE_PEDIDO
FOR EACH ROW
BEGIN
    DECLARE v_PrecioCatalogo DECIMAL(10,2);
    SELECT Precio INTO v_PrecioCatalogo FROM PRODUCTOS WHERE ProductoId = NEW.ProductoId;

    IF NEW.PrecioUnitarioHistorico IS NULL OR NEW.PrecioUnitarioHistorico <= 0 THEN
        SET NEW.PrecioUnitarioHistorico = v_PrecioCatalogo;
    END IF;

    IF NEW.Cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ERROR: La cantidad debe ser mayor a 0.';
    END IF;
END //

DELIMITER ;

-- =============================================================================
-- 6. CREACIÓN DE VISTA (Requerimiento de Consultas Avanzadas)
-- =============================================================================

CREATE VIEW vw_ResumenVentasClientes AS
SELECT 
    c.ClienteId,
    CONCAT(c.Apellido, ', ', c.Nombre) AS Cliente,
    COUNT(p.PedidoId) AS TotalPedidos,
    fn_CalcularTotalGastoCliente(c.ClienteId) AS MontoTotalHistorico
FROM CLIENTES c
LEFT JOIN PEDIDOS p ON c.ClienteId = p.ClienteId
GROUP BY c.ClienteId, c.Apellido, c.Nombre;