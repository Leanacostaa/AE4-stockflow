/* ==========================================================================
   AE4 - ISI17BAD28V26AE4V26 - Proyecto StockFlow
   Archivo: 08_pruebas_programacion.sql
   Pruebas de funciones, procedimientos almacenados y triggers.
   Ejecutar DESPUES de 07_consultas.sql
   --------------------------------------------------------------------------
   Cada prueba registra en #Resultado el codigo de error ESPERADO y el
   OBTENIDO (0 = la operacion fue aceptada). Una prueba negativa solo es OK
   si falla con el error de la regla que se pretende probar, no con
   cualquier error: es la leccion de la prueba T12 del AE2.
   Las pruebas positivas que modifican datos se ejecutan dentro de una
   transaccion que se revierte, para no alterar el estado de la base.
   ========================================================================== */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE StockFlow;
GO
SET NOCOUNT ON;
SET XACT_ABORT OFF;
GO

IF OBJECT_ID('tempdb..#Resultado') IS NOT NULL DROP TABLE #Resultado;
CREATE TABLE #Resultado (
    Id          INT IDENTITY(1,1) PRIMARY KEY,
    Prueba      VARCHAR(8)     NOT NULL,
    Objeto      VARCHAR(40)    NOT NULL,
    Descripcion NVARCHAR(200)  NOT NULL,
    Esperado    INT            NOT NULL,
    Obtenido    INT            NOT NULL,
    Mensaje     NVARCHAR(4000) NULL,
    Resultado   AS (CASE WHEN Esperado = Obtenido THEN 'OK' ELSE 'FALLO' END)
);
GO

/* ==========================================================================
   F. FUNCIONES
   ========================================================================== */
DECLARE @v1 DECIMAL(12,2) = dbo.fn_PrecioVigente(1, '2026-03-15'),
        @v2 DECIMAL(12,2) = dbo.fn_PrecioVigente(1, '2026-07-01'),
        @v3 DECIMAL(12,2) = dbo.fn_PrecioVigente(14, NULL);
INSERT #Resultado VALUES ('F1-01', 'fn_PrecioVigente', N'Precio del producto 1 en dos periodos distintos y de un producto sin precio',
    0, CASE WHEN @v1 = 890000 AND @v2 = 1050000 AND @v3 IS NULL THEN 0 ELSE -1 END,
    CONCAT('15/03: ', @v1, '; 01/07: ', @v2, '; producto 14: ', ISNULL(CONVERT(VARCHAR(20), @v3), 'NULL')));
GO

DECLARE @s1 DECIMAL(12,3) = dbo.fn_StockDisponible(3, NULL),
        @s2 DECIMAL(12,3) = (SELECT SUM(Cantidad) FROM dbo.Stock WHERE ProductoId = 3),
        @s3 DECIMAL(12,3) = dbo.fn_StockDisponible(2, 4);
INSERT #Resultado VALUES ('F2-01', 'fn_StockDisponible', N'Stock total coincide con SUM(Stock) y par inexistente devuelve 0 (no NULL)',
    0, CASE WHEN @s1 = @s2 AND @s3 = 0 THEN 0 ELSE -1 END,
    CONCAT('total producto 3: ', @s1, '; SUM directo: ', @s2, '; producto 2 en deposito 4: ', @s3));
GO

DECLARE @c1 DECIMAL(16,2) = dbo.fn_TotalCompradoCliente(1),
        @c3 DECIMAL(16,2) = dbo.fn_TotalCompradoCliente(3),
        @c6 DECIMAL(16,2) = dbo.fn_TotalCompradoCliente(6);
INSERT #Resultado VALUES ('F3-01', 'fn_TotalCompradoCliente', N'Suma pedidos no cancelados; cliente sin pedidos devuelve 0',
    0, CASE WHEN @c1 = 2700900.00 AND @c3 = 962300.00 AND @c6 = 0 THEN 0 ELSE -1 END,
    CONCAT('cliente 1: ', @c1, '; cliente 3 (con un pedido cancelado): ', @c3, '; cliente 6: ', @c6));
GO

/* ==========================================================================
   P1. sp_RegistrarPedido - controles de parametros
   ========================================================================== */
