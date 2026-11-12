/* ==========================================================================
   AE4 - ISI17BAD28V26AE4V26 - Proyecto StockFlow
   Archivo: 02_datos_prueba.sql  -- Carga inicial de datos (SQL DML)
   Ejecutar DESPUES de 01_ddl.sql
   --------------------------------------------------------------------------
   Primera parte: juego de datos del AE2, sin modificaciones. Representa
   la migracion de saldos e historia previa a la puesta en marcha: por eso se
   carga ANTES de crear los triggers (04_programacion.sql). Las existencias
   de dbo.Stock son saldos iniciales; desde la puesta en marcha solo cambian
   a traves de movimientos de kardex (RN11).
   Segunda parte (seccion 14): datos agregados en AE4 para ejercitar casos limite
   (valores NULL, producto inactivo, producto sin precio, cliente sin
   pedidos, cliente empresa).
   Los IDENTITY son deterministicos porque la base se crea vacia.
   ========================================================================== */

/* Opciones de sesion requeridas por los indices filtrados, las columnas
   calculadas y los modulos programados. SSMS las activa por defecto, pero
   sqlcmd no: se fijan explicitamente para que el script sea portable. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE StockFlow;
GO
SET NOCOUNT ON;
GO

PRINT '--- Sucursales ---';
INSERT INTO dbo.Sucursal (Nombre, Calle, Numero, Ciudad, Provincia, Telefono) VALUES
 (N'Casa Central',  N'Av. Mitre',      N'1250', N'Posadas',       N'Misiones',    N'376-4440001'),
 (N'Sucursal Norte',N'Av. Uruguay',    N'3400', N'Posadas',       N'Misiones',    N'376-4440002'),
 (N'Sucursal Obera',N'Av. Sarmiento',  N'820',  N'Obera',         N'Misiones',    N'3755-410033');
GO

PRINT '--- Empleados ---';
/* El gerente (1) se inserta sin supervisor; el resto lo referencia. */
INSERT INTO dbo.Empleado (Legajo, Nombre, Apellido, Dni, Email, FechaIngreso, Rol, SucursalId, SupervisorId) VALUES
 (N'E-0001', N'Laura',   N'Benitez',  N'28456123', N'lbenitez@empresa.com.ar', '2018-03-05', N'GERENTE',  1, NULL);
GO
INSERT INTO dbo.Empleado (Legajo, Nombre, Apellido, Dni, Email, FechaIngreso, Rol, SucursalId, SupervisorId) VALUES
 (N'E-0002', N'Marcos',  N'Duarte',   N'31220987', N'mduarte@empresa.com.ar',  '2019-07-15', N'COMPRAS',  1, 1),
 (N'E-0003', N'Sofia',   N'Ramirez',  N'34567891', N'sramirez@empresa.com.ar', '2020-02-10', N'VENDEDOR', 1, 1),
 (N'E-0004', N'Diego',   N'Fernandez',N'30112233', N'dfernandez@empresa.com.ar','2017-11-02',N'DEPOSITO', 1, 1),
 (N'E-0005', N'Carla',   N'Ojeda',    N'36998877', N'cojeda@empresa.com.ar',   '2021-05-20', N'VENDEDOR', 2, 1),
 (N'E-0006', N'Hernan',  N'Villalba', N'29887766', N'hvillalba@empresa.com.ar','2016-09-01', N'DEPOSITO', 2, 1),
 (N'E-0007', N'Julieta', N'Maidana',  N'38445566', N'jmaidana@empresa.com.ar', '2022-01-17', N'VENDEDOR', 3, 1),
 (N'E-0008', N'Pablo',   N'Acosta',   N'33221144', N'pacosta@empresa.com.ar',  '2019-04-08', N'ADMIN',    1, 1);
GO

PRINT '--- Categorias (jerarquicas) ---';
INSERT INTO dbo.Categoria (Nombre, Descripcion, CategoriaPadreId) VALUES
 (N'Informatica',    N'Rubro general de computacion', NULL),
 (N'Electrohogar',   N'Linea blanca y pequenos electrodomesticos', NULL);
GO
INSERT INTO dbo.Categoria (Nombre, Descripcion, CategoriaPadreId) VALUES
 (N'Notebooks',      N'Equipos portatiles',        1),
 (N'Perifericos',    N'Teclados, mouse, monitores',1),
 (N'Almacenamiento', N'Discos y memorias',         1),
 (N'Climatizacion',  N'Aires y ventiladores',      2),
 (N'Cocina',         N'Electrodomesticos de cocina',2);
