/* ==========================================================================
   AE4 - ISI17BAD28V26AE4V26 - Proyecto StockFlow
   Archivo: 06_manipulacion_dml.sql  -- Manipulacion de datos (SQL DML)
   Ejecutar DESPUES de 05_vistas.sql
   --------------------------------------------------------------------------
   Operaciones de la puesta en marcha del sistema. A diferencia de las
   pruebas, estos cambios SE CONFIRMAN y forman el estado sobre el que se
   ejecutan las consultas (07) y las pruebas de objetos programados (08).
     M1  INSERT, UPDATE y DELETE directos sobre tablas maestras
     M2  Transaccion explicita: recepcion de una orden de compra
     M3  Transaccion explicita: transferencia entre depositos
     M4  Cambios de precio con historial
     M5  Ventas completas a traves de los procedimientos almacenados
     M6  Cierre de pedidos heredados del AE2
   Los identificadores generados (pedidos, facturas) se capturan en
   variables: no se asumen valores IDENTITY, porque las pruebas de 03
   consumen numeros al ser rechazadas o revertidas.
   ========================================================================== */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE StockFlow;
GO
SET NOCOUNT ON;
GO

/* ==========================================================================
   M1. INSERT / UPDATE / DELETE directos
   ========================================================================== */
PRINT '--- M1.1 INSERT: datos de contacto del cliente 6 (antes sin telefono ni direccion) ---';
INSERT INTO dbo.ClienteTelefono (ClienteId, NroTelefono, Telefono, Tipo)
VALUES (6, 1, N'0376-154334455', N'WHATSAPP');
INSERT INTO dbo.ClienteDireccion (ClienteId, NroDireccion, Calle, Numero, Ciudad, Provincia, CodigoPostal, EsPrincipal)
VALUES (6, 1, N'Junin', N'1820', N'Posadas', N'Misiones', N'N3300', 1);
GO

PRINT '--- M1.2 UPDATE: el cliente 4 informa su email; se eleva el minimo del teclado en el salon ---';
UPDATE dbo.Cliente SET Email = N'nparedes@mail.com' WHERE ClienteId = 4 AND Email IS NULL;
/* Cambiar StockMinimo esta permitido; cambiar Cantidad directamente no (T2). */
UPDATE dbo.Stock SET StockMinimo = 12, StockMaximo = 40
WHERE ProductoId = 4 AND DepositoId = 2;
GO

PRINT '--- M1.3 DELETE: telefono laboral dado de baja y acuerdo de suministro alternativo vencido ---';
DELETE FROM dbo.ClienteTelefono WHERE ClienteId = 1 AND NroTelefono = 2;
DELETE FROM dbo.ProveedorProducto WHERE ProveedorId = 3 AND ProductoId = 12 AND EsPreferido = 0;
GO

/* ==========================================================================
   M2. Transaccion explicita: recepcion de la OC-2026-0003 en Deposito Obera
   Tres tablas deben cambiar juntas: el kardex (T1 suma el stock), las
   cantidades recibidas y el estado de la orden. Si algo falla, nada cambia.
   ========================================================================== */
PRINT '--- M2 Recepcion de OC-2026-0003 (transaccion explicita) ---';
SELECT 'M2 antes' AS Momento, ProductoId, DepositoId, Cantidad
FROM dbo.Stock WHERE DepositoId = 4 AND ProductoId IN (9, 10);

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Oc INT = (SELECT OrdenCompraId FROM dbo.OrdenCompra WHERE NroOrden = N'OC-2026-0003');

    INSERT INTO dbo.MovimientoStock (ProductoId, DepositoId, TipoMovimiento, Cantidad, EmpleadoId,
                                     Motivo, DocumentoTipo, DocumentoId)
    SELECT d.ProductoId, oc.DepositoId, 'INGRESO', d.Cantidad, 6, N'Recepcion OC-2026-0003', 'OC', oc.OrdenCompraId
    FROM dbo.OrdenCompraDetalle AS d
    JOIN dbo.OrdenCompra AS oc ON oc.OrdenCompraId = d.OrdenCompraId
    WHERE d.OrdenCompraId = @Oc;

    UPDATE dbo.OrdenCompraDetalle SET CantidadRecibida = Cantidad WHERE OrdenCompraId = @Oc;
    UPDATE dbo.OrdenCompra SET Estado = 'RECIBIDA' WHERE OrdenCompraId = @Oc;

    COMMIT TRANSACTION;
    PRINT 'M2 COMMIT: orden recibida y stock actualizado por el trigger de kardex.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'M2 ROLLBACK: ' + ERROR_MESSAGE();
