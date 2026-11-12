/* ==========================================================================
   AE4 - ISI17BAD28V26AE4V26 - Proyecto StockFlow
   Archivo: 04_programacion.sql  -- Funciones, procedimientos y triggers
   Ejecutar DESPUES de 03_pruebas_integridad.sql
   --------------------------------------------------------------------------
   Cada objeto resuelve una regla de negocio que el DDL no puede expresar
   (AE2, seccion 11.6) o una operacion del sistema que debe ser atomica.

   FUNCIONES
     F1 dbo.fn_PrecioVigente         precio de venta de un producto a una fecha
     F2 dbo.fn_StockDisponible       existencia por deposito o total
     F3 dbo.fn_TotalCompradoCliente  importe neto comprado por un cliente
   PROCEDIMIENTOS (todos transaccionales, con controles y THROW)
     P1 dbo.sp_RegistrarPedido       alta de venta: pedido + detalle + kardex
     P2 dbo.sp_FacturarPedido        factura con neto = total del detalle
     P3 dbo.sp_RegistrarPago         cobranza parcial o total de una factura
     P4 dbo.sp_ActualizarPrecioProducto  cambio de precio con historial
     P5 dbo.sp_CancelarPedido        anulacion con reversion de stock
   TRIGGERS
     T1 trg_MovimientoStock_AplicarKardex   automatizacion: kardex -> stock
     T2 trg_Stock_ControlarExistencias      control: capacidad y coherencia
     T3 trg_Pedido_ControlarEstado          validacion + auditoria de estados
     T4 trg_Pago_ControlarSaldo             validacion: no cobrar de mas
     T5 trg_ProductoPrecio_ProtegerHistorial integridad del historial

   Convencion de errores: THROW 50001-50099 en procedimientos y
   50100-50199 en triggers, con mensajes legibles para la aplicacion.
   ========================================================================== */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE StockFlow;
GO

/* ==========================================================================
   F1. fn_PrecioVigente(@ProductoId, @Fecha)
   RN: el precio de un producto en una fecha es el del periodo de
   ProductoPrecio que la contiene. @Fecha NULL = hoy. Devuelve NULL si el
   producto no tenia precio en esa fecha.
   ========================================================================== */
CREATE OR ALTER FUNCTION dbo.fn_PrecioVigente (@ProductoId INT, @Fecha DATE)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @Precio DECIMAL(12,2);
    DECLARE @F DATE = ISNULL(@Fecha, CAST(SYSDATETIME() AS DATE));

    SELECT TOP (1) @Precio = pp.PrecioVenta
    FROM dbo.ProductoPrecio AS pp
    WHERE pp.ProductoId = @ProductoId
      AND pp.FechaDesde <= @F
      AND (pp.FechaHasta IS NULL OR pp.FechaHasta >= @F)
    ORDER BY pp.FechaDesde DESC;

    RETURN @Precio;
END;
GO

/* ==========================================================================
   F2. fn_StockDisponible(@ProductoId, @DepositoId)
   Existencia de un producto en un deposito; con @DepositoId NULL devuelve
   el stock total (atributo derivado StockTotal del AE1). Nunca NULL.
   ========================================================================== */
CREATE OR ALTER FUNCTION dbo.fn_StockDisponible (@ProductoId INT, @DepositoId INT)
RETURNS DECIMAL(12,3)
AS
BEGIN
    RETURN ISNULL((
        SELECT SUM(s.Cantidad)
        FROM dbo.Stock AS s
        WHERE s.ProductoId = @ProductoId
          AND (@DepositoId IS NULL OR s.DepositoId = @DepositoId)
    ), 0);
END;
GO

/* ==========================================================================
   F3. fn_TotalCompradoCliente(@ClienteId)
   Importe neto acumulado de los pedidos no cancelados de un cliente.
   Evolucion de fn_CalcularTotalGastoCliente del borrador de AE4: ahora
   considera el descuento de cada renglon y excluye pedidos cancelados.
   ========================================================================== */
CREATE OR ALTER FUNCTION dbo.fn_TotalCompradoCliente (@ClienteId INT)
RETURNS DECIMAL(16,2)
AS
BEGIN
    RETURN ISNULL((
        SELECT SUM(CAST(pd.Cantidad * pd.PrecioUnitarioHistorico
                        * (1 - pd.DescuentoPct / 100.0) AS DECIMAL(16,2)))
        FROM dbo.Pedido AS p
        JOIN dbo.PedidoDetalle AS pd ON pd.PedidoId = p.PedidoId
        WHERE p.ClienteId = @ClienteId
          AND p.Estado <> 'CANCELADO'
    ), 0);
