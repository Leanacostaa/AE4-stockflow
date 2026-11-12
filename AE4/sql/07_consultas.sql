/* ==========================================================================
   AE4 - ISI17BAD28V26AE4V26 - Proyecto StockFlow
   Archivo: 07_consultas.sql  -- Consultas SQL y uso de vistas
   Ejecutar DESPUES de 06_manipulacion_dml.sql
   --------------------------------------------------------------------------
   Cada consulta responde a un requerimiento de informacion (RI) del
   sistema. Indice:
     C01 simple (WHERE, ORDER BY)                         RI02
     C02 simple con tratamiento de NULL (IS NULL, ISNULL)  RI01
     C03 multitabla INNER JOIN (6 tablas)                  RI07
     C04 multitabla LEFT JOIN + NULL (COALESCE)            RI02, RI08
     C05 agregacion COUNT, SUM, AVG, MIN, MAX              RI15
     C06 GROUP BY por sucursal y canal                     RI15
     C07 GROUP BY + HAVING por categoria                   RI15
     C08 GROUP BY + HAVING por cliente                     RI01, RI15
     C09 subconsulta escalar                               RI02
     C10 subconsulta NOT EXISTS                            RI02
     C11 subconsulta IN + vista                            RI05, RI08
     C12 subconsulta correlacionada                        RI06
     C13 EXISTS + agregacion de saldos                     RI12
     C14 funcion en consulta: precio cobrado vs vigente    RI07, RI09
     C15 funcion de stock por deposito                     RI04
     C16 ranking con funciones de ventana                  RI15
     C17 auditoria de estados                              RI14
     C18 vistas: catalogo y cartera de clientes            RI02, RI01
     C19 UPDATE con subconsulta                            RI11
     C20 DELETE con subconsulta                            RI05
   ========================================================================== */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE StockFlow;
GO
SET NOCOUNT ON;
GO

/* C01 - Catalogo de perifericos activos, ordenado por nombre. */
SELECT 'C01' AS Consulta, Sku, Nombre, UnidadMedida, PesoKg
FROM dbo.Producto
WHERE CategoriaId = (SELECT CategoriaId FROM dbo.Categoria WHERE Nombre = N'Perifericos')
  AND Activo = 1
ORDER BY Nombre;
GO

/* C02 - Clientes sin email registrado: no pueden recibir la factura
   electronica. ISNULL presenta el dato faltante de forma legible. */
SELECT 'C02' AS Consulta, ClienteId, CONCAT(Apellido, N', ', Nombre) AS Cliente,
       ISNULL(Email, N'(sin email)') AS Email, FechaAlta
FROM dbo.Cliente
WHERE Email IS NULL
ORDER BY Apellido;
GO

/* C03 - Detalle de ventas: quien compro que, quien lo vendio y donde
   (pedidos no cancelados). */
SELECT 'C03' AS Consulta, p.NroPedido, CAST(p.FechaPedido AS DATE) AS Fecha,
       CONCAT(c.Apellido, N', ', c.Nombre) AS Cliente,
       e.Apellido AS Vendedor, su.Nombre AS Sucursal,
       pr.Sku, pd.Cantidad, pd.PrecioUnitarioHistorico, pd.DescuentoPct,
       CAST(pd.Cantidad * pd.PrecioUnitarioHistorico * (1 - pd.DescuentoPct / 100.0) AS DECIMAL(14,2)) AS Subtotal
FROM dbo.Pedido AS p
INNER JOIN dbo.Cliente       AS c  ON c.ClienteId   = p.ClienteId
INNER JOIN dbo.Empleado      AS e  ON e.EmpleadoId  = p.EmpleadoId
INNER JOIN dbo.Sucursal      AS su ON su.SucursalId = p.SucursalId
INNER JOIN dbo.PedidoDetalle AS pd ON pd.PedidoId   = p.PedidoId
INNER JOIN dbo.Producto      AS pr ON pr.ProductoId = pd.ProductoId
WHERE p.Estado <> 'CANCELADO'
ORDER BY p.NroPedido, pr.Sku;
GO

/* C04 - Productos con datos incompletos para la venta: sin precio vigente
   o sin existencias en ningun deposito. El LEFT JOIN conserva los productos
   sin coincidencia y COALESCE reemplaza los NULL resultantes. */
SELECT 'C04' AS Consulta, p.Sku, p.Nombre,
       COALESCE(CONVERT(NVARCHAR(20), pv.PrecioVenta), N'SIN PRECIO') AS PrecioVigente,
       COALESCE(SUM(s.Cantidad), 0) AS StockTotal,
       CASE WHEN p.Activo = 1 THEN 'ACTIVO' ELSE 'DISCONTINUADO' END AS Situacion