END CATCH;

SELECT 'M2 despues' AS Momento, ProductoId, DepositoId, Cantidad
FROM dbo.Stock WHERE DepositoId = 4 AND ProductoId IN (9, 10);
GO

/* ==========================================================================
   M3. Transaccion explicita: transferencia de 10 teclados K380
   Deposito Central (1) -> Deposito Salon CC (2), que estaba bajo minimo.
   Salida (TRANSFER) y entrada (INGRESO) son dos filas de kardex que deben
   registrarse juntas: una sin la otra haria desaparecer o duplicar stock.
   ========================================================================== */
PRINT '--- M3 Transferencia entre depositos (transaccion explicita) ---';
SELECT 'M3 antes' AS Momento, Deposito, Sku, Cantidad, StockMinimo, EstadoStock
FROM dbo.vw_StockPorDeposito WHERE ProductoId = 4;

BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.MovimientoStock (ProductoId, DepositoId, TipoMovimiento, Cantidad, EmpleadoId, Motivo)
    VALUES (4, 1, 'TRANSFER', 10, 4, N'Reposicion de salon (salida)'),
           (4, 2, 'INGRESO',  10, 4, N'Reposicion de salon (entrada)');
    COMMIT TRANSACTION;
    PRINT 'M3 COMMIT: transferencia registrada.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'M3 ROLLBACK: ' + ERROR_MESSAGE();
END CATCH;

SELECT 'M3 despues' AS Momento, Deposito, Sku, Cantidad, StockMinimo, EstadoStock
FROM dbo.vw_StockPorDeposito WHERE ProductoId = 4;
GO

/* ==========================================================================
   M4. Cambio de precios (conserva el historial; T5 lo protege)
   El mouse M170 (3) se vendio en septiembre a 11.500 y el monitor (5) a
   198.000; desde hoy valen 12.900 y 214.000. Los renglones ya vendidos
   conservan su precio historico (RN06), como muestra la consulta C14.
   ========================================================================== */
PRINT '--- M4 Actualizacion de precios con historial ---';
EXEC dbo.sp_ActualizarPrecioProducto @ProductoId = 3, @PrecioVenta = 12900, @PrecioCosto = 8100;
EXEC dbo.sp_ActualizarPrecioProducto @ProductoId = 5, @PrecioVenta = 214000;

SELECT 'M4 historial' AS Consulta, ProductoId, FechaDesde, FechaHasta, PrecioVenta, PrecioCosto
FROM dbo.ProductoPrecio WHERE ProductoId IN (3, 5) ORDER BY ProductoId, FechaDesde;
GO

/* ==========================================================================
   M5. Ventas completas mediante procedimientos almacenados
   ========================================================================== */
PRINT '--- M5.1 Venta WEB: pedido -> factura B -> pago total -> entrega ---';
DECLARE @PedidoId INT, @NroPedido NVARCHAR(16), @FacturaId INT, @Total DECIMAL(16,2);

EXEC dbo.sp_RegistrarPedido
     @ClienteId = 1, @EmpleadoId = 3, @SucursalId = 1, @DepositoId = 1,
     @Canal = N'WEB', @NroDireccion = 1,
     @ItemsJson = N'[{"ProductoId":6,"Cantidad":3},{"ProductoId":3,"Cantidad":2}]',
     @PedidoId = @PedidoId OUTPUT, @NroPedido = @NroPedido OUTPUT;

EXEC dbo.sp_FacturarPedido @PedidoId = @PedidoId, @FacturaId = @FacturaId OUTPUT;
SELECT @Total = ROUND(TotalFactura, 2) FROM dbo.Factura WHERE FacturaId = @FacturaId;
EXEC dbo.sp_RegistrarPago @FacturaId = @FacturaId, @Monto = @Total, @MedioPagoId = 2, @Referencia = N'TRF-910220';
UPDATE dbo.Pedido SET Estado = 'ENTREGADO' WHERE PedidoId = @PedidoId;