GO

PRINT '--- Marcas ---';
INSERT INTO dbo.Marca (Nombre, PaisOrigen) VALUES
 (N'Lenovo', N'China'), (N'Logitech', N'Suiza'), (N'Samsung', N'Corea del Sur'),
 (N'Kingston', N'Estados Unidos'), (N'Liliana', N'Argentina'), (N'BGH', N'Argentina');
GO

PRINT '--- Productos ---';
INSERT INTO dbo.Producto (Sku, Nombre, Descripcion, CategoriaId, MarcaId, UnidadMedida, PesoKg) VALUES
 (N'NB-LEN-001', N'Notebook Lenovo IdeaPad 3 15"', N'Ryzen 5, 16GB, 512GB SSD', 3, 1, N'UN', 1.650),
 (N'NB-LEN-002', N'Notebook Lenovo ThinkPad E14',  N'i5 13th, 16GB, 512GB SSD', 3, 1, N'UN', 1.420),
 (N'MO-LOG-001', N'Mouse Logitech M170',            N'Inalambrico 2.4GHz',      4, 2, N'UN', 0.075),
 (N'TE-LOG-002', N'Teclado Logitech K380',          N'Bluetooth multidispositivo',4,2, N'UN', 0.423),
 (N'MN-SAM-001', N'Monitor Samsung 24" F24T350',    N'IPS 75Hz 1920x1080',      4, 3, N'UN', 3.200),
 (N'SS-KIN-001', N'SSD Kingston NV2 1TB',           N'NVMe PCIe 4.0',           5, 4, N'UN', 0.007),
 (N'SS-KIN-002', N'SSD Kingston A400 480GB',        N'SATA III 2.5"',           5, 4, N'UN', 0.041),
 (N'RM-KIN-003', N'Memoria Kingston Fury 16GB',     N'DDR4 3200MHz',            5, 4, N'UN', 0.030),
 (N'AA-BGH-001', N'Aire BGH Silent Air 3500W',      N'Frio/calor inverter',     6, 6, N'UN', 38.500),
 (N'VT-LIL-001', N'Ventilador Liliana VTF20',       N'De pie 20 pulgadas',      6, 5, N'UN', 4.800),
 (N'PA-LIL-002', N'Pava electrica Liliana AP940',   N'1.7L acero',              7, 5, N'UN', 0.950),
 (N'MC-SAM-002', N'Microondas Samsung MG23',        N'23L grill',               7, 3, N'UN', 13.200);
GO

PRINT '--- Historial de precios (uno vigente por producto) ---';
INSERT INTO dbo.ProductoPrecio (ProductoId, FechaDesde, FechaHasta, PrecioVenta, PrecioCosto) VALUES
 (1, '2026-01-02', '2026-05-31', 890000, 640000),
 (1, '2026-06-01', NULL, 1050000, 760000),
 (2, '2026-01-02', '2026-05-31', 1340000, 980000),
 (2, '2026-06-01', NULL, 1580000, 1150000),
 (3, '2026-01-02', NULL, 11500, 7200),
 (4, '2026-01-02', '2026-07-14', 56000, 38000),
 (4, '2026-07-15', NULL, 64500, 44000),
 (5, '2026-01-02', NULL, 198000, 142000),
 (6, '2026-02-01', '2026-09-19', 112000, 81000),
 (6, '2026-09-20', NULL, 129000, 93000),
 (7, '2026-02-01', NULL, 58000, 41500),
 (8, '2026-02-01', NULL, 74000, 52000),
 (9, '2026-03-01', NULL, 1250000, 910000),
 (10, '2026-03-01', NULL, 86000, 59000),
 (11, '2026-03-01', NULL, 42000, 28500),
 (12, '2026-03-01', NULL, 385000, 276000);
GO

PRINT '--- Depositos ---';
INSERT INTO dbo.Deposito (Nombre, SucursalId, Calle, Ciudad, Provincia, CapacidadMaxima) VALUES
 (N'Deposito Central',  1, N'Av. Mitre',     N'Posadas', N'Misiones', 5000),
 (N'Deposito Salon CC', 1, N'Av. Mitre',     N'Posadas', N'Misiones', 400),
 (N'Deposito Norte',    2, N'Av. Uruguay',   N'Posadas', N'Misiones', 1500),
 (N'Deposito Obera',    3, N'Av. Sarmiento', N'Obera',   N'Misiones', 900);
GO