FROM dbo.Producto AS p
LEFT JOIN dbo.vw_ProductoPrecioVigente AS pv ON pv.ProductoId = p.ProductoId
LEFT JOIN dbo.Stock AS s ON s.ProductoId = p.ProductoId
GROUP BY p.Sku, p.Nombre, pv.PrecioVenta, p.Activo
HAVING pv.PrecioVenta IS NULL OR COALESCE(SUM(s.Cantidad), 0) = 0;
GO

/* C05 - Indicadores globales de ventas (pedidos no cancelados). */
SELECT 'C05' AS Consulta,
       COUNT(*)          AS Pedidos,
       SUM(t.Total)      AS VentasNetas,
       AVG(t.Total)      AS TicketPromedio,
       MIN(t.Total)      AS TicketMinimo,
       MAX(t.Total)      AS TicketMaximo,
       (SELECT SUM(pd.Cantidad) FROM dbo.PedidoDetalle pd
        JOIN dbo.Pedido p2 ON p2.PedidoId = pd.PedidoId
        WHERE p2.Estado <> 'CANCELADO') AS UnidadesVendidas
FROM dbo.vw_PedidoTotal AS t
JOIN dbo.Pedido AS p ON p.PedidoId = t.PedidoId
WHERE p.Estado <> 'CANCELADO';
GO

/* C06 - Ventas por sucursal y canal. */
SELECT 'C06' AS Consulta, su.Nombre AS Sucursal, p.Canal,
       COUNT(*) AS Pedidos, SUM(t.Total) AS VentasNetas, AVG(t.Total) AS TicketPromedio
FROM dbo.Pedido AS p
JOIN dbo.Sucursal AS su ON su.SucursalId = p.SucursalId
JOIN dbo.vw_PedidoTotal AS t ON t.PedidoId = p.PedidoId
WHERE p.Estado <> 'CANCELADO'
GROUP BY su.Nombre, p.Canal
ORDER BY su.Nombre, VentasNetas DESC;
GO

/* C07 - Categorias cuya venta neta supera $1.000.000 (HAVING filtra
   grupos; WHERE filtraria filas). Se informa la categoria padre. */
SELECT 'C07' AS Consulta, ISNULL(cp.Nombre, c.Nombre) AS Rubro, c.Nombre AS Categoria,
       COUNT(DISTINCT pd.PedidoId) AS Pedidos, SUM(pd.Cantidad) AS Unidades,
       SUM(CAST(pd.Cantidad * pd.PrecioUnitarioHistorico * (1 - pd.DescuentoPct / 100.0) AS DECIMAL(16,2))) AS VentaNeta
FROM dbo.PedidoDetalle AS pd
JOIN dbo.Pedido    AS p  ON p.PedidoId    = pd.PedidoId
JOIN dbo.Producto  AS pr ON pr.ProductoId = pd.ProductoId
JOIN dbo.Categoria AS c  ON c.CategoriaId = pr.CategoriaId
LEFT JOIN dbo.Categoria AS cp ON cp.CategoriaId = c.CategoriaPadreId
WHERE p.Estado <> 'CANCELADO'
GROUP BY cp.Nombre, c.Nombre
HAVING SUM(pd.Cantidad * pd.PrecioUnitarioHistorico * (1 - pd.DescuentoPct / 100.0)) > 1000000
ORDER BY VentaNeta DESC;
GO

/* C08 - Clientes recurrentes: mas de un pedido no cancelado. */
SELECT 'C08' AS Consulta, c.ClienteId, CONCAT(c.Apellido, N', ', c.Nombre) AS Cliente,
       COUNT(*) AS Pedidos, SUM(t.Total) AS TotalComprado
FROM dbo.Cliente AS c
JOIN dbo.Pedido AS p ON p.ClienteId = c.ClienteId
JOIN dbo.vw_PedidoTotal AS t ON t.PedidoId = p.PedidoId
WHERE p.Estado <> 'CANCELADO'
GROUP BY c.ClienteId, c.Apellido, c.Nombre
HAVING COUNT(*) > 1
ORDER BY TotalComprado DESC;
GO

/* C09 - Productos cuyo precio vigente supera el promedio del catalogo
   (subconsulta escalar no correlacionada). */
SELECT 'C09' AS Consulta, p.Sku, p.Nombre, pv.PrecioVenta,
       (SELECT CAST(AVG(PrecioVenta) AS DECIMAL(12,2)) FROM dbo.vw_ProductoPrecioVigente) AS PromedioCatalogo
FROM dbo.Producto AS p
JOIN dbo.vw_ProductoPrecioVigente AS pv ON pv.ProductoId = p.ProductoId
WHERE pv.PrecioVenta > (SELECT AVG(PrecioVenta) FROM dbo.vw_ProductoPrecioVigente)
ORDER BY pv.PrecioVenta DESC;
GO