SELECT 'M5.1' AS Caso, @NroPedido AS NroPedido, p.Estado, f.TipoComprobante, f.NroComprobante,
       f.Neto, f.TotalFactura, s.Cobrado, s.SaldoPendiente
FROM dbo.Pedido p JOIN dbo.Factura f ON f.PedidoId = p.PedidoId
JOIN dbo.vw_FacturaSaldo s ON s.FacturaId = f.FacturaId
WHERE p.PedidoId = @PedidoId;
GO

PRINT '--- M5.2 Venta TELEFONO a empresa (factura A automatica) con cobranza parcial ---';
DECLARE @PedidoId INT, @NroPedido NVARCHAR(16), @FacturaId INT, @Total DECIMAL(16,2);

EXEC dbo.sp_RegistrarPedido
     @ClienteId = 7, @EmpleadoId = 5, @SucursalId = 2, @DepositoId = 3,
     @Canal = N'TELEFONO', @NroDireccion = 1,
     @ItemsJson = N'[{"ProductoId":1,"Cantidad":1},{"ProductoId":3,"Cantidad":5,"DescuentoPct":10}]',
     @PedidoId = @PedidoId OUTPUT, @NroPedido = @NroPedido OUTPUT;

EXEC dbo.sp_FacturarPedido @PedidoId = @PedidoId, @FacturaId = @FacturaId OUTPUT;
SELECT @Total = ROUND(TotalFactura, 2) FROM dbo.Factura WHERE FacturaId = @FacturaId;
DECLARE @Anticipo DECIMAL(14,2) = ROUND(@Total * 0.5, 2);
EXEC dbo.sp_RegistrarPago @FacturaId = @FacturaId, @Monto = @Anticipo, @MedioPagoId = 2, @Referencia = N'TRF-910377';

SELECT 'M5.2' AS Caso, @NroPedido AS NroPedido, pd.ProductoId, pd.Cantidad,
       pd.PrecioUnitarioHistorico, pd.DescuentoPct, f.TipoComprobante, s.SaldoPendiente
FROM dbo.PedidoDetalle pd
JOIN dbo.Factura f ON f.PedidoId = pd.PedidoId
JOIN dbo.vw_FacturaSaldo s ON s.FacturaId = f.FacturaId
WHERE pd.PedidoId = @PedidoId;
GO

PRINT '--- M5.3 Venta de MOSTRADOR en Obera: pago en efectivo y entrega ---';
DECLARE @PedidoId INT, @NroPedido NVARCHAR(16), @FacturaId INT, @Total DECIMAL(16,2);

EXEC dbo.sp_RegistrarPedido
     @ClienteId = 2, @EmpleadoId = 7, @SucursalId = 3, @DepositoId = 4,
     @Canal = N'MOSTRADOR',
     @ItemsJson = N'[{"ProductoId":5,"Cantidad":3},{"ProductoId":10,"Cantidad":4,"DescuentoPct":5}]',
     @PedidoId = @PedidoId OUTPUT, @NroPedido = @NroPedido OUTPUT;

EXEC dbo.sp_FacturarPedido @PedidoId = @PedidoId, @PuntoVenta = 3, @FacturaId = @FacturaId OUTPUT;
SELECT @Total = ROUND(TotalFactura, 2) FROM dbo.Factura WHERE FacturaId = @FacturaId;
EXEC dbo.sp_RegistrarPago @FacturaId = @FacturaId, @Monto = @Total, @MedioPagoId = 1;
UPDATE dbo.Pedido SET Estado = 'ENTREGADO' WHERE PedidoId = @PedidoId;

SELECT 'M5.3' AS Caso, @NroPedido AS NroPedido, p.Estado, f.PuntoVenta, f.NroComprobante, f.TotalFactura
FROM dbo.Pedido p JOIN dbo.Factura f ON f.PedidoId = p.PedidoId WHERE p.PedidoId = @PedidoId;
GO