PRINT '--- Stock por producto y deposito (relacion N:M) ---';
INSERT INTO dbo.Stock (ProductoId, DepositoId, Cantidad, StockMinimo, StockMaximo, UbicacionInterna) VALUES
 ( 1, 1,  24,  5,  80, N'A-01-03'), ( 1, 3,   6,  3,  25, N'N-02-01'),
 ( 2, 1,  11,  3,  40, N'A-01-04'),
 ( 3, 1, 180, 40, 500, N'B-04-02'), ( 3, 2,  25, 10,  60, N'S-01-01'), ( 3, 3,  44, 20, 150, N'N-01-02'),
 ( 4, 1,  62, 20, 200, N'B-04-05'), ( 4, 2,   8, 10,  40, N'S-01-02'),
 ( 5, 1,  33,  8,  90, N'C-02-01'), ( 5, 4,   7,  5,  30, N'O-01-01'),
 ( 6, 1,  95, 25, 300, N'D-01-01'),
 ( 7, 1, 140, 30, 400, N'D-01-02'), ( 7, 3,  28, 15, 100, N'N-03-01'),
 ( 8, 1,  58, 20, 200, N'D-02-01'),
 ( 9, 1,   9,  4,  30, N'E-01-01'), ( 9, 4,   2,  3,  12, N'O-02-01'),
 (10, 1,  71, 25, 250, N'E-02-01'), (10, 4,  18, 10,  60, N'O-02-02'),
 (11, 1, 110, 30, 300, N'F-01-01'), (11, 2,  14,  8,  40, N'S-02-01'),
 (12, 1,  16,  6,  50, N'F-02-01');
GO

PRINT '--- Proveedores ---';
INSERT INTO dbo.Proveedor (RazonSocial, Cuit, Email, FechaAlta) VALUES
 (N'Distribuidora Norte SRL',    '30711234567', N'ventas@distnorte.com.ar',   '2017-04-12'),
 (N'TecnoMayorista SA',          '30698765432', N'compras@tecnomay.com.ar',   '2018-08-30'),
 (N'Electro Litoral SRL',        '33715556668', N'pedidos@electrolitoral.com.ar','2020-11-05'),
 (N'Importadora Guarani SA',     '30677889912', NULL,                          '2021-06-18');
GO

PRINT '--- Telefonos de proveedor (multivaluado) ---';
INSERT INTO dbo.ProveedorTelefono (ProveedorId, NroTelefono, Telefono, Tipo) VALUES
 (1, 1, N'0376-4451122', N'PRINCIPAL'), (1, 2, N'0376-154778899', N'WHATSAPP'),
 (2, 1, N'011-47883322',  N'PRINCIPAL'), (2, 2, N'011-47883399',  N'FAX'),
 (3, 1, N'0342-4559988',  N'PRINCIPAL'),
 (4, 1, N'03757-422110',  N'PRINCIPAL'), (4, 2, N'03757-422111',  N'ALTERNATIVO');
GO

PRINT '--- Que provee cada proveedor (N:M SUMINISTRA) ---';
INSERT INTO dbo.ProveedorProducto (ProveedorId, ProductoId, PrecioCompra, PlazoEntregaDias, CodigoProveedor, EsPreferido) VALUES
 (2,  1,  760000, 10, N'TM-IDEA3',   1),
 (2,  2, 1150000, 12, N'TM-TPE14',   1),
 (1,  1,  782000,  5, N'DN-LEN-I3',  0),
 (1,  3,    7200,  3, N'DN-M170',    1),
 (1,  4,   44000,  3, N'DN-K380',    1),
 (2,  5,  142000,  8, N'TM-F24T350', 1),
 (1,  5,  148500,  4, N'DN-SAM24',   0),
 (2,  6,   81000,  7, N'TM-NV2-1T',  1),
 (2,  7,   41500,  7, N'TM-A400',    1),
 (2,  8,   52000,  7, N'TM-FURY16',  1),
 (3,  9,  910000, 15, N'EL-BGH35',   1),
 (3, 10,   59000,  6, N'EL-VTF20',   1),
 (3, 11,   28500,  6, N'EL-AP940',   1),
 (4, 12,  276000, 20, N'IG-MG23',    1),
 (3, 12,  289000,  9, N'EL-MG23',    0);
GO