END;
GO

/* ==========================================================================
   T1. trg_MovimientoStock_AplicarKardex  (AFTER INSERT, UPDATE, DELETE)
   RN11: la existencia de cada par (producto, deposito) es el saldo de su
   kardex. Todo movimiento nuevo actualiza dbo.Stock en la misma transaccion:
   INGRESO suma; EGRESO, TRANSFER (salida del deposito origen) y AJUSTE
   (merma o diferencia de inventario) restan.
   RN12: el kardex es inalterable. Un movimiento no se modifica ni se borra:
   los errores se corrigen con un movimiento compensatorio.
   ========================================================================== */
CREATE OR ALTER TRIGGER dbo.trg_MovimientoStock_AplicarKardex
ON dbo.MovimientoStock
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted)
        RETURN;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 50101, 'El kardex es inalterable: los movimientos de stock no se modifican ni se eliminan. Registre un movimiento compensatorio.', 1;

    DECLARE @Delta TABLE (
        ProductoId INT NOT NULL,
        DepositoId INT NOT NULL,
        Delta      DECIMAL(12,3) NOT NULL,
        PRIMARY KEY (ProductoId, DepositoId));

    INSERT INTO @Delta (ProductoId, DepositoId, Delta)
    SELECT i.ProductoId, i.DepositoId,
           SUM(CASE WHEN i.TipoMovimiento = 'INGRESO' THEN i.Cantidad ELSE -i.Cantidad END)
    FROM inserted AS i
    GROUP BY i.ProductoId, i.DepositoId;

    DECLARE @Msg NVARCHAR(400);
    SELECT TOP (1) @Msg = CONCAT('Stock insuficiente: producto ', p.Sku, ' en ', dep.Nombre,
                                 ' tiene ', CAST(s.Cantidad AS DECIMAL(12,0)),
                                 ' unidades y el movimiento requiere ', CAST(-d.Delta AS DECIMAL(12,0)), '.')
    FROM @Delta AS d
    JOIN dbo.Stock    AS s   ON s.ProductoId = d.ProductoId AND s.DepositoId = d.DepositoId
    JOIN dbo.Producto AS p   ON p.ProductoId = d.ProductoId
    JOIN dbo.Deposito AS dep ON dep.DepositoId = d.DepositoId
    WHERE s.Cantidad + d.Delta < 0;

    IF @Msg IS NOT NULL
        THROW 50102, @Msg, 1;

    UPDATE s
       SET s.Cantidad = s.Cantidad + d.Delta
    FROM dbo.Stock AS s
    JOIN @Delta AS d ON d.ProductoId = s.ProductoId AND d.DepositoId = s.DepositoId;
END;
GO

/* ==========================================================================
   T2. trg_Stock_ControlarExistencias  (AFTER INSERT, UPDATE)
   RN11 (coherencia stock-kardex): la cantidad solo puede cambiar a traves
   de T1. Una modificacion directa de Stock.Cantidad (nivel de anidamiento
   1) se rechaza. Un alta de stock solo se admite con cantidad 0.
   RN07 de AE1 (capacidad): la suma de existencias de un deposito no puede
   superar su CapacidadMaxima. Era la unica regla del AE1 que el modelo
   conceptual no podia expresar; queda implementada aca.
   ========================================================================== */
