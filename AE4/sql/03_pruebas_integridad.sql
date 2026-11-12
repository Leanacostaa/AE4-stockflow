/* ==========================================================================
   AE4 - ISI17BAD28V26AE4V26 - Proyecto StockFlow
   Archivo: 03_pruebas_integridad.sql
   Bateria de pruebas de las restricciones DECLARATIVAS (PK, FK, UNIQUE,
   CHECK, NOT NULL, indices unicos filtrados, cascadas). Heredada del AE2 sin
   cambios de contenido: se ejecuta sobre el juego de datos recien cargado y
   ANTES de crear los objetos programados, de modo que cada rechazo se debe
   exclusivamente a la restriccion declarativa que se pretende probar.
   --------------------------------------------------------------------------
   Cada prueba negativa debe FALLAR: si imprime "FALLO", la restriccion no
   esta cumpliendo su funcion. Las pruebas positivas se hacen dentro de una
   transaccion con ROLLBACK para no alterar el juego de datos.
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
SET XACT_ABORT OFF;
GO
PRINT '==================================================================';
PRINT ' PRUEBAS NEGATIVAS: cada INSERT/UPDATE de abajo DEBE ser rechazado';
PRINT '==================================================================';
GO

/* ---------- T01  Integridad de entidad: PK duplicada ------------------- */
BEGIN TRY
    INSERT INTO dbo.Stock (ProductoId, DepositoId, Cantidad) VALUES (1, 1, 5);
    PRINT 'FALLO T01: se acepto una PK duplicada en Stock';
END TRY BEGIN CATCH PRINT 'OK   T01 PK compuesta duplicada rechazada -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T02  Integridad referencial: FK inexistente ---------------- */
BEGIN TRY
    INSERT INTO dbo.Producto (Sku, Nombre, CategoriaId, MarcaId)
    VALUES (N'XX-TEST-001', N'Producto sin categoria', 999, 1);
    PRINT 'FALLO T02: se acepto una categoria inexistente';
END TRY BEGIN CATCH PRINT 'OK   T02 FK a Categoria inexistente rechazada -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T03  FK COMPUESTA contra la agregacion Stock --------------- */
/* El producto 2 existe y el deposito 4 existe, pero el par (2,4) NO esta en
   Stock. Con dos FK sueltas esto pasaria; con la FK compuesta no. */
BEGIN TRY
    INSERT INTO dbo.MovimientoStock (ProductoId, DepositoId, TipoMovimiento, Cantidad, EmpleadoId, Motivo)
    VALUES (2, 4, N'INGRESO', 10, 4, N'Par producto-deposito inexistente');
    PRINT 'FALLO T03: se acepto un movimiento sobre un par (producto,deposito) sin stock';
END TRY BEGIN CATCH PRINT 'OK   T03 FK compuesta a Stock rechazada -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T04  FK compuesta solapada: direccion de OTRO cliente ------ */
/* La direccion 2 existe, pero pertenece al cliente 1, no al 2. */
BEGIN TRY
    INSERT INTO dbo.Pedido (NroPedido, ClienteId, NroDireccion, EmpleadoId, SucursalId, Canal)
    VALUES (N'PED-TEST-01', 2, 2, 3, 1, N'WEB');
    PRINT 'FALLO T04: se acepto enviar al domicilio de otro cliente';
END TRY BEGIN CATCH PRINT 'OK   T04 Direccion de otro cliente rechazada -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T05  CHECK de dominio: estado fuera del conjunto ----------- */
BEGIN TRY
    UPDATE dbo.Pedido SET Estado = N'DESPACHADO' WHERE PedidoId = 5;
    PRINT 'FALLO T05: se acepto un estado fuera del conjunto permitido';
END TRY BEGIN CATCH PRINT 'OK   T05 Estado invalido rechazado -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T06  CHECK: stock negativo --------------------------------- */
BEGIN TRY
    UPDATE dbo.Stock SET Cantidad = -1 WHERE ProductoId = 1 AND DepositoId = 1;
    PRINT 'FALLO T06: se acepto stock negativo';
END TRY BEGIN CATCH PRINT 'OK   T06 Stock negativo rechazado -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T07  CHECK multicolumna: recibir mas de lo pedido ---------- */
BEGIN TRY
    UPDATE dbo.OrdenCompraDetalle SET CantidadRecibida = 999
    WHERE OrdenCompraId = 3 AND ProductoId = 9;
    PRINT 'FALLO T07: se acepto recibir mas cantidad que la pedida';