/* C10 - Productos activos que nunca se vendieron (NOT EXISTS). */
SELECT 'C10' AS Consulta, p.Sku, p.Nombre, dbo.fn_StockDisponible(p.ProductoId, NULL) AS StockTotal
FROM dbo.Producto AS p
WHERE p.Activo = 1
  AND NOT EXISTS (SELECT 1 FROM dbo.PedidoDetalle AS pd
                  JOIN dbo.Pedido AS pe ON pe.PedidoId = pd.PedidoId
                  WHERE pd.ProductoId = p.ProductoId AND pe.Estado <> 'CANCELADO')
ORDER BY p.Sku;
GO

/* C11 - A quien reponer: proveedor preferido de cada producto que esta
   bajo minimo en algun deposito (subconsulta IN sobre una vista). */
SELECT 'C11' AS Consulta, pr.RazonSocial, p.Sku, pp.PrecioCompra, pp.PlazoEntregaDias
FROM dbo.ProveedorProducto AS pp
JOIN dbo.Proveedor AS pr ON pr.ProveedorId = pp.ProveedorId
JOIN dbo.Producto  AS p  ON p.ProductoId   = pp.ProductoId
WHERE pp.EsPreferido = 1
  AND pp.ProductoId IN (SELECT ProductoId FROM dbo.vw_StockBajoMinimo)
ORDER BY pr.RazonSocial;
GO

/* C12 - Ultimo pedido de cada cliente (subconsulta correlacionada: se
   evalua una vez por cada fila externa). */
SELECT 'C12' AS Consulta, CONCAT(c.Apellido, N', ', c.Nombre) AS Cliente, p.NroPedido, p.FechaPedido, p.Estado
FROM dbo.Pedido AS p
JOIN dbo.Cliente AS c ON c.ClienteId = p.ClienteId
WHERE p.FechaPedido = (SELECT MAX(p2.FechaPedido) FROM dbo.Pedido AS p2
                       WHERE p2.ClienteId = p.ClienteId)
ORDER BY p.FechaPedido DESC;
GO

/* C13 - Cuentas a cobrar: clientes con al menos una factura con saldo y
   con telefono de contacto para gestionar la cobranza (EXISTS). */
SELECT 'C13' AS Consulta, c.ClienteId, CONCAT(c.Apellido, N', ', c.Nombre) AS Cliente,
       CAST(SUM(s.SaldoPendiente) AS DECIMAL(16,2)) AS Deuda, COUNT(*) AS FacturasConSaldo
FROM dbo.Cliente AS c
JOIN dbo.Pedido AS p ON p.ClienteId = c.ClienteId
JOIN dbo.Factura AS f ON f.PedidoId = p.PedidoId
JOIN dbo.vw_FacturaSaldo AS s ON s.FacturaId = f.FacturaId
WHERE s.SaldoPendiente > 0
  AND EXISTS (SELECT 1 FROM dbo.ClienteTelefono ct WHERE ct.ClienteId = c.ClienteId)
GROUP BY c.ClienteId, c.Apellido, c.Nombre
ORDER BY Deuda DESC;
GO

/* C14 - Precio cobrado frente al precio de lista de la fecha de venta y
   frente al precio vigente hoy (fn_PrecioVigente). Evidencia de RN06: el
   precio historico del renglon no cambia aunque cambie la lista. */
SELECT 'C14' AS Consulta, p.NroPedido, CAST(p.FechaPedido AS DATE) AS Fecha, pr.Sku,
       pd.PrecioUnitarioHistorico AS PrecioCobrado,
       dbo.fn_PrecioVigente(pd.ProductoId, CAST(p.FechaPedido AS DATE)) AS PrecioListaEseDia,
       dbo.fn_PrecioVigente(pd.ProductoId, NULL) AS PrecioListaHoy
FROM dbo.PedidoDetalle AS pd
JOIN dbo.Pedido   AS p  ON p.PedidoId    = pd.PedidoId
JOIN dbo.Producto AS pr ON pr.ProductoId = pd.ProductoId
WHERE pd.PrecioUnitarioHistorico <> dbo.fn_PrecioVigente(pd.ProductoId, NULL)
ORDER BY p.NroPedido;
GO

/* C15 - Disponibilidad de los productos de Informatica por deposito y
   total (fn_StockDisponible). */
SELECT 'C15' AS Consulta, p.Sku,
       dbo.fn_StockDisponible(p.ProductoId, 1) AS Central,
       dbo.fn_StockDisponible(p.ProductoId, 2) AS SalonCC,
       dbo.fn_StockDisponible(p.ProductoId, 3) AS Norte,
       dbo.fn_StockDisponible(p.ProductoId, 4) AS Obera,
       dbo.fn_StockDisponible(p.ProductoId, NULL) AS Total