CREATE OR ALTER TRIGGER dbo.trg_Stock_ControlarExistencias
ON dbo.Stock
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted)
        RETURN;

    /* TRIGGER_NESTLEVEL() = 1: el cambio no viene de otro trigger. */
    IF TRIGGER_NESTLEVEL() = 1
       AND EXISTS (
            SELECT 1
            FROM inserted AS i
            LEFT JOIN deleted AS d
                   ON d.ProductoId = i.ProductoId AND d.DepositoId = i.DepositoId
            WHERE i.Cantidad <> ISNULL(d.Cantidad, 0))
        THROW 50111, 'Stock.Cantidad no se modifica directamente: registre un movimiento en MovimientoStock (INGRESO, EGRESO, TRANSFER o AJUSTE).', 1;

    DECLARE @Msg NVARCHAR(400);
    SELECT TOP (1) @Msg = CONCAT('Capacidad excedida en ', dep.Nombre, ': ocupacion resultante ',
                                 CAST(o.Ocupacion AS DECIMAL(12,0)), ' sobre una capacidad maxima de ',
                                 dep.CapacidadMaxima, ' unidades.')
    FROM (SELECT DISTINCT DepositoId FROM inserted) AS a
    JOIN dbo.Deposito AS dep ON dep.DepositoId = a.DepositoId
    CROSS APPLY (SELECT SUM(s.Cantidad) AS Ocupacion
                 FROM dbo.Stock AS s WHERE s.DepositoId = a.DepositoId) AS o
    WHERE dep.CapacidadMaxima IS NOT NULL
      AND o.Ocupacion > dep.CapacidadMaxima;

    IF @Msg IS NOT NULL
        THROW 50112, @Msg, 1;
END;
GO

/* ==========================================================================
   T3. trg_Pedido_ControlarEstado  (AFTER INSERT, UPDATE)
   RN13 (ciclo de vida): PENDIENTE -> CONFIRMADO | CANCELADO;
       CONFIRMADO -> ENTREGADO | CANCELADO; ENTREGADO y CANCELADO son finales.
   RN14: un pedido solo pasa a ENTREGADO si esta facturado (AE2, 11.4), no
       puede cancelarse si ya tiene factura, y no puede quedar CANCELADO con
       stock egresado sin revertir (la anulacion se hace con P5).
   RN15 (auditoria): cada alta y cada cambio de estado se registra en
       PedidoEstadoHistorial con fecha, hora y usuario.
   ========================================================================== */
CREATE OR ALTER TRIGGER dbo.trg_Pedido_ControlarEstado
ON dbo.Pedido
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted)
        RETURN;

    DECLARE @Msg NVARCHAR(400);

    /* 1. Transiciones permitidas (solo en UPDATE con cambio real de estado). */
    SELECT TOP (1) @Msg = CONCAT('Transicion de estado no permitida en ', i.NroPedido, ': ',
                                 d.Estado, ' -> ', i.Estado, '.')
    FROM inserted AS i
    JOIN deleted  AS d ON d.PedidoId = i.PedidoId
    WHERE i.Estado <> d.Estado
      AND NOT ( (d.Estado = 'PENDIENTE'  AND i.Estado IN ('CONFIRMADO','CANCELADO'))
             OR (d.Estado = 'CONFIRMADO' AND i.Estado IN ('ENTREGADO','CANCELADO')) );
    IF @Msg IS NOT NULL THROW 50121, @Msg, 1;

    /* 2. ENTREGADO exige factura. */
    SELECT TOP (1) @Msg = CONCAT('El pedido ', i.NroPedido, ' no puede entregarse sin factura emitida.')
    FROM inserted AS i
    LEFT JOIN deleted AS d ON d.PedidoId = i.PedidoId
    WHERE i.Estado = 'ENTREGADO' AND ISNULL(d.Estado, '') <> 'ENTREGADO'
      AND NOT EXISTS (SELECT 1 FROM dbo.Factura AS f WHERE f.PedidoId = i.PedidoId);
    IF @Msg IS NOT NULL THROW 50122, @Msg, 1;

    /* 3. CANCELADO: sin factura y sin stock egresado pendiente de reversion. */
    SELECT TOP (1) @Msg = CONCAT('El pedido ', i.NroPedido, ' esta facturado y no puede cancelarse.')
    FROM inserted AS i
    JOIN deleted  AS d ON d.PedidoId = i.PedidoId
    WHERE i.Estado = 'CANCELADO' AND d.Estado <> 'CANCELADO'
      AND EXISTS (SELECT 1 FROM dbo.Factura AS f WHERE f.PedidoId = i.PedidoId);
    IF @Msg IS NOT NULL THROW 50123, @Msg, 1;

    SELECT TOP (1) @Msg = CONCAT('El pedido ', i.NroPedido,
                                 ' tiene stock egresado sin revertir: anulelo con dbo.sp_CancelarPedido.')
    FROM inserted AS i
    JOIN deleted  AS d ON d.PedidoId = i.PedidoId
    WHERE i.Estado = 'CANCELADO' AND d.Estado <> 'CANCELADO'
      AND EXISTS (
            SELECT 1
            FROM dbo.MovimientoStock AS m
            WHERE m.DocumentoTipo = 'PEDIDO' AND m.DocumentoId = i.PedidoId
            GROUP BY m.ProductoId, m.DepositoId
            HAVING SUM(CASE WHEN m.TipoMovimiento = 'INGRESO' THEN m.Cantidad ELSE -m.Cantidad END) < 0);
    IF @Msg IS NOT NULL THROW 50124, @Msg, 1;

    /* 4. Auditoria: alta (EstadoAnterior NULL) o cambio efectivo de estado. */
    INSERT INTO dbo.PedidoEstadoHistorial (PedidoId, EstadoAnterior, EstadoNuevo)
    SELECT i.PedidoId, d.Estado, i.Estado
    FROM inserted AS i
    LEFT JOIN deleted AS d ON d.PedidoId = i.PedidoId
    WHERE d.PedidoId IS NULL OR d.Estado <> i.Estado;