DECLARE @P VARCHAR(8) = 'P1-01', @O VARCHAR(40) = 'sp_RegistrarPedido', @D NVARCHAR(200) = N'Cliente inexistente', @E INT = 50001;
BEGIN TRY
    EXEC dbo.sp_RegistrarPedido @ClienteId = 999, @EmpleadoId = 3, @SucursalId = 1, @DepositoId = 1,
         @Canal = N'MOSTRADOR', @ItemsJson = N'[{"ProductoId":3,"Cantidad":1}]';
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'P1-02', @O VARCHAR(40) = 'sp_RegistrarPedido', @D NVARCHAR(200) = N'Empleado de deposito intenta registrar una venta', @E INT = 50002;
BEGIN TRY
    EXEC dbo.sp_RegistrarPedido @ClienteId = 1, @EmpleadoId = 4, @SucursalId = 1, @DepositoId = 1,
         @Canal = N'MOSTRADOR', @ItemsJson = N'[{"ProductoId":3,"Cantidad":1}]';
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'P1-03', @O VARCHAR(40) = 'sp_RegistrarPedido', @D NVARCHAR(200) = N'Vendedor de Sucursal Norte vende en Casa Central', @E INT = 50003;
BEGIN TRY
    EXEC dbo.sp_RegistrarPedido @ClienteId = 1, @EmpleadoId = 5, @SucursalId = 1, @DepositoId = 1,
         @Canal = N'MOSTRADOR', @ItemsJson = N'[{"ProductoId":3,"Cantidad":1}]';
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'P1-04', @O VARCHAR(40) = 'sp_RegistrarPedido', @D NVARCHAR(200) = N'Despacho desde un deposito de otra sucursal', @E INT = 50004;
BEGIN TRY
    EXEC dbo.sp_RegistrarPedido @ClienteId = 1, @EmpleadoId = 3, @SucursalId = 1, @DepositoId = 4,
         @Canal = N'MOSTRADOR', @ItemsJson = N'[{"ProductoId":3,"Cantidad":1}]';
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'P1-05', @O VARCHAR(40) = 'sp_RegistrarPedido', @D NVARCHAR(200) = N'Pedido WEB con la direccion de otro cliente', @E INT = 50005;
BEGIN TRY
    EXEC dbo.sp_RegistrarPedido @ClienteId = 2, @EmpleadoId = 3, @SucursalId = 1, @DepositoId = 1,
         @Canal = N'WEB', @NroDireccion = 2, @ItemsJson = N'[{"ProductoId":3,"Cantidad":1}]';
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'P1-06', @O VARCHAR(40) = 'sp_RegistrarPedido', @D NVARCHAR(200) = N'Detalle del pedido vacio', @E INT = 50006;
BEGIN TRY
    EXEC dbo.sp_RegistrarPedido @ClienteId = 1, @EmpleadoId = 3, @SucursalId = 1, @DepositoId = 1,
         @Canal = N'MOSTRADOR', @ItemsJson = N'[]';
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'P1-07', @O VARCHAR(40) = 'sp_RegistrarPedido', @D NVARCHAR(200) = N'Renglon con cantidad cero', @E INT = 50007;
BEGIN TRY
    EXEC dbo.sp_RegistrarPedido @ClienteId = 1, @EmpleadoId = 3, @SucursalId = 1, @DepositoId = 1,
         @Canal = N'MOSTRADOR', @ItemsJson = N'[{"ProductoId":3,"Cantidad":0}]';
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'P1-08', @O VARCHAR(40) = 'sp_RegistrarPedido', @D NVARCHAR(200) = N'Producto repetido en el mismo pedido', @E INT = 50007;
BEGIN TRY
    EXEC dbo.sp_RegistrarPedido @ClienteId = 1, @EmpleadoId = 3, @SucursalId = 1, @DepositoId = 1,
         @Canal = N'MOSTRADOR', @ItemsJson = N'[{"ProductoId":3,"Cantidad":1},{"ProductoId":3,"Cantidad":2}]';
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'P1-09', @O VARCHAR(40) = 'sp_RegistrarPedido', @D NVARCHAR(200) = N'Venta de un producto discontinuado', @E INT = 50008;
BEGIN TRY
    EXEC dbo.sp_RegistrarPedido @ClienteId = 1, @EmpleadoId = 3, @SucursalId = 1, @DepositoId = 1,
         @Canal = N'MOSTRADOR', @ItemsJson = N'[{"ProductoId":13,"Cantidad":1}]';
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'P1-10', @O VARCHAR(40) = 'sp_RegistrarPedido', @D NVARCHAR(200) = N'Venta de un producto sin precio vigente', @E INT = 50009;
BEGIN TRY
    EXEC dbo.sp_RegistrarPedido @ClienteId = 1, @EmpleadoId = 3, @SucursalId = 1, @DepositoId = 1,
         @Canal = N'MOSTRADOR', @ItemsJson = N'[{"ProductoId":14,"Cantidad":1}]';
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