FROM dbo.Producto AS p
JOIN dbo.Categoria AS c ON c.CategoriaId = p.CategoriaId
WHERE c.CategoriaPadreId = (SELECT CategoriaId FROM dbo.Categoria WHERE Nombre = N'Informatica')
  AND p.Activo = 1
ORDER BY p.Sku;
GO

/* C16 - Ranking de productos por venta neta (RANK) y participacion
   porcentual sobre el total (SUM OVER). */
SELECT 'C16' AS Consulta,
       RANK() OVER (ORDER BY v.VentaNeta DESC) AS Puesto,
       v.Sku, v.Unidades, v.VentaNeta,
       CAST(100.0 * v.VentaNeta / SUM(v.VentaNeta) OVER () AS DECIMAL(5,2)) AS PorcentajeDelTotal
FROM (SELECT pr.Sku, SUM(pd.Cantidad) AS Unidades,
             SUM(CAST(pd.Cantidad * pd.PrecioUnitarioHistorico * (1 - pd.DescuentoPct / 100.0) AS DECIMAL(16,2))) AS VentaNeta
      FROM dbo.PedidoDetalle AS pd
      JOIN dbo.Pedido   AS p  ON p.PedidoId    = pd.PedidoId
      JOIN dbo.Producto AS pr ON pr.ProductoId = pd.ProductoId
      WHERE p.Estado <> 'CANCELADO'
      GROUP BY pr.Sku) AS v
ORDER BY Puesto;
GO

/* C17 - Trazabilidad de un pedido anulado: estados, momentos y usuario,
   junto con los movimientos de stock que genero y revirtio. */
SELECT 'C17 estados' AS Consulta, p.NroPedido, h.EstadoAnterior, h.EstadoNuevo, h.FechaHora
FROM dbo.PedidoEstadoHistorial AS h
JOIN dbo.Pedido AS p ON p.PedidoId = h.PedidoId
WHERE p.Estado = 'CANCELADO'
ORDER BY h.HistorialId;

SELECT 'C17 kardex' AS Consulta, p.NroPedido, m.TipoMovimiento, pr.Sku, m.Cantidad, m.Motivo
FROM dbo.MovimientoStock AS m
JOIN dbo.Pedido   AS p  ON p.PedidoId    = m.DocumentoId AND m.DocumentoTipo = 'PEDIDO'
JOIN dbo.Producto AS pr ON pr.ProductoId = m.ProductoId
WHERE p.Estado = 'CANCELADO'
ORDER BY m.MovimientoId;
GO

/* C18 - Consultas sobre las vistas del sistema. */
SELECT 'C18 catalogo' AS Consulta, Sku, Producto, Categoria, Marca,
       ISNULL(CONVERT(NVARCHAR(20), PrecioVigente), N'-') AS PrecioVigente, StockTotal, ProveedorPreferido
FROM dbo.vw_CatalogoProductos
WHERE Activo = 1
ORDER BY Categoria, Producto;

SELECT 'C18 cartera' AS Consulta, Cliente, Documento, Email, CantidadPedidos,
       TotalComprado, UltimaCompra, CAST(SaldoPendiente AS DECIMAL(16,2)) AS SaldoPendiente
FROM dbo.vw_ResumenVentasCliente
ORDER BY TotalComprado DESC;
GO

/* C19 - UPDATE con subconsulta: anular ordenes de compra en BORRADOR con
   mas de 30 dias de antiguedad y sin mercaderia recibida. */
UPDATE dbo.OrdenCompra
   SET Estado = 'ANULADA'
 WHERE Estado = 'BORRADOR'
   AND FechaEmision < DATEADD(DAY, -30, CAST(SYSDATETIME() AS DATE))
   AND NOT EXISTS (SELECT 1 FROM dbo.OrdenCompraDetalle d
                   WHERE d.OrdenCompraId = dbo.OrdenCompra.OrdenCompraId AND d.CantidadRecibida > 0);
PRINT CONCAT('C19 ordenes de compra anuladas: ', @@ROWCOUNT);
SELECT 'C19' AS Consulta, NroOrden, FechaEmision, Estado FROM dbo.OrdenCompra ORDER BY NroOrden;
GO

/* C20 - DELETE con subconsulta: dar de baja los numeros de FAX de los
   proveedores que conservan un telefono PRINCIPAL. */
DELETE FROM dbo.ProveedorTelefono
 WHERE Tipo = 'FAX'
   AND ProveedorId IN (SELECT ProveedorId FROM dbo.ProveedorTelefono WHERE Tipo = 'PRINCIPAL');
PRINT CONCAT('C20 telefonos de fax eliminados: ', @@ROWCOUNT);
SELECT 'C20' AS Consulta, ProveedorId, NroTelefono, Telefono, Tipo
FROM dbo.ProveedorTelefono ORDER BY ProveedorId, NroTelefono;
GO

PRINT 'Consultas finalizadas.';
GO