END;
GO

/* ==========================================================================
   T4. trg_Pago_ControlarSaldo  (AFTER INSERT, UPDATE)
   RN16 (AE2, 11.6): la suma de los pagos de una factura no puede superar
   su total. Compara una fila con un agregado de la misma tabla, por eso no
   puede ser un CHECK.
   ========================================================================== */
CREATE OR ALTER TRIGGER dbo.trg_Pago_ControlarSaldo
ON dbo.Pago
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted)
        RETURN;

    DECLARE @Msg NVARCHAR(400);
    SELECT TOP (1) @Msg = CONCAT('El pago excede el saldo de la factura ', f.TipoComprobante, '-',
                                 RIGHT(CONCAT('0000', f.PuntoVenta), 4), '-',
                                 RIGHT(CONCAT('00000000', f.NroComprobante), 8),
                                 ': total ', CAST(ROUND(f.TotalFactura, 2) AS DECIMAL(16,2)),
                                 ', cobrado ', c.Cobrado, '.')
    FROM (SELECT DISTINCT FacturaId FROM inserted) AS a
    JOIN dbo.Factura AS f ON f.FacturaId = a.FacturaId
    CROSS APPLY (SELECT SUM(pg.Monto) AS Cobrado
                 FROM dbo.Pago AS pg WHERE pg.FacturaId = a.FacturaId) AS c
    WHERE c.Cobrado > ROUND(f.TotalFactura, 2);

    IF @Msg IS NOT NULL
        THROW 50131, @Msg, 1;
END;
GO

/* ==========================================================================
   T5. trg_ProductoPrecio_ProtegerHistorial  (AFTER UPDATE, DELETE)
   RN10: el historial de precios es inalterable (en el borrador de AE4 esta
   regla se cubria con la tabla AUDITORIA_PRECIOS; con el modelo del AE2 el
   historial ya existe y lo que hace falta es protegerlo). La unica
   modificacion admitida es cerrar el periodo vigente (FechaHasta NULL ->
   fecha), que es lo que hace P4. Un precio no se corrige "pisando" la fila.
   ========================================================================== */
CREATE OR ALTER TRIGGER dbo.trg_ProductoPrecio_ProtegerHistorial
ON dbo.ProductoPrecio
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM deleted)
        RETURN;

    IF NOT EXISTS (SELECT 1 FROM inserted)
        THROW 50141, 'El historial de precios no admite eliminaciones. Para discontinuar un producto use Producto.Activo = 0.', 1;

    IF UPDATE(ProductoId) OR UPDATE(FechaDesde)
       OR EXISTS (
            SELECT 1
            FROM deleted  AS d
            JOIN inserted AS i ON i.ProductoId = d.ProductoId AND i.FechaDesde = d.FechaDesde
            WHERE d.FechaHasta IS NOT NULL
               OR i.PrecioVenta <> d.PrecioVenta
               OR ISNULL(i.PrecioCosto, -1) <> ISNULL(d.PrecioCosto, -1))
        THROW 50142, 'El historial de precios es inalterable: solo puede cerrarse el periodo vigente. Use dbo.sp_ActualizarPrecioProducto.', 1;
END;
GO