PRINT '--- Ordenes de compra ---';
INSERT INTO dbo.OrdenCompra (NroOrden, ProveedorId, EmpleadoId, DepositoId, FechaEmision, FechaEntregaEstimada, Estado) VALUES
 (N'OC-2026-0001', 2, 2, 1, '2026-08-04', '2026-08-14', N'RECIBIDA'),
 (N'OC-2026-0002', 1, 2, 1, '2026-08-20', '2026-08-25', N'RECIBIDA'),
 (N'OC-2026-0003', 3, 2, 4, '2026-09-10', '2026-09-25', N'EMITIDA'),
 (N'OC-2026-0004', 4, 2, 1, '2026-09-22', '2026-10-12', N'BORRADOR');
GO

INSERT INTO dbo.OrdenCompraDetalle (OrdenCompraId, ProductoId, Cantidad, PrecioUnitario, CantidadRecibida) VALUES
 (1,  1, 15,  760000, 15), (1,  6, 40,   81000, 40), (1,  8, 25,   52000, 25),
 (2,  3, 100,   7200, 100),(2,  4, 50,   44000, 50),
 (3,  9,  6,  910000,  0), (3, 10, 30,   59000,  0),
 (4, 12, 10,  276000,  0);
GO

PRINT '--- Movimientos de stock (FK compuesta contra Stock) ---';
INSERT INTO dbo.MovimientoStock (FechaHora, ProductoId, DepositoId, TipoMovimiento, Cantidad, EmpleadoId, Motivo, DocumentoTipo, DocumentoId) VALUES
 ('2026-08-14 09:15:00',  1, 1, N'INGRESO',  15, 4, N'Recepcion OC-2026-0001', N'OC', 1),
 ('2026-08-14 09:22:00',  6, 1, N'INGRESO',  40, 4, N'Recepcion OC-2026-0001', N'OC', 1),
 ('2026-08-14 09:30:00',  8, 1, N'INGRESO',  25, 4, N'Recepcion OC-2026-0001', N'OC', 1),
 ('2026-08-25 10:05:00',  3, 1, N'INGRESO', 100, 4, N'Recepcion OC-2026-0002', N'OC', 2),
 ('2026-08-25 10:11:00',  4, 1, N'INGRESO',  50, 4, N'Recepcion OC-2026-0002', N'OC', 2),
 ('2026-09-02 16:40:00',  3, 1, N'TRANSFER', 25, 6, N'Traslado a salon',       NULL, NULL),
 ('2026-09-02 16:41:00',  3, 2, N'INGRESO',  25, 6, N'Traslado desde central', NULL, NULL),
 ('2026-09-05 11:20:00',  1, 1, N'EGRESO',    2, 4, N'Venta PED-2026-0001',    N'PEDIDO', 1),
 ('2026-09-05 11:20:00',  5, 1, N'EGRESO',    1, 4, N'Venta PED-2026-0001',    N'PEDIDO', 1),
 ('2026-09-12 15:02:00',  7, 1, N'AJUSTE',    3, 4, N'Diferencia de inventario fisico', N'AJUSTE', 1);
GO

PRINT '--- Clientes ---';
INSERT INTO dbo.Cliente (TipoDoc, NroDoc, Nombre, Apellido, Email, FechaAlta) VALUES
 (N'DNI',  N'32145678', N'Martin',   N'Gomez',     N'mgomez@mail.com',       '2024-03-11'),
 (N'DNI',  N'27998877', N'Lucia',    N'Sosa',      N'lsosa@mail.com',        '2023-09-02'),
 (N'CUIT', N'20345678901', N'Estudio','Contable RS',N'admin@estudiors.com.ar','2022-05-19'),
 (N'DNI',  N'40112233', N'Nicolas',  N'Paredes',   NULL,                     '2025-01-28'),
 (N'PAS',  N'AB1234567',N'Helena',   N'Kowalski',  N'hkowalski@mail.com',    '2025-07-06');
GO

INSERT INTO dbo.ClienteTelefono (ClienteId, NroTelefono, Telefono, Tipo) VALUES
 (1, 1, N'0376-154112233', N'PRINCIPAL'), (1, 2, N'0376-4423344', N'LABORAL'),
 (2, 1, N'0376-154998877', N'WHATSAPP'),
 (3, 1, N'0376-4412345',   N'PRINCIPAL'),
 (4, 1, N'0376-154667788', N'PRINCIPAL'),
 (5, 1, N'0376-154223344', N'PRINCIPAL');
GO