/* P1-11 y P1-12: atomicidad. El primer renglon es valido y el segundo no
   tiene stock suficiente: la transaccion debe revertirse completa. */
DECLARE @PedAntes INT = (SELECT COUNT(*) FROM dbo.Pedido),
        @StockAntes DECIMAL(12,3) = dbo.fn_StockDisponible(3, 1),
        @MovAntes INT = (SELECT COUNT(*) FROM dbo.MovimientoStock);
DECLARE @P VARCHAR(8) = 'P1-11', @O VARCHAR(40) = 'sp_RegistrarPedido', @D NVARCHAR(200) = N'Stock insuficiente en el segundo renglon', @E INT = 50010;
BEGIN TRY
    EXEC dbo.sp_RegistrarPedido @ClienteId = 1, @EmpleadoId = 3, @SucursalId = 1, @DepositoId = 1,
         @Canal = N'MOSTRADOR', @ItemsJson = N'[{"ProductoId":3,"Cantidad":1},{"ProductoId":9,"Cantidad":50}]';
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
DECLARE @PedDesp INT = (SELECT COUNT(*) FROM dbo.Pedido),
        @StockDesp DECIMAL(12,3) = dbo.fn_StockDisponible(3, 1),
        @MovDesp INT = (SELECT COUNT(*) FROM dbo.MovimientoStock);
INSERT #Resultado VALUES ('P1-12', 'sp_RegistrarPedido', N'Atomicidad: tras el rechazo no quedan pedido, renglones ni movimientos parciales',
    0, CASE WHEN @PedAntes = @PedDesp AND @StockAntes = @StockDesp AND @MovAntes = @MovDesp THEN 0 ELSE -1 END,
    CONCAT('pedidos ', @PedAntes, '->', @PedDesp, '; stock mouse ', @StockAntes, '->', @StockDesp,
           '; movimientos ', @MovAntes, '->', @MovDesp));
GO

/* P1-13: caso valido completo, verificado y revertido. */
DECLARE @Id INT, @Nro NVARCHAR(16), @Antes DECIMAL(12,3) = dbo.fn_StockDisponible(10, 4),
        @Despues DECIMAL(12,3), @Precio DECIMAL(12,2), @Hist INT, @Mov INT, @Ok INT, @Msg NVARCHAR(400);
BEGIN TRANSACTION;
EXEC dbo.sp_RegistrarPedido @ClienteId = 4, @EmpleadoId = 7, @SucursalId = 3, @DepositoId = 4,
     @Canal = N'WEB', @NroDireccion = 1, @ItemsJson = N'[{"ProductoId":10,"Cantidad":2}]',
     @PedidoId = @Id OUTPUT, @NroPedido = @Nro OUTPUT;
SELECT @Despues = dbo.fn_StockDisponible(10, 4),
       @Precio  = (SELECT PrecioUnitarioHistorico FROM dbo.PedidoDetalle WHERE PedidoId = @Id AND ProductoId = 10),
       @Hist    = (SELECT COUNT(*) FROM dbo.PedidoEstadoHistorial WHERE PedidoId = @Id AND EstadoAnterior IS NULL),
       @Mov     = (SELECT COUNT(*) FROM dbo.MovimientoStock WHERE DocumentoTipo = 'PEDIDO' AND DocumentoId = @Id);