/* ==========================================================================
   P1. sp_RegistrarPedido
   Registra una venta completa como unidad atomica:
     1. cabecera del pedido (estado CONFIRMADO, numeracion PED-AAAA-NNNN);
     2. renglones con PrecioUnitarioHistorico = precio vigente (RN06 de AE1);
     3. un EGRESO de kardex por renglon, que T1 descuenta del stock.
   Parametros: @ItemsJson es un arreglo JSON
     [{"ProductoId":6,"Cantidad":2,"DescuentoPct":0}, ...]
   (DescuentoPct es opcional). Se eligio JSON porque es lo que envia la
   aplicacion web y SQL Server 2022 lo procesa con OPENJSON.
   ========================================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarPedido
    @ClienteId    INT,
    @EmpleadoId   INT,
    @SucursalId   INT,
    @DepositoId   INT,
    @Canal        NVARCHAR(12),
    @NroDireccion TINYINT = NULL,
    @ItemsJson    NVARCHAR(MAX),
    @PedidoId     INT          = NULL OUTPUT,
    @NroPedido    NVARCHAR(16) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Msg NVARCHAR(400);
    DECLARE @Hoy DATE = CAST(SYSDATETIME() AS DATE);

    /* ---- Controles de parametros (antes de abrir la transaccion) ---- */
    IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE ClienteId = @ClienteId AND Activo = 1)
        THROW 50001, 'El cliente no existe o esta inactivo.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Empleado
                   WHERE EmpleadoId = @EmpleadoId AND Activo = 1
                     AND Rol IN ('VENDEDOR','GERENTE','ADMIN'))
        THROW 50002, 'El empleado no existe, esta inactivo o su rol no le permite registrar ventas.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Empleado WHERE EmpleadoId = @EmpleadoId AND SucursalId = @SucursalId)
        THROW 50003, 'El empleado no pertenece a la sucursal indicada.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Deposito WHERE DepositoId = @DepositoId AND SucursalId = @SucursalId)
        THROW 50004, 'El deposito de despacho no pertenece a la sucursal indicada.', 1;

    IF @Canal NOT IN ('MOSTRADOR','WEB','TELEFONO')
        THROW 50005, 'Canal de venta invalido (MOSTRADOR, WEB o TELEFONO).', 1;
    IF @Canal = 'MOSTRADOR' AND @NroDireccion IS NOT NULL
        THROW 50005, 'Un pedido de mostrador se retira en el local y no lleva direccion de envio.', 1;
    IF @Canal <> 'MOSTRADOR' AND NOT EXISTS (SELECT 1 FROM dbo.ClienteDireccion
                                            WHERE ClienteId = @ClienteId AND NroDireccion = @NroDireccion)
        THROW 50005, 'Los pedidos WEB y TELEFONO requieren una direccion de envio registrada del cliente.', 1;

    IF @ItemsJson IS NULL OR ISJSON(@ItemsJson) = 0
        THROW 50006, 'El detalle del pedido no es un JSON valido.', 1;

    DECLARE @Items TABLE (
        ProductoId   INT,
        Cantidad     DECIMAL(12,3),
        DescuentoPct DECIMAL(5,2),
        Precio       DECIMAL(12,2));

    INSERT INTO @Items (ProductoId, Cantidad, DescuentoPct)
    SELECT j.ProductoId, j.Cantidad, ISNULL(j.DescuentoPct, 0)
    FROM OPENJSON(@ItemsJson)
         WITH (ProductoId   INT           '$.ProductoId',
               Cantidad     DECIMAL(12,3) '$.Cantidad',
               DescuentoPct DECIMAL(5,2)  '$.DescuentoPct') AS j;

    IF NOT EXISTS (SELECT 1 FROM @Items)
        THROW 50006, 'Todo pedido debe contener al menos un renglon (RN08).', 1;

    IF EXISTS (SELECT 1 FROM @Items WHERE ProductoId IS NULL OR Cantidad IS NULL OR Cantidad <= 0
                                       OR DescuentoPct < 0 OR DescuentoPct > 100)
        THROW 50007, 'Cada renglon requiere ProductoId, Cantidad > 0 y un descuento entre 0 y 100.', 1;

    IF EXISTS (SELECT ProductoId FROM @Items GROUP BY ProductoId HAVING COUNT(*) > 1)
        THROW 50007, 'Un producto no puede repetirse en el mismo pedido: unifique las cantidades.', 1;

    SELECT TOP (1) @Msg = CONCAT('El producto ', i.ProductoId, ' no existe o esta discontinuado.')
    FROM @Items AS i
    LEFT JOIN dbo.Producto AS p ON p.ProductoId = i.ProductoId AND p.Activo = 1
    WHERE p.ProductoId IS NULL;
    IF @Msg IS NOT NULL THROW 50008, @Msg, 1;

    UPDATE @Items SET Precio = dbo.fn_PrecioVigente(ProductoId, @Hoy);

    SELECT TOP (1) @Msg = CONCAT('El producto ', p.Sku, ' no tiene precio vigente.')
    FROM @Items AS i JOIN dbo.Producto AS p ON p.ProductoId = i.ProductoId
    WHERE i.Precio IS NULL;
    IF @Msg IS NOT NULL THROW 50009, @Msg, 1;

    /* ---- Operacion atomica ---- */
    BEGIN TRY
        BEGIN TRANSACTION;

        /* Control de stock dentro de la transaccion y con bloqueo de
           actualizacion: dos ventas concurrentes no pueden vender la misma
           unidad. T1 vuelve a controlar como segunda linea de defensa. */
        SELECT TOP (1) @Msg = CONCAT('Stock insuficiente de ', p.Sku, ' en el deposito: disponible ',
                                     CAST(ISNULL(s.Cantidad, 0) AS DECIMAL(12,0)),
                                     ', solicitado ', CAST(i.Cantidad AS DECIMAL(12,0)), '.')
        FROM @Items AS i
        JOIN dbo.Producto AS p ON p.ProductoId = i.ProductoId
        LEFT JOIN dbo.Stock AS s WITH (UPDLOCK, HOLDLOCK)
               ON s.ProductoId = i.ProductoId AND s.DepositoId = @DepositoId
        WHERE ISNULL(s.Cantidad, 0) < i.Cantidad;
        IF @Msg IS NOT NULL THROW 50010, @Msg, 1;

        /* Numeracion correlativa por anio, serializada con UPDLOCK/HOLDLOCK. */
        DECLARE @Anio CHAR(4) = CAST(YEAR(@Hoy) AS CHAR(4));
        DECLARE @Siguiente INT = 1 + ISNULL((
            SELECT MAX(CAST(RIGHT(NroPedido, 4) AS INT))
            FROM dbo.Pedido WITH (UPDLOCK, HOLDLOCK)
            WHERE NroPedido LIKE 'PED-' + @Anio + '-%'), 0);
        SET @NroPedido = CONCAT('PED-', @Anio, '-', RIGHT(CONCAT('0000', @Siguiente), 4));

        INSERT INTO dbo.Pedido (NroPedido, ClienteId, NroDireccion, EmpleadoId, SucursalId, Estado, Canal)
        VALUES (@NroPedido, @ClienteId, @NroDireccion, @EmpleadoId, @SucursalId, 'CONFIRMADO', @Canal);
        SET @PedidoId = SCOPE_IDENTITY();

        INSERT INTO dbo.PedidoDetalle (PedidoId, ProductoId, Cantidad, PrecioUnitarioHistorico, DescuentoPct)
        SELECT @PedidoId, ProductoId, Cantidad, Precio, DescuentoPct
        FROM @Items;

        INSERT INTO dbo.MovimientoStock (ProductoId, DepositoId, TipoMovimiento, Cantidad, EmpleadoId,
                                         Motivo, DocumentoTipo, DocumentoId)
        SELECT ProductoId, @DepositoId, 'EGRESO', Cantidad, @EmpleadoId,
               CONCAT('Venta ', @NroPedido), 'PEDIDO', @PedidoId
        FROM @Items;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @PedidoId = NULL;
        SET @NroPedido = NULL;
        THROW;
    END CATCH;