INSERT INTO dbo.ClienteDireccion (ClienteId, NroDireccion, Calle, Numero, Ciudad, Provincia, CodigoPostal, EsPrincipal) VALUES
 (1, 1, N'Rivadavia',   N'2140', N'Posadas', N'Misiones', N'N3300', 1),
 (1, 2, N'Los Lapachos',N'88',   N'Garupa',  N'Misiones', N'N3304', 0),
 (2, 1, N'Buenos Aires',N'1570', N'Posadas', N'Misiones', N'N3300', 1),
 (3, 1, N'Colon',       N'980',  N'Posadas', N'Misiones', N'N3300', 1),
 (4, 1, N'San Lorenzo', N'455',  N'Obera',   N'Misiones', N'N3360', 1),
 (5, 1, N'Cordoba',     N'1212', N'Posadas', N'Misiones', N'N3300', 1);
GO

PRINT '--- Pedidos ---';
/* Canal MOSTRADOR => NroDireccion NULL (CK_Pedido_Envio). */
INSERT INTO dbo.Pedido (NroPedido, ClienteId, NroDireccion, EmpleadoId, SucursalId, FechaPedido, Estado, Canal) VALUES
 (N'PED-2026-0001', 1, 1,    3, 1, '2026-09-05 11:05:00', N'ENTREGADO',  N'WEB'),
 (N'PED-2026-0002', 2, NULL, 5, 2, '2026-09-08 17:30:00', N'ENTREGADO',  N'MOSTRADOR'),
 (N'PED-2026-0003', 3, 1,    3, 1, '2026-09-15 10:12:00', N'ENTREGADO',  N'TELEFONO'),
 (N'PED-2026-0004', 4, 1,    7, 3, '2026-09-24 12:45:00', N'CONFIRMADO', N'WEB'),
 (N'PED-2026-0005', 5, NULL, 5, 2, '2026-09-29 19:02:00', N'PENDIENTE',  N'MOSTRADOR');
GO

INSERT INTO dbo.PedidoDetalle (PedidoId, ProductoId, Cantidad, PrecioUnitarioHistorico, DescuentoPct) VALUES
 (1, 1, 2, 1050000, 0),
 (1, 5, 1, 198000, 5),
 (2, 3, 2, 11500, 0),
 (2, 4, 1, 64500, 10),
 (3, 6, 4, 112000, 0),
 (3, 8, 2, 74000, 0),
 (3, 5, 2, 198000, 7.5),
 (4, 10, 3, 86000, 0),
 (4, 11, 2, 42000, 0),
 (5, 7, 1, 58000, 0);
GO

/* Totales netos calculados a partir del detalle:
     Pedido 1: neto 2288100.00
     Pedido 2: neto 81050.00
     Pedido 3: neto 962300.00
     Pedido 4: neto 342000.00
     Pedido 5: neto 58000.00
*/

PRINT '--- Facturas (1:1 con pedido, solo los entregados y confirmados) ---';
INSERT INTO dbo.Factura (PedidoId, TipoComprobante, PuntoVenta, NroComprobante, FechaEmision, Neto, AlicuotaIva) VALUES
 (1, 'A', 1, 1001, '2026-09-05', 2288100.00, 21),
 (2, 'B', 1, 1002, '2026-09-08', 81050.00, 21),
 (3, 'A', 1, 1003, '2026-09-15', 962300.00, 21),
 (4, 'B', 3, 2001, '2026-09-24', 342000.00, 21);
GO

PRINT '--- Medios de pago ---';
INSERT INTO dbo.MedioPago (Nombre, RecargoPct) VALUES
 (N'Efectivo', 0), (N'Transferencia', 0), (N'Tarjeta de debito', 0),
 (N'Tarjeta de credito 3 cuotas', 12.50), (N'Cuenta corriente', 0);
GO

PRINT '--- Pagos (parciales y en varios medios sobre la misma factura) ---';
INSERT INTO dbo.Pago (FacturaId, NroPago, FechaPago, Monto, MedioPagoId, Referencia) VALUES
 (1, 1, '2026-09-05', 1384300.50, 2, 'TRF-889211'),
 (1, 2, '2026-09-20', 1384300.50, 4, 'VISA-4417'),
 (2, 1, '2026-09-08', 98070.50, 1, NULL),
 (3, 1, '2026-09-15', 465753.20, 2, 'TRF-901344');
GO

/* Factura 4 queda sin pagos: saldo pendiente completo.
   Factura 3 cobrada parcialmente: saldo 698629.80. */
/* ==========================================================================
   14. DATOS AGREGADOS EN AE4 (casos limite)
   ========================================================================== */