END TRY BEGIN CATCH PRINT 'OK   T07 CantidadRecibida > Cantidad rechazada -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T08  CHECK de coherencia temporal -------------------------- */
BEGIN TRY
    INSERT INTO dbo.ProductoPrecio (ProductoId, FechaDesde, FechaHasta, PrecioVenta)
    VALUES (3, '2026-10-01', '2026-09-01', 15000);
    PRINT 'FALLO T08: se acepto un periodo que cierra antes de abrir';
END TRY BEGIN CATCH PRINT 'OK   T08 FechaHasta < FechaDesde rechazada -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T09  CHECK condicional: mostrador con direccion ------------ */
BEGIN TRY
    INSERT INTO dbo.Pedido (NroPedido, ClienteId, NroDireccion, EmpleadoId, SucursalId, Canal)
    VALUES (N'PED-TEST-02', 1, 1, 3, 1, N'MOSTRADOR');
    PRINT 'FALLO T09: se acepto un pedido de mostrador con direccion de envio';
END TRY BEGIN CATCH PRINT 'OK   T09 Mostrador con direccion rechazado -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T10  CHECK condicional inverso: web sin direccion ---------- */
BEGIN TRY
    INSERT INTO dbo.Pedido (NroPedido, ClienteId, NroDireccion, EmpleadoId, SucursalId, Canal)
    VALUES (N'PED-TEST-03', 1, NULL, 3, 1, N'WEB');
    PRINT 'FALLO T10: se acepto un pedido web sin direccion de envio';
END TRY BEGIN CATCH PRINT 'OK   T10 Pedido web sin direccion rechazado -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T11  UNIQUE sobre clave alternativa ------------------------ */
BEGIN TRY
    INSERT INTO dbo.Producto (Sku, Nombre, CategoriaId, MarcaId)
    VALUES (N'MO-LOG-001', N'Mouse duplicado', 4, 2);
    PRINT 'FALLO T11: se acepto un SKU duplicado';
END TRY BEGIN CATCH PRINT 'OK   T11 SKU duplicado rechazado -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T12  UNIQUE compuesto: documento de cliente ---------------- */
BEGIN TRY
    INSERT INTO dbo.Cliente (TipoDoc, NroDoc, Nombre, Apellido)
    VALUES (N'DNI', N'32145678', N'Otro', N'Cliente');
    PRINT 'FALLO T12: se acepto un (TipoDoc, NroDoc) duplicado';
END TRY BEGIN CATCH PRINT 'OK   T12 Documento duplicado rechazado -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T13  UNIQUE sobre FK: relacion 1:1 pedido-factura ---------- */
BEGIN TRY
    INSERT INTO dbo.Factura (PedidoId, TipoComprobante, PuntoVenta, NroComprobante, Neto, AlicuotaIva)
    VALUES (1, 'B', 1, 9999, 1000, 21);
    PRINT 'FALLO T13: se acepto una segunda factura para el mismo pedido';
END TRY BEGIN CATCH PRINT 'OK   T13 Segunda factura del mismo pedido rechazada -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T14  UNIQUE de numeracion fiscal -------------------------- */
BEGIN TRY
    INSERT INTO dbo.Factura (PedidoId, TipoComprobante, PuntoVenta, NroComprobante, Neto, AlicuotaIva)
    VALUES (5, 'A', 1, 1001, 1000, 21);
    PRINT 'FALLO T14: se acepto una numeracion de comprobante repetida';
END TRY BEGIN CATCH PRINT 'OK   T14 Numeracion fiscal repetida rechazada -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T15  Indice unico filtrado: dos precios vigentes ----------- */
BEGIN TRY
    INSERT INTO dbo.ProductoPrecio (ProductoId, FechaDesde, FechaHasta, PrecioVenta)
    VALUES (3, '2026-10-01', NULL, 13000);
    PRINT 'FALLO T15: se aceptaron dos precios vigentes para el mismo producto';
END TRY BEGIN CATCH PRINT 'OK   T15 Segundo precio vigente rechazado -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T16  Indice unico filtrado: dos proveedores preferidos ----- */
BEGIN TRY
    UPDATE dbo.ProveedorProducto SET EsPreferido = 1 WHERE ProveedorId = 1 AND ProductoId = 1;
    PRINT 'FALLO T16: se aceptaron dos proveedores preferidos para el mismo producto';