SET @Ok  = CASE WHEN @Despues = @Antes - 2 AND @Precio = dbo.fn_PrecioVigente(10, NULL) AND @Hist = 1 AND @Mov = 1 THEN 0 ELSE -1 END;
SET @Msg = CONCAT(@Nro, ': stock ', @Antes, '->', @Despues, '; precio ', @Precio, '; historial ', @Hist, '; movimientos ', @Mov);
ROLLBACK TRANSACTION;
INSERT #Resultado VALUES ('P1-13', 'sp_RegistrarPedido', N'Alta valida: descuenta stock, fija precio vigente, audita y genera kardex', 0, @Ok, @Msg);
GO

/* ==========================================================================
   P2. sp_FacturarPedido
   ========================================================================== */
DECLARE @P VARCHAR(8) = 'P2-01', @O VARCHAR(40) = 'sp_FacturarPedido', @D NVARCHAR(200) = N'Facturar un pedido inexistente', @E INT = 50021;
BEGIN TRY
    EXEC dbo.sp_FacturarPedido @PedidoId = 99999;
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'P2-02', @O VARCHAR(40) = 'sp_FacturarPedido', @D NVARCHAR(200) = N'Facturar un pedido cancelado', @E INT = 50022;
DECLARE @Ped INT = (SELECT TOP (1) PedidoId FROM dbo.Pedido WHERE Estado = 'CANCELADO');
BEGIN TRY
    EXEC dbo.sp_FacturarPedido @PedidoId = @Ped;
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'P2-03', @O VARCHAR(40) = 'sp_FacturarPedido', @D NVARCHAR(200) = N'Segunda factura para el mismo pedido', @E INT = 50023;
DECLARE @Ped INT = (SELECT PedidoId FROM dbo.Pedido WHERE NroPedido = N'PED-2026-0007');
BEGIN TRY
    EXEC dbo.sp_FacturarPedido @PedidoId = @Ped;
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @Dif INT = (SELECT COUNT(*) FROM dbo.Factura f JOIN dbo.vw_PedidoTotal t ON t.PedidoId = f.PedidoId
                    WHERE f.Neto <> t.Total);
DECLARE @TipoA CHAR(1) = (SELECT f.TipoComprobante FROM dbo.Factura f JOIN dbo.Pedido p ON p.PedidoId = f.PedidoId
                          WHERE p.NroPedido = N'PED-2026-0007');
INSERT #Resultado VALUES ('P2-04', 'sp_FacturarPedido', N'Neto de todas las facturas = total del detalle; cliente con CUIT recibe factura A',
    0, CASE WHEN @Dif = 0 AND @TipoA = 'A' THEN 0 ELSE -1 END,
    CONCAT('facturas con diferencia: ', @Dif, '; tipo emitido a cliente CUIT: ', @TipoA));
GO

/* ==========================================================================
   P3 / T4. sp_RegistrarPago y trg_Pago_ControlarSaldo
   ========================================================================== */
DECLARE @P VARCHAR(8) = 'P3-01', @O VARCHAR(40) = 'sp_RegistrarPago', @D NVARCHAR(200) = N'Pago con monto cero', @E INT = 50033;
BEGIN TRY
    EXEC dbo.sp_RegistrarPago @FacturaId = 1, @Monto = 0, @MedioPagoId = 1;
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'P3-02', @O VARCHAR(40) = 'sp_RegistrarPago', @D NVARCHAR(200) = N'Pago que excede el saldo de la factura', @E INT = 50131;
DECLARE @Fac INT = (SELECT f.FacturaId FROM dbo.Factura f JOIN dbo.Pedido p ON p.PedidoId = f.PedidoId
                    WHERE p.NroPedido = N'PED-2026-0007');
BEGIN TRY
    EXEC dbo.sp_RegistrarPago @FacturaId = @Fac, @Monto = 700000, @MedioPagoId = 2;
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'T4-01', @O VARCHAR(40) = 'trg_Pago_ControlarSaldo', @D NVARCHAR(200) = N'INSERT directo (sin procedimiento) sobre una factura ya cancelada', @E INT = 50131;
BEGIN TRY
    INSERT INTO dbo.Pago (FacturaId, NroPago, Monto, MedioPagoId) VALUES (1, 3, 1.00, 1);
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @Fac INT = (SELECT f.FacturaId FROM dbo.Factura f JOIN dbo.Pedido p ON p.PedidoId = f.PedidoId
                    WHERE p.NroPedido = N'PED-2026-0007');
