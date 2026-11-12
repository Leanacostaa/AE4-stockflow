/* ==========================================================================
   AE4 - ISI17BAD28V26AE4V26 - Proyecto StockFlow
   Archivo: 05_vistas.sql  -- Vistas de informacion para el sistema
   Ejecutar DESPUES de 04_programacion.sql (usan las funciones F1-F3).
   --------------------------------------------------------------------------
   Las seis vistas del AE2 (atributos derivados) se crean en 01_ddl.sql.
   Estas tres responden a necesidades de consulta del sistema y son las que
   consume la aplicacion web StockFlow:
     V1 vw_CatalogoProductos     catalogo con precio vigente, stock y proveedor
     V2 vw_StockPorDeposito      existencias por deposito y alerta de minimo
     V3 vw_ResumenVentasCliente  cartera de clientes: compras y deuda
   ========================================================================== */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE StockFlow;
GO

/* V1. Catalogo comercial (RI02, RI04). Un producto sin precio o sin stock
   igual aparece (LEFT JOIN); los NULL se muestran de forma explicita. */
CREATE OR ALTER VIEW dbo.vw_CatalogoProductos AS
SELECT p.ProductoId,
       p.Sku,
       p.Nombre                                   AS Producto,
       c.Nombre                                   AS Categoria,
       ISNULL(m.Nombre, N'(sin marca)')           AS Marca,
       pv.PrecioVenta                             AS PrecioVigente,
       dbo.fn_StockDisponible(p.ProductoId, NULL) AS StockTotal,
       ISNULL(pr.RazonSocial, N'(sin proveedor preferido)') AS ProveedorPreferido,
       p.Activo
FROM dbo.Producto AS p
JOIN dbo.Categoria AS c ON c.CategoriaId = p.CategoriaId
LEFT JOIN dbo.Marca AS m ON m.MarcaId = p.MarcaId
LEFT JOIN dbo.vw_ProductoPrecioVigente AS pv ON pv.ProductoId = p.ProductoId
LEFT JOIN dbo.ProveedorProducto AS pp ON pp.ProductoId = p.ProductoId AND pp.EsPreferido = 1
LEFT JOIN dbo.Proveedor AS pr ON pr.ProveedorId = pp.ProveedorId;
GO

/* V2. Existencias por deposito con semaforo de reposicion (RI04, RI08). */
CREATE OR ALTER VIEW dbo.vw_StockPorDeposito AS
SELECT d.DepositoId,
       d.Nombre        AS Deposito,
       su.Nombre       AS Sucursal,
       d.CapacidadMaxima,
       s.ProductoId,
       p.Sku,
       p.Nombre        AS Producto,
       s.Cantidad,
       s.StockMinimo,
       s.StockMaximo,
       s.UbicacionInterna,
       CASE WHEN s.Cantidad = 0              THEN 'SIN STOCK'
            WHEN s.Cantidad < s.StockMinimo  THEN 'BAJO MINIMO'
            ELSE 'OK' END AS EstadoStock
FROM dbo.Stock AS s
JOIN dbo.Deposito AS d  ON d.DepositoId = s.DepositoId
JOIN dbo.Sucursal AS su ON su.SucursalId = d.SucursalId
JOIN dbo.Producto AS p  ON p.ProductoId = s.ProductoId;
GO

/* V3. Resumen comercial por cliente (RI01, RI06). Evolucion de
   vw_ResumenVentasClientes del borrador: incluye a los clientes sin pedidos
   (LEFT JOIN), excluye pedidos cancelados y agrega la deuda pendiente. */
CREATE OR ALTER VIEW dbo.vw_ResumenVentasCliente AS
SELECT c.ClienteId,
       CONCAT(c.Apellido, N', ', c.Nombre)        AS Cliente,
       CONCAT(c.TipoDoc, N' ', c.NroDoc)          AS Documento,
       ISNULL(c.Email, N'(sin email)')            AS Email,
       COUNT(p.PedidoId)                          AS CantidadPedidos,
       dbo.fn_TotalCompradoCliente(c.ClienteId)   AS TotalComprado,
       MAX(p.FechaPedido)                         AS UltimaCompra,
       ISNULL((SELECT SUM(fs.SaldoPendiente)
               FROM dbo.vw_FacturaSaldo AS fs
               JOIN dbo.Factura AS f  ON f.FacturaId = fs.FacturaId
               JOIN dbo.Pedido  AS p2 ON p2.PedidoId = f.PedidoId
               WHERE p2.ClienteId = c.ClienteId), 0) AS SaldoPendiente
FROM dbo.Cliente AS c
LEFT JOIN dbo.Pedido AS p ON p.ClienteId = c.ClienteId AND p.Estado <> 'CANCELADO'
GROUP BY c.ClienteId, c.Apellido, c.Nombre, c.TipoDoc, c.NroDoc, c.Email;
GO

PRINT 'Vistas AE4 creadas: vw_CatalogoProductos, vw_StockPorDeposito, vw_ResumenVentasCliente.';
GO