END TRY BEGIN CATCH PRINT 'OK   T16 Segundo proveedor preferido rechazado -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T17  NOT NULL --------------------------------------------- */
BEGIN TRY
    INSERT INTO dbo.Cliente (TipoDoc, NroDoc, Nombre, Apellido) VALUES (N'DNI', N'11223344', NULL, N'SinNombre');
    PRINT 'FALLO T17: se acepto un nombre nulo';
END TRY BEGIN CATCH PRINT 'OK   T17 NOT NULL rechazado -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T18  Autorrelacion: empleado que se supervisa a si mismo --- */
BEGIN TRY
    UPDATE dbo.Empleado SET SupervisorId = 3 WHERE EmpleadoId = 3;
    PRINT 'FALLO T18: se acepto que un empleado sea su propio supervisor';
END TRY BEGIN CATCH PRINT 'OK   T18 Autosupervision rechazada -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T19  Restriccion de formato: CUIT no numerico -------------- */
BEGIN TRY
    INSERT INTO dbo.Proveedor (RazonSocial, Cuit) VALUES (N'Proveedor Trucho SA', '30-7112345');
    PRINT 'FALLO T19: se acepto un CUIT con caracteres no numericos';
END TRY BEGIN CATCH PRINT 'OK   T19 CUIT invalido rechazado -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T20  Borrado restringido: padre con hijos ------------------ */
BEGIN TRY
    DELETE FROM dbo.Producto WHERE ProductoId = 1;
    PRINT 'FALLO T20: se borro un producto con stock y ventas asociadas';
END TRY BEGIN CATCH PRINT 'OK   T20 DELETE restringido por FK -> ' + ERROR_MESSAGE(); END CATCH
GO

/* ---------- T21  Alicuota de IVA fuera de las vigentes ----------------- */
BEGIN TRY
    INSERT INTO dbo.Factura (PedidoId, TipoComprobante, PuntoVenta, NroComprobante, Neto, AlicuotaIva)
    VALUES (5, 'C', 1, 5001, 58000, 15);
    PRINT 'FALLO T21: se acepto una alicuota de IVA inexistente';
END TRY BEGIN CATCH PRINT 'OK   T21 Alicuota invalida rechazada -> ' + ERROR_MESSAGE(); END CATCH
GO

PRINT '';
PRINT '==================================================================';
PRINT ' PRUEBAS POSITIVAS: operaciones validas (se deshacen con ROLLBACK)';
PRINT '==================================================================';
GO

/* ---------- T22  Borrado en cascada de un pedido y su detalle ---------- */
BEGIN TRANSACTION;
    DECLARE @antes INT = (SELECT COUNT(*) FROM dbo.PedidoDetalle WHERE PedidoId = 5);
    DELETE FROM dbo.Pedido WHERE PedidoId = 5;
    DECLARE @despues INT = (SELECT COUNT(*) FROM dbo.PedidoDetalle WHERE PedidoId = 5);
    PRINT CONCAT('T22 Cascada Pedido->PedidoDetalle: renglones antes=', @antes, ' despues=', @despues,
                 CASE WHEN @antes > 0 AND @despues = 0 THEN '  OK' ELSE '  FALLO' END);
ROLLBACK TRANSACTION;
GO

/* ---------- T23  Borrado en cascada de cliente -> telefonos y direcciones */
/* Nota: PRINT no admite subconsultas (Msg 1046), por eso los conteos se
   guardan antes en variables, igual que en T22. */
BEGIN TRANSACTION;
    DECLARE @telAntes INT = (SELECT COUNT(*) FROM dbo.ClienteTelefono  WHERE ClienteId = 5);
    DECLARE @dirAntes INT = (SELECT COUNT(*) FROM dbo.ClienteDireccion WHERE ClienteId = 5);
    DELETE FROM dbo.Pago    WHERE FacturaId IN (SELECT f.FacturaId FROM dbo.Factura f JOIN dbo.Pedido p ON p.PedidoId = f.PedidoId WHERE p.ClienteId = 5);
    DELETE FROM dbo.Factura WHERE PedidoId  IN (SELECT PedidoId FROM dbo.Pedido WHERE ClienteId = 5);
    DELETE FROM dbo.Pedido  WHERE ClienteId = 5;
    DELETE FROM dbo.Cliente WHERE ClienteId = 5;
    DECLARE @telDespues INT = (SELECT COUNT(*) FROM dbo.ClienteTelefono  WHERE ClienteId = 5);
    DECLARE @dirDespues INT = (SELECT COUNT(*) FROM dbo.ClienteDireccion WHERE ClienteId = 5);
    PRINT CONCAT('T23 Cascada Cliente->Telefonos/Direcciones: telefonos ', @telAntes, '->', @telDespues,
                 ', direcciones ', @dirAntes, '->', @dirDespues,
                 CASE WHEN @telAntes > 0 AND @dirAntes > 0 AND @telDespues = 0 AND @dirDespues = 0
                      THEN '  OK' ELSE '  FALLO' END);