DECLARE @Saldo DECIMAL(14,2) = (SELECT ROUND(SaldoPendiente, 2) FROM dbo.vw_FacturaSaldo WHERE FacturaId = @Fac);
DECLARE @Nro TINYINT, @SaldoFinal DECIMAL(16,4), @Ok INT, @Msg NVARCHAR(400);
BEGIN TRANSACTION;
EXEC dbo.sp_RegistrarPago @FacturaId = @Fac, @Monto = @Saldo, @MedioPagoId = 3, @NroPago = @Nro OUTPUT;
SET @SaldoFinal = (SELECT SaldoPendiente FROM dbo.vw_FacturaSaldo WHERE FacturaId = @Fac);
SET @Ok  = CASE WHEN @Nro = 2 AND @SaldoFinal = 0 THEN 0 ELSE -1 END;
SET @Msg = CONCAT('pago nro ', @Nro, ' por ', @Saldo, '; saldo final ', @SaldoFinal);
ROLLBACK TRANSACTION;
INSERT #Resultado VALUES ('P3-03', 'sp_RegistrarPago', N'Pago exacto del saldo: numeracion correlativa y saldo cero', 0, @Ok, @Msg);
GO

/* ==========================================================================
   P4 / T5. sp_ActualizarPrecioProducto y trg_ProductoPrecio_ProtegerHistorial
   ========================================================================== */
DECLARE @P VARCHAR(8) = 'P4-01', @O VARCHAR(40) = 'sp_ActualizarPrecioProducto', @D NVARCHAR(200) = N'Precio igual al vigente', @E INT = 50044;
BEGIN TRY
    EXEC dbo.sp_ActualizarPrecioProducto @ProductoId = 1, @PrecioVenta = 1050000;
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'P4-02', @O VARCHAR(40) = 'sp_ActualizarPrecioProducto', @D NVARCHAR(200) = N'Precio con vigencia futura', @E INT = 50043;
DECLARE @Futuro DATE = DATEADD(DAY, 10, CAST(SYSDATETIME() AS DATE));
BEGIN TRY
    EXEC dbo.sp_ActualizarPrecioProducto @ProductoId = 1, @PrecioVenta = 1100000, @FechaDesde = @Futuro;
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'P4-03', @O VARCHAR(40) = 'sp_ActualizarPrecioProducto', @D NVARCHAR(200) = N'Segundo cambio de precio el mismo dia', @E INT = 50045;
BEGIN TRY
    EXEC dbo.sp_ActualizarPrecioProducto @ProductoId = 3, @PrecioVenta = 13500;
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'T5-01', @O VARCHAR(40) = 'trg_ProductoPrecio_Proteger', @D NVARCHAR(200) = N'UPDATE directo del precio vigente (pisar el valor)', @E INT = 50142;
BEGIN TRY
    UPDATE dbo.ProductoPrecio SET PrecioVenta = 999999 WHERE ProductoId = 1 AND FechaHasta IS NULL;
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'T5-02', @O VARCHAR(40) = 'trg_ProductoPrecio_Proteger', @D NVARCHAR(200) = N'Modificar un periodo de precio ya cerrado', @E INT = 50142;
BEGIN TRY
    UPDATE dbo.ProductoPrecio SET FechaHasta = '2026-06-30' WHERE ProductoId = 1 AND FechaDesde = '2026-01-02';
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'T5-03', @O VARCHAR(40) = 'trg_ProductoPrecio_Proteger', @D NVARCHAR(200) = N'Eliminar el historial de precios de un producto', @E INT = 50141;
BEGIN TRY
    DELETE FROM dbo.ProductoPrecio WHERE ProductoId = 1;
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @Vig INT = (SELECT COUNT(*) FROM (SELECT ProductoId FROM dbo.ProductoPrecio WHERE FechaHasta IS NULL
                                          GROUP BY ProductoId HAVING COUNT(*) > 1) x);