PRINT '--- M5.4 Pedido TELEFONO que el cliente desiste: anulacion con reversion de stock ---';
DECLARE @PedidoId INT, @NroPedido NVARCHAR(16);

SELECT 'M5.4 stock antes' AS Momento, ProductoId, Cantidad
FROM dbo.Stock WHERE DepositoId = 1 AND ProductoId IN (2, 7, 8);

EXEC dbo.sp_RegistrarPedido
     @ClienteId = 3, @EmpleadoId = 3, @SucursalId = 1, @DepositoId = 1,
     @Canal = N'TELEFONO', @NroDireccion = 1,
     @ItemsJson = N'[{"ProductoId":2,"Cantidad":1},{"ProductoId":8,"Cantidad":4},{"ProductoId":7,"Cantidad":10}]',
     @PedidoId = @PedidoId OUTPUT, @NroPedido = @NroPedido OUTPUT;

SELECT 'M5.4 stock con pedido' AS Momento, ProductoId, Cantidad
FROM dbo.Stock WHERE DepositoId = 1 AND ProductoId IN (2, 7, 8);

EXEC dbo.sp_CancelarPedido @PedidoId = @PedidoId, @EmpleadoId = 3, @Motivo = N'El cliente desiste de la compra';

SELECT 'M5.4 stock despues de anular' AS Momento, ProductoId, Cantidad
FROM dbo.Stock WHERE DepositoId = 1 AND ProductoId IN (2, 7, 8);
GO

/* ==========================================================================
   M6. Cierre de pedidos heredados del AE2
   PED-2026-0005 (PENDIENTE, mostrador) se confirma, se factura y se cobra
   parcialmente; PED-2026-0004 (CONFIRMADO y facturado) recibe un pago
   parcial y se entrega.
   ========================================================================== */
PRINT '--- M6 Cierre de pedidos heredados ---';
DECLARE @P5 INT = (SELECT PedidoId FROM dbo.Pedido WHERE NroPedido = N'PED-2026-0005');
DECLARE @P4 INT = (SELECT PedidoId FROM dbo.Pedido WHERE NroPedido = N'PED-2026-0004');
DECLARE @F5 INT, @F4 INT;

UPDATE dbo.Pedido SET Estado = 'CONFIRMADO' WHERE PedidoId = @P5;
EXEC dbo.sp_FacturarPedido @PedidoId = @P5, @PuntoVenta = 1, @FacturaId = @F5 OUTPUT;
EXEC dbo.sp_RegistrarPago @FacturaId = @F5, @Monto = 30000, @MedioPagoId = 1;

SET @F4 = (SELECT FacturaId FROM dbo.Factura WHERE PedidoId = @P4);
EXEC dbo.sp_RegistrarPago @FacturaId = @F4, @Monto = 200000, @MedioPagoId = 5, @Referencia = N'CC-0042';
UPDATE dbo.Pedido SET Estado = 'ENTREGADO' WHERE PedidoId = @P4;
GO

/* ==========================================================================
   Estado resultante
   ========================================================================== */
SELECT 'Pedidos' AS Resumen, p.NroPedido, p.Canal, p.Estado, c.Apellido AS Cliente,
       t.Total AS NetoPedido, f.TipoComprobante, f.NroComprobante, s.SaldoPendiente
FROM dbo.Pedido p
JOIN dbo.Cliente c ON c.ClienteId = p.ClienteId
LEFT JOIN dbo.vw_PedidoTotal t ON t.PedidoId = p.PedidoId
LEFT JOIN dbo.Factura f ON f.PedidoId = p.PedidoId
LEFT JOIN dbo.vw_FacturaSaldo s ON s.FacturaId = f.FacturaId
ORDER BY p.NroPedido;

SELECT 'Historial de estados' AS Resumen, p.NroPedido, h.EstadoAnterior, h.EstadoNuevo, h.Usuario
FROM dbo.PedidoEstadoHistorial h JOIN dbo.Pedido p ON p.PedidoId = h.PedidoId
ORDER BY h.HistorialId;
GO

PRINT 'Manipulacion de datos finalizada.';
GO