ROLLBACK TRANSACTION;
GO

/* ---------- T24  Columna calculada PERSISTED se mantiene sola ---------- */
BEGIN TRANSACTION;
    UPDATE dbo.Factura SET Neto = 100000, AlicuotaIva = 10.5 WHERE FacturaId = 4;
    SELECT 'T24 columna calculada' AS Prueba, Neto, AlicuotaIva, TotalFactura,
           Esperado = CAST(100000 * 1.105 AS DECIMAL(16,4)),
           Resultado = CASE WHEN TotalFactura = CAST(100000 * 1.105 AS DECIMAL(16,4)) THEN 'OK' ELSE 'FALLO' END
    FROM dbo.Factura WHERE FacturaId = 4;
ROLLBACK TRANSACTION;
GO

/* ---------- T25  Alta valida completa de una venta --------------------- */
BEGIN TRANSACTION;
    INSERT INTO dbo.Pedido (NroPedido, ClienteId, NroDireccion, EmpleadoId, SucursalId, Canal, Estado)
    VALUES (N'PED-TEST-OK', 1, 2, 3, 1, N'WEB', N'CONFIRMADO');
    DECLARE @ped INT = SCOPE_IDENTITY();
    INSERT INTO dbo.PedidoDetalle (PedidoId, ProductoId, Cantidad, PrecioUnitarioHistorico, DescuentoPct)
    VALUES (@ped, 6, 2, 112000, 0), (@ped, 3, 1, 11500, 0);
    INSERT INTO dbo.Factura (PedidoId, TipoComprobante, PuntoVenta, NroComprobante, Neto, AlicuotaIva)
    VALUES (@ped, 'B', 1, 7777, (SELECT Total FROM dbo.vw_PedidoTotal WHERE PedidoId = @ped), 21);
    SELECT 'T25 alta completa' AS Prueba, v.PedidoId, v.Total AS NetoCalculado, f.TotalFactura
    FROM dbo.vw_PedidoTotal v JOIN dbo.Factura f ON f.PedidoId = v.PedidoId
    WHERE v.PedidoId = @ped;
ROLLBACK TRANSACTION;
GO


/* ---------- T26  Varios clientes sin email (indice unico filtrado) --------- */
/* Con UNIQUE comun esto fallaria: SQL Server admite un solo NULL. */
BEGIN TRANSACTION;
    INSERT INTO dbo.Cliente (TipoDoc, NroDoc, Nombre, Apellido, Email)
    VALUES (N'DNI', N'45111222', N'Ana',   N'Benitez', NULL),
           (N'DNI', N'45333444', N'Bruno', N'Sanchez', NULL);
    DECLARE @sinEmail INT = (SELECT COUNT(*) FROM dbo.Cliente WHERE Email IS NULL);
    PRINT CONCAT('T26 Dos clientes nuevos sin email aceptados: ', @sinEmail,
                 ' clientes sin email en total',
                 CASE WHEN @sinEmail >= 3 THEN '  OK' ELSE '  FALLO' END);
ROLLBACK TRANSACTION;
GO

PRINT '';
PRINT '==================================================================';
PRINT ' CONSULTAS DE VERIFICACION DEL MODELO';
PRINT '==================================================================';
GO

/* V1 - Stock total por producto (atributo derivado StockTotal) */
SELECT 'V1 StockTotal por producto' AS Consulta, * FROM dbo.vw_ProductoStock ORDER BY Sku;

/* V2 - Productos por debajo del minimo en algun deposito */
SELECT 'V2 Bajo minimo' AS Consulta, * FROM dbo.vw_StockBajoMinimo ORDER BY Sku;