DECLARE @Huecos INT = (SELECT COUNT(*) FROM dbo.ProductoPrecio a
                       JOIN dbo.ProductoPrecio b ON b.ProductoId = a.ProductoId
                        AND b.FechaDesde = (SELECT MIN(c.FechaDesde) FROM dbo.ProductoPrecio c
                                            WHERE c.ProductoId = a.ProductoId AND c.FechaDesde > a.FechaDesde)
                       WHERE DATEADD(DAY, 1, a.FechaHasta) <> b.FechaDesde);
INSERT #Resultado VALUES ('P4-04', 'sp_ActualizarPrecioProducto', N'Historial consistente: un solo precio vigente y periodos contiguos sin huecos',
    0, CASE WHEN @Vig = 0 AND @Huecos = 0 THEN 0 ELSE -1 END,
    CONCAT('productos con 2+ vigentes: ', @Vig, '; periodos no contiguos: ', @Huecos));
GO

/* ==========================================================================
   P5. sp_CancelarPedido
   ========================================================================== */
DECLARE @P VARCHAR(8) = 'P5-01', @O VARCHAR(40) = 'sp_CancelarPedido', @D NVARCHAR(200) = N'Cancelar un pedido facturado', @E INT = 50053;
DECLARE @Ped INT = (SELECT PedidoId FROM dbo.Pedido WHERE NroPedido = N'PED-2026-0007');
BEGIN TRY
    EXEC dbo.sp_CancelarPedido @PedidoId = @Ped, @EmpleadoId = 3;
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'P5-02', @O VARCHAR(40) = 'sp_CancelarPedido', @D NVARCHAR(200) = N'Cancelar un pedido ya cancelado', @E INT = 50052;
DECLARE @Ped INT = (SELECT TOP (1) PedidoId FROM dbo.Pedido WHERE Estado = 'CANCELADO');
BEGIN TRY
    EXEC dbo.sp_CancelarPedido @PedidoId = @Ped, @EmpleadoId = 3;
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @Ped INT = (SELECT TOP (1) PedidoId FROM dbo.Pedido WHERE Estado = 'CANCELADO');
DECLARE @Neto INT = (SELECT COUNT(*) FROM (
                        SELECT ProductoId, DepositoId
                        FROM dbo.MovimientoStock
                        WHERE DocumentoTipo = 'PEDIDO' AND DocumentoId = @Ped
                        GROUP BY ProductoId, DepositoId
                        HAVING SUM(CASE WHEN TipoMovimiento = 'INGRESO' THEN Cantidad ELSE -Cantidad END) <> 0) x);
DECLARE @Movs INT = (SELECT COUNT(*) FROM dbo.MovimientoStock WHERE DocumentoTipo = 'PEDIDO' AND DocumentoId = @Ped);
INSERT #Resultado VALUES ('P5-03', 'sp_CancelarPedido', N'El pedido anulado deja saldo neto cero en el kardex (egresos revertidos)',
    0, CASE WHEN @Neto = 0 AND @Movs = 6 THEN 0 ELSE -1 END,
    CONCAT('movimientos del pedido: ', @Movs, '; pares con saldo distinto de cero: ', @Neto));
GO

/* ==========================================================================
   T1. trg_MovimientoStock_AplicarKardex
   ========================================================================== */