END;
GO

/* ==========================================================================
   P2. sp_FacturarPedido
   Emite la factura de un pedido CONFIRMADO o ENTREGADO, con
   Neto = total del detalle (vw_PedidoTotal). Resuelve la regla del AE2
   "Factura.Neto debe coincidir con la suma del detalle".
   @TipoComprobante NULL -> se deduce: 'A' si el cliente tiene CUIT, 'B' en
   otro caso. El numero es correlativo por (tipo, punto de venta).
   ========================================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_FacturarPedido
    @PedidoId        INT,
    @PuntoVenta      SMALLINT = 1,
    @TipoComprobante CHAR(1)  = NULL,
    @AlicuotaIva     DECIMAL(5,2) = 21,
    @FacturaId       INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Estado NVARCHAR(12), @TipoDoc NVARCHAR(6);
    SELECT @Estado = p.Estado, @TipoDoc = c.TipoDoc
    FROM dbo.Pedido AS p JOIN dbo.Cliente AS c ON c.ClienteId = p.ClienteId
    WHERE p.PedidoId = @PedidoId;

    IF @Estado IS NULL
        THROW 50021, 'El pedido no existe.', 1;
    IF @Estado NOT IN ('CONFIRMADO','ENTREGADO')
        THROW 50022, 'Solo se facturan pedidos CONFIRMADOS o ENTREGADOS.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Factura WHERE PedidoId = @PedidoId)
        THROW 50023, 'El pedido ya tiene factura emitida (relacion 1:1).', 1;

    SET @TipoComprobante = ISNULL(@TipoComprobante, CASE WHEN @TipoDoc = 'CUIT' THEN 'A' ELSE 'B' END);
    IF @TipoComprobante NOT IN ('A','B','C')
        THROW 50024, 'Tipo de comprobante invalido (A, B o C).', 1;

    DECLARE @Neto DECIMAL(14,2) = (SELECT Total FROM dbo.vw_PedidoTotal WHERE PedidoId = @PedidoId);
    IF @Neto IS NULL
        THROW 50025, 'El pedido no tiene renglones: no hay importe para facturar.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Nro INT = 1 + ISNULL((
            SELECT MAX(NroComprobante)
            FROM dbo.Factura WITH (UPDLOCK, HOLDLOCK)
            WHERE TipoComprobante = @TipoComprobante AND PuntoVenta = @PuntoVenta), 0);

        INSERT INTO dbo.Factura (PedidoId, TipoComprobante, PuntoVenta, NroComprobante, Neto, AlicuotaIva)
        VALUES (@PedidoId, @TipoComprobante, @PuntoVenta, @Nro, @Neto, @AlicuotaIva);
        SET @FacturaId = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @FacturaId = NULL;
        THROW;
    END CATCH;
END;
GO

/* ==========================================================================
   P3. sp_RegistrarPago
   Registra un pago (total o parcial) sobre una factura. El numero de pago
   es correlativo dentro de la factura (entidad debil). El control de que no
   se cobre de mas lo hace T4, de modo que rige tambien para INSERT directos.
   ========================================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarPago
    @FacturaId   INT,
    @Monto       DECIMAL(14,2),
    @MedioPagoId INT,
    @Referencia  NVARCHAR(40) = NULL,
    @NroPago     TINYINT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Factura WHERE FacturaId = @FacturaId)
        THROW 50031, 'La factura no existe.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.MedioPago WHERE MedioPagoId = @MedioPagoId AND Activo = 1)
        THROW 50032, 'El medio de pago no existe o esta inactivo.', 1;
    IF @Monto IS NULL OR @Monto <= 0
        THROW 50033, 'El monto del pago debe ser mayor que cero.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        SET @NroPago = 1 + ISNULL((SELECT MAX(NroPago) FROM dbo.Pago WITH (UPDLOCK, HOLDLOCK)
                                   WHERE FacturaId = @FacturaId), 0);

        INSERT INTO dbo.Pago (FacturaId, NroPago, Monto, MedioPagoId, Referencia)
        VALUES (@FacturaId, @NroPago, @Monto, @MedioPagoId, @Referencia);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @NroPago = NULL;
        THROW;
    END CATCH;
END;
GO

/* ==========================================================================
   P4. sp_ActualizarPrecioProducto
   Cambia el precio de venta de un producto conservando el historial:
   cierra el periodo vigente el dia anterior a @FechaDesde y abre uno nuevo.
   Ambas operaciones van en una transaccion: nunca puede quedar un producto
   con dos precios vigentes ni sin ninguno.
   ========================================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_ActualizarPrecioProducto
    @ProductoId  INT,
    @PrecioVenta DECIMAL(12,2),
    @PrecioCosto DECIMAL(12,2) = NULL,
    @FechaDesde  DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Hoy DATE = CAST(SYSDATETIME() AS DATE);
    SET @FechaDesde = ISNULL(@FechaDesde, @Hoy);

    IF NOT EXISTS (SELECT 1 FROM dbo.Producto WHERE ProductoId = @ProductoId AND Activo = 1)
        THROW 50041, 'El producto no existe o esta discontinuado.', 1;
    IF @PrecioVenta IS NULL OR @PrecioVenta <= 0
        THROW 50042, 'El precio de venta debe ser mayor que cero.', 1;
    IF @PrecioCosto IS NOT NULL AND @PrecioCosto < 0
        THROW 50042, 'El precio de costo no puede ser negativo.', 1;
    IF @FechaDesde > @Hoy
        THROW 50043, 'No se admiten precios con vigencia futura.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @DesdeVigente DATE, @PrecioActual DECIMAL(12,2), @CostoActual DECIMAL(12,2);
        SELECT @DesdeVigente = FechaDesde, @PrecioActual = PrecioVenta, @CostoActual = PrecioCosto
        FROM dbo.ProductoPrecio WITH (UPDLOCK, HOLDLOCK)
        WHERE ProductoId = @ProductoId AND FechaHasta IS NULL;

        IF @PrecioActual = @PrecioVenta AND ISNULL(@PrecioCosto, @CostoActual) = @CostoActual
            THROW 50044, 'El precio informado es igual al vigente: no hay cambio que registrar.', 1;

        /* FechaHasta es inclusiva y debe ser posterior a FechaDesde
           (CK_ProductoPrecio_Periodo): el periodo vigente debe haber durado
           al menos dos dias. */
        IF @DesdeVigente IS NOT NULL AND DATEADD(DAY, -1, @FechaDesde) <= @DesdeVigente
            THROW 50045, 'La nueva vigencia debe comenzar al menos dos dias despues del inicio del precio vigente.', 1;

        IF @DesdeVigente IS NOT NULL
            UPDATE dbo.ProductoPrecio
               SET FechaHasta = DATEADD(DAY, -1, @FechaDesde)
             WHERE ProductoId = @ProductoId AND FechaDesde = @DesdeVigente;

        INSERT INTO dbo.ProductoPrecio (ProductoId, FechaDesde, FechaHasta, PrecioVenta, PrecioCosto)
        VALUES (@ProductoId, @FechaDesde, NULL, @PrecioVenta, ISNULL(@PrecioCosto, @CostoActual));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ==========================================================================
   P5. sp_CancelarPedido
   Anula un pedido no facturado. Por cada EGRESO de kardex que genero el
   pedido registra el INGRESO compensatorio (T1 repone el stock) y luego
   cambia el estado a CANCELADO (T3 valida y audita). Todo o nada.
   ========================================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_CancelarPedido
    @PedidoId   INT,
    @EmpleadoId INT,
    @Motivo     NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Estado NVARCHAR(12), @NroPedido NVARCHAR(16);
    SELECT @Estado = Estado, @NroPedido = NroPedido FROM dbo.Pedido WHERE PedidoId = @PedidoId;

    IF @Estado IS NULL
        THROW 50051, 'El pedido no existe.', 1;
    IF @Estado NOT IN ('PENDIENTE','CONFIRMADO')
        THROW 50052, 'Solo pueden cancelarse pedidos PENDIENTES o CONFIRMADOS.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Factura WHERE PedidoId = @PedidoId)
        THROW 50053, 'El pedido esta facturado: requiere nota de credito, no cancelacion.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Empleado WHERE EmpleadoId = @EmpleadoId AND Activo = 1)
        THROW 50054, 'El empleado no existe o esta inactivo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.MovimientoStock (ProductoId, DepositoId, TipoMovimiento, Cantidad, EmpleadoId,
                                         Motivo, DocumentoTipo, DocumentoId)
        SELECT m.ProductoId, m.DepositoId, 'INGRESO', SUM(m.Cantidad), @EmpleadoId,
               LEFT(CONCAT('Anulacion ', @NroPedido, ISNULL(': ' + @Motivo, '')), 200),
               'PEDIDO', @PedidoId
        FROM dbo.MovimientoStock AS m
        WHERE m.DocumentoTipo = 'PEDIDO' AND m.DocumentoId = @PedidoId
          AND m.TipoMovimiento = 'EGRESO'
        GROUP BY m.ProductoId, m.DepositoId;

        UPDATE dbo.Pedido SET Estado = 'CANCELADO' WHERE PedidoId = @PedidoId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

PRINT 'Objetos programados creados: 3 funciones, 5 procedimientos, 5 triggers.';
GO