/* V3 - Saldo pendiente por factura (derivado sobre Pago) */
SELECT 'V3 Saldos' AS Consulta, s.*, p.NroPedido, c.Apellido, c.Nombre
FROM dbo.vw_FacturaSaldo s
JOIN dbo.Factura f ON f.FacturaId = s.FacturaId
JOIN dbo.Pedido  p ON p.PedidoId  = f.PedidoId
JOIN dbo.Cliente c ON c.ClienteId = p.ClienteId
ORDER BY s.FacturaId;

/* V4 - Precio vigente vs precio efectivamente cobrado: justifica por que
       PrecioUnitarioHistorico NO es redundante */
SELECT 'V4 Precio vigente vs cobrado' AS Consulta,
       p.Sku, pd.PedidoId, pd.PrecioUnitarioHistorico, pv.PrecioVenta AS PrecioVigenteHoy,
       Diferencia = pd.PrecioUnitarioHistorico - pv.PrecioVenta
FROM dbo.PedidoDetalle pd
JOIN dbo.Producto p ON p.ProductoId = pd.ProductoId
LEFT JOIN dbo.vw_ProductoPrecioVigente pv ON pv.ProductoId = pd.ProductoId
ORDER BY pd.PedidoId, p.Sku;

/* V5 - Jerarquia de categorias (autorrelacion) */
WITH Arbol AS (
    SELECT CategoriaId, Nombre, CategoriaPadreId, Nivel = 0,
           Ruta = CAST(Nombre AS NVARCHAR(400))
    FROM dbo.Categoria WHERE CategoriaPadreId IS NULL
    UNION ALL
    SELECT c.CategoriaId, c.Nombre, c.CategoriaPadreId, a.Nivel + 1,
           CAST(a.Ruta + N' > ' + c.Nombre AS NVARCHAR(400))
    FROM dbo.Categoria c JOIN Arbol a ON a.CategoriaId = c.CategoriaPadreId
)
SELECT 'V5 Jerarquia de categorias' AS Consulta, Nivel, Ruta FROM Arbol ORDER BY Ruta;

/* V6 - Kardex: movimientos de un producto en un deposito */
SELECT 'V6 Kardex' AS Consulta, m.FechaHora, p.Sku, d.Nombre AS Deposito,
       m.TipoMovimiento, m.Cantidad, e.Apellido AS Responsable, m.Motivo
FROM dbo.MovimientoStock m
JOIN dbo.Producto p ON p.ProductoId = m.ProductoId
JOIN dbo.Deposito d ON d.DepositoId = m.DepositoId
JOIN dbo.Empleado e ON e.EmpleadoId = m.EmpleadoId
ORDER BY m.FechaHora;

/* V7 - Comparativa de proveedores para un mismo producto (justifica el N:M) */
SELECT 'V7 Proveedores por producto' AS Consulta,
       p.Sku, p.Nombre, pr.RazonSocial, pp.PrecioCompra, pp.PlazoEntregaDias, pp.EsPreferido
FROM dbo.ProveedorProducto pp
JOIN dbo.Producto  p  ON p.ProductoId  = pp.ProductoId
JOIN dbo.Proveedor pr ON pr.ProveedorId = pp.ProveedorId
WHERE pp.ProductoId IN (SELECT ProductoId FROM dbo.ProveedorProducto GROUP BY ProductoId HAVING COUNT(*) > 1)
ORDER BY p.Sku, pp.PrecioCompra;

/* V8 - Inventario del metamodelo: restricciones efectivamente creadas */
SELECT 'V8 Restricciones creadas' AS Consulta, Tipo, Cantidad FROM (
    SELECT Tipo = 'PRIMARY KEY', Cantidad = COUNT(*) FROM sys.key_constraints WHERE type = 'PK'
    UNION ALL SELECT 'UNIQUE',        COUNT(*) FROM sys.key_constraints   WHERE type = 'UQ'
    UNION ALL SELECT 'FOREIGN KEY',   COUNT(*) FROM sys.foreign_keys
    UNION ALL SELECT 'CHECK',         COUNT(*) FROM sys.check_constraints
    UNION ALL SELECT 'DEFAULT',       COUNT(*) FROM sys.default_constraints
    UNION ALL SELECT 'INDICE UNICO FILTRADO', COUNT(*) FROM sys.indexes WHERE is_unique = 1 AND has_filter = 1
    UNION ALL SELECT 'TABLAS',        COUNT(*) FROM sys.tables
) AS x ORDER BY Tipo;
GO

PRINT 'Pruebas finalizadas. Revisar que ninguna linea empiece con FALLO.';
GO