DECLARE @P VARCHAR(8) = 'T1-01', @O VARCHAR(40) = 'trg_MovimientoStock_Kardex', @D NVARCHAR(200) = N'Modificar un movimiento de kardex', @E INT = 50101;
BEGIN TRY
    UPDATE dbo.MovimientoStock SET Cantidad = 1 WHERE MovimientoId = 1;
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'T1-02', @O VARCHAR(40) = 'trg_MovimientoStock_Kardex', @D NVARCHAR(200) = N'Eliminar un movimiento de kardex', @E INT = 50101;
BEGIN TRY
    DELETE FROM dbo.MovimientoStock WHERE MovimientoId = 1;
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'T1-03', @O VARCHAR(40) = 'trg_MovimientoStock_Kardex', @D NVARCHAR(200) = N'Egreso mayor que la existencia del deposito', @E INT = 50102;
BEGIN TRY
    INSERT INTO dbo.MovimientoStock (ProductoId, DepositoId, TipoMovimiento, Cantidad, EmpleadoId, Motivo)
    VALUES (9, 1, 'EGRESO', 1000, 4, N'Prueba de stock insuficiente');
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @Antes DECIMAL(12,3) = dbo.fn_StockDisponible(3, 1), @Ing DECIMAL(12,3), @Aj DECIMAL(12,3), @Ok INT, @Msg NVARCHAR(400);
BEGIN TRANSACTION;
INSERT INTO dbo.MovimientoStock (ProductoId, DepositoId, TipoMovimiento, Cantidad, EmpleadoId, Motivo)
VALUES (3, 1, 'INGRESO', 5, 4, N'Prueba ingreso');
SET @Ing = dbo.fn_StockDisponible(3, 1);
INSERT INTO dbo.MovimientoStock (ProductoId, DepositoId, TipoMovimiento, Cantidad, EmpleadoId, Motivo, DocumentoTipo, DocumentoId)
VALUES (3, 1, 'AJUSTE', 2, 4, N'Prueba ajuste por rotura', 'AJUSTE', 2);
SET @Aj = dbo.fn_StockDisponible(3, 1);
SET @Ok  = CASE WHEN @Ing = @Antes + 5 AND @Aj = @Antes + 3 THEN 0 ELSE -1 END;
SET @Msg = CONCAT('stock ', @Antes, ' -> INGRESO 5 -> ', @Ing, ' -> AJUSTE 2 -> ', @Aj);
ROLLBACK TRANSACTION;
INSERT #Resultado VALUES ('T1-04', 'trg_MovimientoStock_Kardex', N'INGRESO suma y AJUSTE resta automaticamente sobre Stock', 0, @Ok, @Msg);
GO

/* ==========================================================================
   T2. trg_Stock_ControlarExistencias
   ========================================================================== */
DECLARE @P VARCHAR(8) = 'T2-01', @O VARCHAR(40) = 'trg_Stock_ControlarExistencias', @D NVARCHAR(200) = N'UPDATE directo de Stock.Cantidad (sin kardex)', @E INT = 50111;
BEGIN TRY
    UPDATE dbo.Stock SET Cantidad = Cantidad + 100 WHERE ProductoId = 1 AND DepositoId = 1;
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'T2-02', @O VARCHAR(40) = 'trg_Stock_ControlarExistencias', @D NVARCHAR(200) = N'Alta de stock con cantidad inicial distinta de cero', @E INT = 50111;
BEGIN TRY
    INSERT INTO dbo.Stock (ProductoId, DepositoId, Cantidad, StockMinimo) VALUES (2, 4, 10, 2);
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @Antes DECIMAL(12,3) = dbo.fn_StockDisponible(3, 2);
DECLARE @P VARCHAR(8) = 'T2-03', @O VARCHAR(40) = 'trg_Stock_ControlarExistencias', @D NVARCHAR(200) = N'Ingreso que supera la capacidad del deposito (RN07 de AE1)', @E INT = 50112;
BEGIN TRY
    INSERT INTO dbo.MovimientoStock (ProductoId, DepositoId, TipoMovimiento, Cantidad, EmpleadoId, Motivo)
    VALUES (3, 2, 'INGRESO', 500, 6, N'Prueba de capacidad');
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
DECLARE @Despues DECIMAL(12,3) = dbo.fn_StockDisponible(3, 2);
INSERT #Resultado VALUES ('T2-04', 'trg_Stock_ControlarExistencias', N'Tras el rechazo por capacidad el movimiento y el stock se revierten',
    0, CASE WHEN @Antes = @Despues
                 AND NOT EXISTS (SELECT 1 FROM dbo.MovimientoStock WHERE Motivo = N'Prueba de capacidad') THEN 0 ELSE -1 END,
    CONCAT('stock mouse en salon: ', @Antes, ' -> ', @Despues));
GO

DECLARE @Ok INT, @Msg NVARCHAR(400);
BEGIN TRANSACTION;
BEGIN TRY
    INSERT INTO dbo.Stock (ProductoId, DepositoId, Cantidad, StockMinimo) VALUES (2, 4, 0, 2);
    SET @Ok = 0; SET @Msg = N'alta del par (producto 2, deposito 4) con cantidad 0 aceptada';