PRINT '--- AE4: productos para casos limite ---';
/* 13: producto dado de baja logica (Activo = 0): no puede venderse.
   14: producto recien dado de alta, todavia sin precio ni stock (NULL). */
INSERT INTO dbo.Producto (Sku, Nombre, Descripcion, CategoriaId, MarcaId, UnidadMedida, PesoKg, Activo) VALUES
 (N'IM-SAM-003', N'Impresora Samsung Xpress M2020', N'Laser monocromatica (discontinuada)', 4, 3, N'UN', 4.100, 0),
 (N'WC-LOG-004', N'Webcam Logitech C920',           NULL,                                  4, 2, N'UN', NULL,  1);
GO
INSERT INTO dbo.ProductoPrecio (ProductoId, FechaDesde, FechaHasta, PrecioVenta, PrecioCosto) VALUES
 (13, '2026-01-02', NULL, 310000, 220000);
GO

PRINT '--- AE4: clientes para casos limite ---';
/* 6: cliente sin email, sin telefono y sin pedidos (tratamiento de NULL).
   7: cliente empresa (CUIT): se le emite factura A. */
INSERT INTO dbo.Cliente (TipoDoc, NroDoc, Nombre, Apellido, Email, FechaAlta) VALUES
 (N'DNI',  N'35111222',    N'Rocio',       N'Benitez',      NULL,                      '2026-10-20'),
 (N'CUIT', N'30715559991', N'Tecnologias', N'del Litoral SA', N'compras@tecnolitoral.com.ar', '2026-10-28');
GO
INSERT INTO dbo.ClienteTelefono (ClienteId, NroTelefono, Telefono, Tipo) VALUES
 (7, 1, N'0376-4498800', N'LABORAL');
INSERT INTO dbo.ClienteDireccion (ClienteId, NroDireccion, Calle, Numero, Ciudad, Provincia, CodigoPostal, EsPrincipal) VALUES
 (7, 1, N'Av. Quaranta', N'5100', N'Posadas', N'Misiones', N'N3300', 1);
GO

PRINT '--- Recuento de filas cargadas ---';
SELECT 'Sucursal' AS Tabla, COUNT(*) AS Filas FROM dbo.Sucursal
UNION ALL SELECT 'Empleado',              COUNT(*) FROM dbo.Empleado
UNION ALL SELECT 'Categoria',             COUNT(*) FROM dbo.Categoria
UNION ALL SELECT 'Marca',                 COUNT(*) FROM dbo.Marca
UNION ALL SELECT 'Producto',              COUNT(*) FROM dbo.Producto
UNION ALL SELECT 'ProductoPrecio',        COUNT(*) FROM dbo.ProductoPrecio
UNION ALL SELECT 'Deposito',              COUNT(*) FROM dbo.Deposito
UNION ALL SELECT 'Stock',                 COUNT(*) FROM dbo.Stock
UNION ALL SELECT 'MovimientoStock',       COUNT(*) FROM dbo.MovimientoStock
UNION ALL SELECT 'Proveedor',             COUNT(*) FROM dbo.Proveedor
UNION ALL SELECT 'ProveedorTelefono',     COUNT(*) FROM dbo.ProveedorTelefono
UNION ALL SELECT 'ProveedorProducto',     COUNT(*) FROM dbo.ProveedorProducto
UNION ALL SELECT 'OrdenCompra',           COUNT(*) FROM dbo.OrdenCompra
UNION ALL SELECT 'OrdenCompraDetalle',    COUNT(*) FROM dbo.OrdenCompraDetalle
UNION ALL SELECT 'Cliente',               COUNT(*) FROM dbo.Cliente
UNION ALL SELECT 'ClienteTelefono',       COUNT(*) FROM dbo.ClienteTelefono
UNION ALL SELECT 'ClienteDireccion',      COUNT(*) FROM dbo.ClienteDireccion
UNION ALL SELECT 'Pedido',                COUNT(*) FROM dbo.Pedido
UNION ALL SELECT 'PedidoDetalle',         COUNT(*) FROM dbo.PedidoDetalle
UNION ALL SELECT 'PedidoEstadoHistorial', COUNT(*) FROM dbo.PedidoEstadoHistorial
UNION ALL SELECT 'Factura',               COUNT(*) FROM dbo.Factura
UNION ALL SELECT 'MedioPago',             COUNT(*) FROM dbo.MedioPago
UNION ALL SELECT 'Pago',                  COUNT(*) FROM dbo.Pago
ORDER BY Tabla;
GO

PRINT 'Datos de prueba cargados.';
GO