END TRY BEGIN CATCH
    SET @Ok = ERROR_NUMBER(); SET @Msg = ERROR_MESSAGE();
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
INSERT #Resultado VALUES ('T2-05', 'trg_Stock_ControlarExistencias', N'Alta de un producto en un deposito con cantidad 0', 0, @Ok, @Msg);
GO

/* ==========================================================================
   T3. trg_Pedido_ControlarEstado
   ========================================================================== */
DECLARE @P VARCHAR(8) = 'T3-01', @O VARCHAR(40) = 'trg_Pedido_ControlarEstado', @D NVARCHAR(200) = N'Retroceder un pedido ENTREGADO a PENDIENTE', @E INT = 50121;
BEGIN TRY
    UPDATE dbo.Pedido SET Estado = 'PENDIENTE' WHERE NroPedido = N'PED-2026-0001';
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'T3-02', @O VARCHAR(40) = 'trg_Pedido_ControlarEstado', @D NVARCHAR(200) = N'Entregar un pedido sin factura', @E INT = 50122;
DECLARE @Id INT;
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.sp_RegistrarPedido @ClienteId = 2, @EmpleadoId = 5, @SucursalId = 2, @DepositoId = 3,
         @Canal = N'MOSTRADOR', @ItemsJson = N'[{"ProductoId":3,"Cantidad":1}]', @PedidoId = @Id OUTPUT;
    UPDATE dbo.Pedido SET Estado = 'ENTREGADO' WHERE PedidoId = @Id;
    ROLLBACK TRANSACTION;
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'T3-03', @O VARCHAR(40) = 'trg_Pedido_ControlarEstado', @D NVARCHAR(200) = N'Cancelar por UPDATE un pedido facturado', @E INT = 50123;
BEGIN TRY
    UPDATE dbo.Pedido SET Estado = 'CANCELADO' WHERE NroPedido = N'PED-2026-0007';
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @P VARCHAR(8) = 'T3-04', @O VARCHAR(40) = 'trg_Pedido_ControlarEstado', @D NVARCHAR(200) = N'Cancelar por UPDATE sin revertir el stock egresado', @E INT = 50124;
DECLARE @Id INT;
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.sp_RegistrarPedido @ClienteId = 2, @EmpleadoId = 5, @SucursalId = 2, @DepositoId = 3,
         @Canal = N'MOSTRADOR', @ItemsJson = N'[{"ProductoId":3,"Cantidad":1}]', @PedidoId = @Id OUTPUT;
    UPDATE dbo.Pedido SET Estado = 'CANCELADO' WHERE PedidoId = @Id;
    ROLLBACK TRANSACTION;
    INSERT #Resultado VALUES (@P, @O, @D, @E, 0, N'(operacion aceptada)');
END TRY BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT #Resultado VALUES (@P, @O, @D, @E, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH;
GO

DECLARE @Ped INT = (SELECT TOP (1) PedidoId FROM dbo.Pedido WHERE Estado = 'CANCELADO');
DECLARE @Secuencia NVARCHAR(200) = (
    SELECT STRING_AGG(CONCAT(ISNULL(EstadoAnterior, 'alta'), '->', EstadoNuevo), ' ; ')
           WITHIN GROUP (ORDER BY HistorialId)
    FROM dbo.PedidoEstadoHistorial WHERE PedidoId = @Ped);
INSERT #Resultado VALUES ('T3-05', 'trg_Pedido_ControlarEstado', N'Auditoria: el historial registra el alta y cada cambio de estado',
    0, CASE WHEN @Secuencia = N'alta->CONFIRMADO ; CONFIRMADO->CANCELADO' THEN 0 ELSE -1 END, @Secuencia);
GO

/* ==========================================================================
   RESUMEN
   ========================================================================== */
SELECT Prueba, Objeto, Descripcion, Esperado, Obtenido, Resultado, Mensaje
FROM #Resultado ORDER BY Id;

SELECT COUNT(*) AS Pruebas,
       SUM(CASE WHEN Resultado = 'OK' THEN 1 ELSE 0 END) AS Correctas,
       SUM(CASE WHEN Resultado = 'FALLO' THEN 1 ELSE 0 END) AS Fallidas
FROM #Resultado;
GO

PRINT 'Pruebas de programacion finalizadas. Revisar que la columna Fallidas sea 0.';
GO
