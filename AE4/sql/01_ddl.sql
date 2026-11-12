/* ==========================================================================
   AE4 - Trabajo Final Integrador - Base de Datos (ISI17BAD28V26AE4V26)
   Proyecto : StockFlow - Gestion de stock, compras y ventas
   Motor    : Microsoft SQL Server 2022 (T-SQL)
   Archivo  : 01_ddl.sql  -- Lenguaje de definicion de datos (DDL)
   --------------------------------------------------------------------------
   Origen   : esquema relacional normalizado (3FN) del AE2 (22 tablas), sin
              cambios estructurales, mas la ampliacion de la seccion 8
              (tabla de auditoria PedidoEstadoHistorial, incorporada en AE4).
   Cambio   : la base se llama StockFlow (en AE2: GestionStockVentas) para
              que ambas versiones puedan convivir en el mismo servidor.
   Orden    : 01_ddl -> 02_datos_prueba -> 03_pruebas_integridad
              -> 04_programacion -> 05_vistas -> 06_manipulacion_dml
              -> 07_consultas -> 08_pruebas_programacion
   ========================================================================== */

/* Opciones de sesion requeridas por los indices filtrados, las columnas
   calculadas y los modulos programados. SSMS las activa por defecto, pero
   sqlcmd no: se fijan explicitamente para que el script sea portable. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE master;
GO

IF DB_ID('StockFlow') IS NOT NULL
BEGIN
    ALTER DATABASE StockFlow SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE StockFlow;
END
GO

/* Collation Modern_Spanish_CI_AI: comparaciones sin distinguir mayusculas ni
   acentos, de modo que 'Monitor' = 'MONITOR' = 'monitór' en busquedas. */
CREATE DATABASE StockFlow COLLATE Modern_Spanish_CI_AI;
GO

USE StockFlow;
GO
SET NOCOUNT ON;
GO

/* ==========================================================================
   1. ORGANIZACION
   ========================================================================== */

CREATE TABLE dbo.Sucursal (
    SucursalId   INT            NOT NULL IDENTITY(1,1),
    Nombre       NVARCHAR(80)   NOT NULL,
    Calle        NVARCHAR(120)  NOT NULL,
    Numero       NVARCHAR(10)   NOT NULL,
    Ciudad       NVARCHAR(60)   NOT NULL,
    Provincia    NVARCHAR(60)   NOT NULL,
    Telefono     NVARCHAR(30)   NULL,
    Activa       BIT            NOT NULL CONSTRAINT DF_Sucursal_Activa DEFAULT (1),
    CONSTRAINT PK_Sucursal PRIMARY KEY (SucursalId),
    CONSTRAINT UQ_Sucursal_Nombre UNIQUE (Nombre)
);
GO

CREATE TABLE dbo.Empleado (
    EmpleadoId    INT           NOT NULL IDENTITY(1,1),
    Legajo        NVARCHAR(12)  NOT NULL,
    Nombre        NVARCHAR(60)  NOT NULL,
    Apellido      NVARCHAR(60)  NOT NULL,
    Dni           NVARCHAR(12)  NOT NULL,
    Email         NVARCHAR(120) NOT NULL,
    FechaIngreso  DATE          NOT NULL,
    Rol           NVARCHAR(20)  NOT NULL,
    SucursalId    INT           NOT NULL,
    SupervisorId  INT           NULL,
    Activo        BIT           NOT NULL CONSTRAINT DF_Empleado_Activo DEFAULT (1),
    CONSTRAINT PK_Empleado        PRIMARY KEY (EmpleadoId),
    CONSTRAINT UQ_Empleado_Legajo UNIQUE (Legajo),
    CONSTRAINT UQ_Empleado_Dni    UNIQUE (Dni),
    CONSTRAINT UQ_Empleado_Email  UNIQUE (Email),
    CONSTRAINT FK_Empleado_Sucursal   FOREIGN KEY (SucursalId)
        REFERENCES dbo.Sucursal (SucursalId) ON DELETE NO ACTION,
    /* Autorrelacion: SQL Server exige NO ACTION, una cascada sobre la propia
       tabla produciria un ciclo (error 1785). */
    CONSTRAINT FK_Empleado_Supervisor FOREIGN KEY (SupervisorId)
        REFERENCES dbo.Empleado (EmpleadoId) ON DELETE NO ACTION,
    CONSTRAINT CK_Empleado_Rol CHECK (Rol IN ('VENDEDOR','DEPOSITO','COMPRAS','ADMIN','GERENTE')),
    CONSTRAINT CK_Empleado_Dni CHECK (Dni NOT LIKE '%[^0-9]%' AND LEN(Dni) BETWEEN 7 AND 9),
    CONSTRAINT CK_Empleado_Email CHECK (Email LIKE '%_@_%._%'),
    /* Nadie se supervisa a si mismo. */
    CONSTRAINT CK_Empleado_NoAutoSupervision CHECK (SupervisorId <> EmpleadoId)
);
GO

/* ==========================================================================
   2. CATALOGO
   ========================================================================== */

CREATE TABLE dbo.Categoria (
    CategoriaId      INT           NOT NULL IDENTITY(1,1),
    Nombre           NVARCHAR(80)  NOT NULL,
    Descripcion      NVARCHAR(250) NULL,
    CategoriaPadreId INT           NULL,
    CONSTRAINT PK_Categoria        PRIMARY KEY (CategoriaId),
    CONSTRAINT UQ_Categoria_Nombre UNIQUE (Nombre),
    CONSTRAINT FK_Categoria_Padre  FOREIGN KEY (CategoriaPadreId)
        REFERENCES dbo.Categoria (CategoriaId) ON DELETE NO ACTION,
    CONSTRAINT CK_Categoria_NoAutoPadre CHECK (CategoriaPadreId <> CategoriaId)
);
GO

CREATE TABLE dbo.Marca (
    MarcaId    INT          NOT NULL IDENTITY(1,1),
    Nombre     NVARCHAR(80) NOT NULL,
    PaisOrigen NVARCHAR(60) NULL,
    CONSTRAINT PK_Marca        PRIMARY KEY (MarcaId),
    CONSTRAINT UQ_Marca_Nombre UNIQUE (Nombre)
);
GO

CREATE TABLE dbo.Producto (
    ProductoId   INT            NOT NULL IDENTITY(1,1),
    Sku          NVARCHAR(30)   NOT NULL,
    Nombre       NVARCHAR(120)  NOT NULL,
    Descripcion  NVARCHAR(400)  NULL,
    CategoriaId  INT            NOT NULL,
    MarcaId      INT            NULL,
    UnidadMedida NVARCHAR(10)   NOT NULL CONSTRAINT DF_Producto_Unidad DEFAULT ('UN'),
    PesoKg       DECIMAL(10,3)  NULL,
    Activo       BIT            NOT NULL CONSTRAINT DF_Producto_Activo DEFAULT (1),
    CONSTRAINT PK_Producto     PRIMARY KEY (ProductoId),
    CONSTRAINT UQ_Producto_Sku UNIQUE (Sku),
    CONSTRAINT FK_Producto_Categoria FOREIGN KEY (CategoriaId)
        REFERENCES dbo.Categoria (CategoriaId) ON DELETE NO ACTION,
    CONSTRAINT FK_Producto_Marca FOREIGN KEY (MarcaId)
        REFERENCES dbo.Marca (MarcaId) ON DELETE NO ACTION,
    CONSTRAINT CK_Producto_Unidad CHECK (UnidadMedida IN ('UN','KG','LT','MT','CJ')),
    CONSTRAINT CK_Producto_Peso   CHECK (PesoKg IS NULL OR PesoKg >= 0)
);
GO

/* Entidad debil: PK = clave del propietario + discriminante temporal. */
CREATE TABLE dbo.ProductoPrecio (
    ProductoId  INT           NOT NULL,
    FechaDesde  DATE          NOT NULL,
    FechaHasta  DATE          NULL,
    PrecioVenta DECIMAL(12,2) NOT NULL,
    PrecioCosto DECIMAL(12,2) NULL,
    CONSTRAINT PK_ProductoPrecio PRIMARY KEY (ProductoId, FechaDesde),
    CONSTRAINT FK_ProductoPrecio_Producto FOREIGN KEY (ProductoId)
        REFERENCES dbo.Producto (ProductoId) ON DELETE CASCADE,
    CONSTRAINT CK_ProductoPrecio_Venta   CHECK (PrecioVenta > 0),
    CONSTRAINT CK_ProductoPrecio_Costo   CHECK (PrecioCosto IS NULL OR PrecioCosto >= 0),
    CONSTRAINT CK_ProductoPrecio_Periodo CHECK (FechaHasta IS NULL OR FechaHasta > FechaDesde)
);
GO

/* Indice unico filtrado: a lo sumo un precio vigente (FechaHasta nula) por
   producto. Es una restriccion que un CHECK no puede expresar porque abarca
   varias filas; SQL Server la resuelve con un indice filtrado. */
CREATE UNIQUE INDEX UX_ProductoPrecio_Vigente
    ON dbo.ProductoPrecio (ProductoId)
    WHERE FechaHasta IS NULL;
GO

/* ==========================================================================
   3. STOCK
   ========================================================================== */

CREATE TABLE dbo.Deposito (
    DepositoId      INT           NOT NULL IDENTITY(1,1),
    Nombre          NVARCHAR(80)  NOT NULL,
    SucursalId      INT           NOT NULL,
    Calle           NVARCHAR(120) NULL,
    Ciudad          NVARCHAR(60)  NULL,
    Provincia       NVARCHAR(60)  NULL,
    CapacidadMaxima INT           NULL,
    CONSTRAINT PK_Deposito PRIMARY KEY (DepositoId),
    CONSTRAINT UQ_Deposito_Sucursal_Nombre UNIQUE (SucursalId, Nombre),
    CONSTRAINT FK_Deposito_Sucursal FOREIGN KEY (SucursalId)
        REFERENCES dbo.Sucursal (SucursalId) ON DELETE NO ACTION,
    CONSTRAINT CK_Deposito_Capacidad CHECK (CapacidadMaxima IS NULL OR CapacidadMaxima > 0)
);
GO

/* Tabla de la relacion N:M ALMACENA. Los cuatro atributos no clave son
   atributos de la RELACION, no de Producto ni de Deposito. */
CREATE TABLE dbo.Stock (
    ProductoId       INT           NOT NULL,
    DepositoId       INT           NOT NULL,
    Cantidad         DECIMAL(12,3) NOT NULL CONSTRAINT DF_Stock_Cantidad DEFAULT (0),
    StockMinimo      DECIMAL(12,3) NOT NULL CONSTRAINT DF_Stock_Minimo   DEFAULT (0),
    StockMaximo      DECIMAL(12,3) NULL,
    UbicacionInterna NVARCHAR(30)  NULL,
    CONSTRAINT PK_Stock PRIMARY KEY (ProductoId, DepositoId),
    CONSTRAINT FK_Stock_Producto FOREIGN KEY (ProductoId)
        REFERENCES dbo.Producto (ProductoId) ON DELETE NO ACTION,
    CONSTRAINT FK_Stock_Deposito FOREIGN KEY (DepositoId)
        REFERENCES dbo.Deposito (DepositoId) ON DELETE NO ACTION,
    CONSTRAINT CK_Stock_Cantidad CHECK (Cantidad >= 0),
    CONSTRAINT CK_Stock_Minimo   CHECK (StockMinimo >= 0),
    CONSTRAINT CK_Stock_Maximo   CHECK (StockMaximo IS NULL OR StockMaximo >= StockMinimo)
);
GO

/* Kardex. La FK es COMPUESTA contra Stock: un movimiento solo puede existir
   sobre un par (producto, deposito) que realmente este dado de alta. */
CREATE TABLE dbo.MovimientoStock (
    MovimientoId   BIGINT        NOT NULL IDENTITY(1,1),
    FechaHora      DATETIME2(0)  NOT NULL CONSTRAINT DF_Movimiento_Fecha DEFAULT (SYSDATETIME()),
    ProductoId     INT           NOT NULL,
    DepositoId     INT           NOT NULL,
    TipoMovimiento NVARCHAR(12)  NOT NULL,
    Cantidad       DECIMAL(12,3) NOT NULL,
    EmpleadoId     INT           NOT NULL,
    Motivo         NVARCHAR(200) NULL,
    DocumentoTipo  NVARCHAR(12)  NULL,
    DocumentoId    BIGINT        NULL,
    CONSTRAINT PK_MovimientoStock PRIMARY KEY (MovimientoId),
    CONSTRAINT FK_Movimiento_Stock FOREIGN KEY (ProductoId, DepositoId)
        REFERENCES dbo.Stock (ProductoId, DepositoId) ON DELETE NO ACTION,
    CONSTRAINT FK_Movimiento_Empleado FOREIGN KEY (EmpleadoId)
        REFERENCES dbo.Empleado (EmpleadoId) ON DELETE NO ACTION,
    CONSTRAINT CK_Movimiento_Tipo     CHECK (TipoMovimiento IN ('INGRESO','EGRESO','AJUSTE','TRANSFER')),
    CONSTRAINT CK_Movimiento_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_Movimiento_Doc      CHECK (DocumentoTipo IS NULL OR DocumentoTipo IN ('OC','PEDIDO','AJUSTE')),
    /* Si se referencia un documento, deben venir tipo e id juntos. */
    CONSTRAINT CK_Movimiento_DocCompleto CHECK
        ((DocumentoTipo IS NULL AND DocumentoId IS NULL)
         OR (DocumentoTipo IS NOT NULL AND DocumentoId IS NOT NULL))
);
GO

/* ==========================================================================
   4. COMPRAS
   ========================================================================== */

CREATE TABLE dbo.Proveedor (
    ProveedorId  INT           NOT NULL IDENTITY(1,1),
    RazonSocial  NVARCHAR(120) NOT NULL,
    Cuit         CHAR(11)      NOT NULL,
    Email        NVARCHAR(120) NULL,
    FechaAlta    DATE          NOT NULL CONSTRAINT DF_Proveedor_Alta DEFAULT (CAST(SYSDATETIME() AS DATE)),
    Activo       BIT           NOT NULL CONSTRAINT DF_Proveedor_Activo DEFAULT (1),
    CONSTRAINT PK_Proveedor       PRIMARY KEY (ProveedorId),
    CONSTRAINT UQ_Proveedor_Cuit  UNIQUE (Cuit),
    CONSTRAINT CK_Proveedor_Cuit  CHECK (Cuit NOT LIKE '%[^0-9]%'),
    CONSTRAINT CK_Proveedor_Email CHECK (Email IS NULL OR Email LIKE '%_@_%._%')
);
GO

/* Email unico PERO con varios proveedores sin email.
   Una restriccion UNIQUE de SQL Server trata los NULL como iguales entre si y
   admite UNO SOLO, de modo que el segundo proveedor sin email seria rechazado.
   El indice unico filtrado aplica la unicidad solo a las filas con valor. */
CREATE UNIQUE INDEX UX_Proveedor_Email
    ON dbo.Proveedor (Email)
    WHERE Email IS NOT NULL;
GO

/* Atributo multivaluado Telefono resuelto como tabla propia. */
CREATE TABLE dbo.ProveedorTelefono (
    ProveedorId INT          NOT NULL,
    NroTelefono TINYINT      NOT NULL,
    Telefono    NVARCHAR(30) NOT NULL,
    Tipo        NVARCHAR(15) NOT NULL CONSTRAINT DF_ProvTel_Tipo DEFAULT ('PRINCIPAL'),
    CONSTRAINT PK_ProveedorTelefono PRIMARY KEY (ProveedorId, NroTelefono),
    CONSTRAINT FK_ProveedorTelefono_Proveedor FOREIGN KEY (ProveedorId)
        REFERENCES dbo.Proveedor (ProveedorId) ON DELETE CASCADE,
    CONSTRAINT CK_ProvTel_Tipo CHECK (Tipo IN ('PRINCIPAL','ALTERNATIVO','WHATSAPP','FAX'))
);
GO

/* Relacion N:M SUMINISTRA: que puede proveer cada proveedor y en que condiciones. */
CREATE TABLE dbo.ProveedorProducto (
    ProveedorId      INT           NOT NULL,
    ProductoId       INT           NOT NULL,
    PrecioCompra     DECIMAL(12,2) NOT NULL,
    PlazoEntregaDias SMALLINT      NOT NULL CONSTRAINT DF_ProvProd_Plazo DEFAULT (0),
    CodigoProveedor  NVARCHAR(40)  NULL,
    EsPreferido      BIT           NOT NULL CONSTRAINT DF_ProvProd_Preferido DEFAULT (0),
    CONSTRAINT PK_ProveedorProducto PRIMARY KEY (ProveedorId, ProductoId),
    CONSTRAINT FK_ProveedorProducto_Proveedor FOREIGN KEY (ProveedorId)
        REFERENCES dbo.Proveedor (ProveedorId) ON DELETE CASCADE,
    CONSTRAINT FK_ProveedorProducto_Producto FOREIGN KEY (ProductoId)
        REFERENCES dbo.Producto (ProductoId) ON DELETE NO ACTION,
    CONSTRAINT CK_ProvProd_Precio CHECK (PrecioCompra > 0),
    CONSTRAINT CK_ProvProd_Plazo  CHECK (PlazoEntregaDias >= 0)
);
GO

/* A lo sumo un proveedor preferido por producto. */
CREATE UNIQUE INDEX UX_ProveedorProducto_Preferido
    ON dbo.ProveedorProducto (ProductoId)
    WHERE EsPreferido = 1;
GO

CREATE TABLE dbo.OrdenCompra (
    OrdenCompraId        INT          NOT NULL IDENTITY(1,1),
    NroOrden             NVARCHAR(16) NOT NULL,
    ProveedorId          INT          NOT NULL,
    EmpleadoId           INT          NOT NULL,
    DepositoId           INT          NOT NULL,
    FechaEmision         DATE         NOT NULL CONSTRAINT DF_OC_Emision DEFAULT (CAST(SYSDATETIME() AS DATE)),
    FechaEntregaEstimada DATE         NULL,
    Estado               NVARCHAR(12) NOT NULL CONSTRAINT DF_OC_Estado DEFAULT ('BORRADOR'),
    CONSTRAINT PK_OrdenCompra     PRIMARY KEY (OrdenCompraId),
    CONSTRAINT UQ_OrdenCompra_Nro UNIQUE (NroOrden),
    CONSTRAINT FK_OrdenCompra_Proveedor FOREIGN KEY (ProveedorId)
        REFERENCES dbo.Proveedor (ProveedorId) ON DELETE NO ACTION,
    CONSTRAINT FK_OrdenCompra_Empleado FOREIGN KEY (EmpleadoId)
        REFERENCES dbo.Empleado (EmpleadoId) ON DELETE NO ACTION,
    CONSTRAINT FK_OrdenCompra_Deposito FOREIGN KEY (DepositoId)
        REFERENCES dbo.Deposito (DepositoId) ON DELETE NO ACTION,
    CONSTRAINT CK_OC_Estado CHECK (Estado IN ('BORRADOR','EMITIDA','RECIBIDA','ANULADA')),
    CONSTRAINT CK_OC_Fechas CHECK (FechaEntregaEstimada IS NULL OR FechaEntregaEstimada >= FechaEmision)
);
GO

CREATE TABLE dbo.OrdenCompraDetalle (
    OrdenCompraId    INT           NOT NULL,
    ProductoId       INT           NOT NULL,
    Cantidad         DECIMAL(12,3) NOT NULL,
    PrecioUnitario   DECIMAL(12,2) NOT NULL,
    CantidadRecibida DECIMAL(12,3) NOT NULL CONSTRAINT DF_OCD_Recibida DEFAULT (0),
    CONSTRAINT PK_OrdenCompraDetalle PRIMARY KEY (OrdenCompraId, ProductoId),
    CONSTRAINT FK_OCD_OrdenCompra FOREIGN KEY (OrdenCompraId)
        REFERENCES dbo.OrdenCompra (OrdenCompraId) ON DELETE CASCADE,
    CONSTRAINT FK_OCD_Producto FOREIGN KEY (ProductoId)
        REFERENCES dbo.Producto (ProductoId) ON DELETE NO ACTION,
    CONSTRAINT CK_OCD_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_OCD_Precio   CHECK (PrecioUnitario >= 0),
    /* No se puede recibir mas de lo pedido. */
    CONSTRAINT CK_OCD_Recibida  CHECK (CantidadRecibida >= 0 AND CantidadRecibida <= Cantidad)
);
GO

/* ==========================================================================
   5. VENTAS Y COBRANZAS
   ========================================================================== */

CREATE TABLE dbo.Cliente (
    ClienteId INT           NOT NULL IDENTITY(1,1),
    TipoDoc   NVARCHAR(6)   NOT NULL,
    NroDoc    NVARCHAR(12)  NOT NULL,
    Nombre    NVARCHAR(60)  NOT NULL,
    Apellido  NVARCHAR(60)  NOT NULL,
    Email     NVARCHAR(120) NULL,
    FechaAlta DATE          NOT NULL CONSTRAINT DF_Cliente_Alta DEFAULT (CAST(SYSDATETIME() AS DATE)),
    Activo    BIT           NOT NULL CONSTRAINT DF_Cliente_Activo DEFAULT (1),
    CONSTRAINT PK_Cliente       PRIMARY KEY (ClienteId),
    CONSTRAINT UQ_Cliente_Doc   UNIQUE (TipoDoc, NroDoc),
    CONSTRAINT CK_Cliente_TipoDoc CHECK (TipoDoc IN ('DNI','CUIT','CUIL','PAS')),
    CONSTRAINT CK_Cliente_Email   CHECK (Email IS NULL OR Email LIKE '%_@_%._%')
);
GO

/* Mismo caso que en Proveedor: el email es unico entre quienes lo tienen,
   y puede haber muchos clientes sin email. */
CREATE UNIQUE INDEX UX_Cliente_Email
    ON dbo.Cliente (Email)
    WHERE Email IS NOT NULL;
GO

CREATE TABLE dbo.ClienteTelefono (
    ClienteId   INT          NOT NULL,
    NroTelefono TINYINT      NOT NULL,
    Telefono    NVARCHAR(30) NOT NULL,
    Tipo        NVARCHAR(15) NOT NULL CONSTRAINT DF_CliTel_Tipo DEFAULT ('PRINCIPAL'),
    CONSTRAINT PK_ClienteTelefono PRIMARY KEY (ClienteId, NroTelefono),
    CONSTRAINT FK_ClienteTelefono_Cliente FOREIGN KEY (ClienteId)
        REFERENCES dbo.Cliente (ClienteId) ON DELETE CASCADE,
    CONSTRAINT CK_CliTel_Tipo CHECK (Tipo IN ('PRINCIPAL','ALTERNATIVO','WHATSAPP','LABORAL'))
);
GO

/* Multivaluado compuesto: entidad debil con discriminante NroDireccion. */
CREATE TABLE dbo.ClienteDireccion (
    ClienteId    INT           NOT NULL,
    NroDireccion TINYINT       NOT NULL,
    Calle        NVARCHAR(120) NOT NULL,
    Numero       NVARCHAR(10)  NOT NULL,
    Ciudad       NVARCHAR(60)  NOT NULL,
    Provincia    NVARCHAR(60)  NOT NULL,
    CodigoPostal NVARCHAR(10)  NULL,
    EsPrincipal  BIT           NOT NULL CONSTRAINT DF_CliDir_Principal DEFAULT (0),
    CONSTRAINT PK_ClienteDireccion PRIMARY KEY (ClienteId, NroDireccion),
    CONSTRAINT FK_ClienteDireccion_Cliente FOREIGN KEY (ClienteId)
        REFERENCES dbo.Cliente (ClienteId) ON DELETE CASCADE
);
GO

CREATE UNIQUE INDEX UX_ClienteDireccion_Principal
    ON dbo.ClienteDireccion (ClienteId)
    WHERE EsPrincipal = 1;
GO

CREATE TABLE dbo.Pedido (
    PedidoId     INT          NOT NULL IDENTITY(1,1),
    NroPedido    NVARCHAR(16) NOT NULL,
    ClienteId    INT          NOT NULL,
    NroDireccion TINYINT      NULL,
    EmpleadoId   INT          NOT NULL,
    SucursalId   INT          NOT NULL,
    FechaPedido  DATETIME2(0) NOT NULL CONSTRAINT DF_Pedido_Fecha DEFAULT (SYSDATETIME()),
    Estado       NVARCHAR(12) NOT NULL CONSTRAINT DF_Pedido_Estado DEFAULT ('PENDIENTE'),
    Canal        NVARCHAR(12) NOT NULL,
    CONSTRAINT PK_Pedido     PRIMARY KEY (PedidoId),
    CONSTRAINT UQ_Pedido_Nro UNIQUE (NroPedido),
    CONSTRAINT FK_Pedido_Cliente FOREIGN KEY (ClienteId)
        REFERENCES dbo.Cliente (ClienteId) ON DELETE NO ACTION,
    /* FK compuesta solapada: la direccion de envio tiene que ser una direccion
       DE ESE cliente. La columna ClienteId participa de las dos FK, de modo que
       el motor hace imposible enviar al domicilio de otro cliente. */
    CONSTRAINT FK_Pedido_ClienteDireccion FOREIGN KEY (ClienteId, NroDireccion)
        REFERENCES dbo.ClienteDireccion (ClienteId, NroDireccion) ON DELETE NO ACTION,
    CONSTRAINT FK_Pedido_Empleado FOREIGN KEY (EmpleadoId)
        REFERENCES dbo.Empleado (EmpleadoId) ON DELETE NO ACTION,
    CONSTRAINT FK_Pedido_Sucursal FOREIGN KEY (SucursalId)
        REFERENCES dbo.Sucursal (SucursalId) ON DELETE NO ACTION,
    CONSTRAINT CK_Pedido_Estado CHECK (Estado IN ('PENDIENTE','CONFIRMADO','ENTREGADO','CANCELADO')),
    CONSTRAINT CK_Pedido_Canal  CHECK (Canal IN ('MOSTRADOR','WEB','TELEFONO')),
    /* Un pedido de mostrador se retira; cualquier otro canal exige domicilio.
       Nota: con NroDireccion NULL la FK compuesta no se verifica (MATCH SIMPLE),
       por eso la regla se completa con este CHECK. */
    CONSTRAINT CK_Pedido_Envio CHECK (
        (Canal = 'MOSTRADOR' AND NroDireccion IS NULL)
     OR (Canal <> 'MOSTRADOR' AND NroDireccion IS NOT NULL))
);
GO

CREATE TABLE dbo.PedidoDetalle (
    PedidoId                INT           NOT NULL,
    ProductoId              INT           NOT NULL,
    Cantidad                DECIMAL(12,3) NOT NULL,
    PrecioUnitarioHistorico DECIMAL(12,2) NOT NULL,
    DescuentoPct            DECIMAL(5,2)  NOT NULL CONSTRAINT DF_PedDet_Desc DEFAULT (0),
    CONSTRAINT PK_PedidoDetalle PRIMARY KEY (PedidoId, ProductoId),
    CONSTRAINT FK_PedidoDetalle_Pedido FOREIGN KEY (PedidoId)
        REFERENCES dbo.Pedido (PedidoId) ON DELETE CASCADE,
    CONSTRAINT FK_PedidoDetalle_Producto FOREIGN KEY (ProductoId)
        REFERENCES dbo.Producto (ProductoId) ON DELETE NO ACTION,
    CONSTRAINT CK_PedDet_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_PedDet_Precio   CHECK (PrecioUnitarioHistorico >= 0),
    CONSTRAINT CK_PedDet_Desc     CHECK (DescuentoPct >= 0 AND DescuentoPct <= 100)
);
GO

CREATE TABLE dbo.Factura (
    FacturaId       INT           NOT NULL IDENTITY(1,1),
    PedidoId        INT           NOT NULL,
    TipoComprobante CHAR(1)       NOT NULL,
    PuntoVenta      SMALLINT      NOT NULL,
    NroComprobante  INT           NOT NULL,
    FechaEmision    DATE          NOT NULL CONSTRAINT DF_Factura_Fecha DEFAULT (CAST(SYSDATETIME() AS DATE)),
    Neto            DECIMAL(14,2) NOT NULL,
    AlicuotaIva     DECIMAL(5,2)  NOT NULL CONSTRAINT DF_Factura_Iva DEFAULT (21),
    /* Atributo derivado materializado: depende solo de columnas de la propia
       fila, por lo que SQL Server puede mantenerlo sin triggers. */
    TotalFactura AS CAST(Neto * (1 + AlicuotaIva / 100.0) AS DECIMAL(16,4)) PERSISTED,
    CONSTRAINT PK_Factura PRIMARY KEY (FacturaId),
    /* UNIQUE sobre la FK: asi se implementa una relacion 1:1. */
    CONSTRAINT UQ_Factura_Pedido UNIQUE (PedidoId),
    CONSTRAINT UQ_Factura_Numeracion UNIQUE (TipoComprobante, PuntoVenta, NroComprobante),
    CONSTRAINT FK_Factura_Pedido FOREIGN KEY (PedidoId)
        REFERENCES dbo.Pedido (PedidoId) ON DELETE NO ACTION,
    CONSTRAINT CK_Factura_Tipo  CHECK (TipoComprobante IN ('A','B','C')),
    CONSTRAINT CK_Factura_Iva   CHECK (AlicuotaIva IN (0, 10.5, 21)),
    CONSTRAINT CK_Factura_Neto  CHECK (Neto >= 0),
    CONSTRAINT CK_Factura_PtoVta CHECK (PuntoVenta BETWEEN 1 AND 9999),
    CONSTRAINT CK_Factura_NroCbte CHECK (NroComprobante > 0)
);
GO

CREATE TABLE dbo.MedioPago (
    MedioPagoId INT          NOT NULL IDENTITY(1,1),
    Nombre      NVARCHAR(40) NOT NULL,
    RecargoPct  DECIMAL(5,2) NOT NULL CONSTRAINT DF_MedioPago_Recargo DEFAULT (0),
    Activo      BIT          NOT NULL CONSTRAINT DF_MedioPago_Activo DEFAULT (1),
    CONSTRAINT PK_MedioPago        PRIMARY KEY (MedioPagoId),
    CONSTRAINT UQ_MedioPago_Nombre UNIQUE (Nombre),
    CONSTRAINT CK_MedioPago_Recargo CHECK (RecargoPct >= 0 AND RecargoPct <= 100)
);
GO

/* Entidad debil de Factura: permite cobranza parcial y en varios medios. */
CREATE TABLE dbo.Pago (
    FacturaId   INT           NOT NULL,
    NroPago     TINYINT       NOT NULL,
    FechaPago   DATE          NOT NULL CONSTRAINT DF_Pago_Fecha DEFAULT (CAST(SYSDATETIME() AS DATE)),
    Monto       DECIMAL(14,2) NOT NULL,
    MedioPagoId INT           NOT NULL,
    Referencia  NVARCHAR(40)  NULL,
    CONSTRAINT PK_Pago PRIMARY KEY (FacturaId, NroPago),
    CONSTRAINT FK_Pago_Factura FOREIGN KEY (FacturaId)
        REFERENCES dbo.Factura (FacturaId) ON DELETE CASCADE,
    CONSTRAINT FK_Pago_MedioPago FOREIGN KEY (MedioPagoId)
        REFERENCES dbo.MedioPago (MedioPagoId) ON DELETE NO ACTION,
    CONSTRAINT CK_Pago_Monto CHECK (Monto > 0)
);
GO

/* ==========================================================================
   6. INDICES SOBRE CLAVES FORANEAS
   SQL Server indexa automaticamente PK y UNIQUE, pero NO las FK. Sin estos
   indices, cada DELETE en la tabla padre recorre la hija completa.
   ========================================================================== */

CREATE INDEX IX_Empleado_Sucursal        ON dbo.Empleado (SucursalId);
CREATE INDEX IX_Empleado_Supervisor      ON dbo.Empleado (SupervisorId);
CREATE INDEX IX_Categoria_Padre          ON dbo.Categoria (CategoriaPadreId);
CREATE INDEX IX_Producto_Categoria       ON dbo.Producto (CategoriaId);
CREATE INDEX IX_Producto_Marca           ON dbo.Producto (MarcaId);
CREATE INDEX IX_Deposito_Sucursal        ON dbo.Deposito (SucursalId);
CREATE INDEX IX_Stock_Deposito           ON dbo.Stock (DepositoId);
CREATE INDEX IX_Movimiento_Empleado      ON dbo.MovimientoStock (EmpleadoId);
CREATE INDEX IX_Movimiento_Fecha         ON dbo.MovimientoStock (FechaHora);
CREATE INDEX IX_ProvProd_Producto        ON dbo.ProveedorProducto (ProductoId);
CREATE INDEX IX_OrdenCompra_Proveedor    ON dbo.OrdenCompra (ProveedorId);
CREATE INDEX IX_OrdenCompra_Empleado     ON dbo.OrdenCompra (EmpleadoId);
CREATE INDEX IX_OrdenCompra_Deposito     ON dbo.OrdenCompra (DepositoId);
CREATE INDEX IX_OCD_Producto             ON dbo.OrdenCompraDetalle (ProductoId);
CREATE INDEX IX_Pedido_Cliente           ON dbo.Pedido (ClienteId);
CREATE INDEX IX_Pedido_Empleado          ON dbo.Pedido (EmpleadoId);
CREATE INDEX IX_Pedido_Sucursal          ON dbo.Pedido (SucursalId);
CREATE INDEX IX_Pedido_Fecha             ON dbo.Pedido (FechaPedido);
CREATE INDEX IX_PedidoDetalle_Producto   ON dbo.PedidoDetalle (ProductoId);
CREATE INDEX IX_Pago_MedioPago           ON dbo.Pago (MedioPagoId);
GO

/* ==========================================================================
   7. VISTAS DE ATRIBUTOS DERIVADOS
   Los derivados que agregan sobre otras tablas no pueden ser columnas
   calculadas: se resuelven con vistas, no con triggers ni redundancia.
   ========================================================================== */

CREATE VIEW dbo.vw_ProductoPrecioVigente AS
SELECT pp.ProductoId, pp.FechaDesde, pp.PrecioVenta, pp.PrecioCosto
FROM dbo.ProductoPrecio AS pp
WHERE pp.FechaHasta IS NULL;
GO

CREATE VIEW dbo.vw_ProductoStock AS
SELECT p.ProductoId, p.Sku, p.Nombre,
       StockTotal = SUM(ISNULL(s.Cantidad, 0))
FROM dbo.Producto AS p
LEFT JOIN dbo.Stock AS s ON s.ProductoId = p.ProductoId
GROUP BY p.ProductoId, p.Sku, p.Nombre;
GO

CREATE VIEW dbo.vw_DepositoOcupacion AS
SELECT d.DepositoId, d.Nombre, d.CapacidadMaxima,
       OcupacionActual = SUM(ISNULL(s.Cantidad, 0))
FROM dbo.Deposito AS d
LEFT JOIN dbo.Stock AS s ON s.DepositoId = d.DepositoId
GROUP BY d.DepositoId, d.Nombre, d.CapacidadMaxima;
GO

CREATE VIEW dbo.vw_PedidoTotal AS
SELECT pd.PedidoId,
       Total = SUM(CAST(pd.Cantidad * pd.PrecioUnitarioHistorico
                        * (1 - pd.DescuentoPct / 100.0) AS DECIMAL(16,2)))
FROM dbo.PedidoDetalle AS pd
GROUP BY pd.PedidoId;
GO

CREATE VIEW dbo.vw_FacturaSaldo AS
SELECT f.FacturaId, f.TotalFactura,
       Cobrado = SUM(ISNULL(pg.Monto, 0)),
       SaldoPendiente = f.TotalFactura - SUM(ISNULL(pg.Monto, 0))
FROM dbo.Factura AS f
LEFT JOIN dbo.Pago AS pg ON pg.FacturaId = f.FacturaId
GROUP BY f.FacturaId, f.TotalFactura;
GO

CREATE VIEW dbo.vw_StockBajoMinimo AS
SELECT s.ProductoId, p.Sku, p.Nombre, s.DepositoId, d.Nombre AS Deposito,
       s.Cantidad, s.StockMinimo
FROM dbo.Stock AS s
JOIN dbo.Producto AS p ON p.ProductoId = s.ProductoId
JOIN dbo.Deposito AS d ON d.DepositoId = s.DepositoId
WHERE s.Cantidad < s.StockMinimo;
GO

/* ==========================================================================
   8. AMPLIACION AE4: AUDITORIA DE ESTADOS DEL PEDIDO
   RN15: todo cambio de estado de un pedido queda registrado con fecha, hora
   y usuario. La tabla la alimenta exclusivamente el trigger
   trg_Pedido_ControlarEstado (archivo 04_programacion.sql).
   EstadoAnterior es NULL en el registro de alta del pedido.
   ========================================================================== */

CREATE TABLE dbo.PedidoEstadoHistorial (
    HistorialId    BIGINT        NOT NULL IDENTITY(1,1),
    PedidoId       INT           NOT NULL,
    EstadoAnterior NVARCHAR(12)  NULL,
    EstadoNuevo    NVARCHAR(12)  NOT NULL,
    FechaHora      DATETIME2(0)  NOT NULL CONSTRAINT DF_PedHist_Fecha   DEFAULT (SYSDATETIME()),
    Usuario        NVARCHAR(128) NOT NULL CONSTRAINT DF_PedHist_Usuario DEFAULT (SUSER_SNAME()),
    CONSTRAINT PK_PedidoEstadoHistorial PRIMARY KEY (HistorialId),
    /* El historial es parte del pedido: si un pedido se elimina (solo posible
       si no esta facturado), su historial se elimina con el. */
    CONSTRAINT FK_PedHist_Pedido FOREIGN KEY (PedidoId)
        REFERENCES dbo.Pedido (PedidoId) ON DELETE CASCADE,
    CONSTRAINT CK_PedHist_EstadoAnt CHECK (EstadoAnterior IS NULL OR
        EstadoAnterior IN ('PENDIENTE','CONFIRMADO','ENTREGADO','CANCELADO')),
    CONSTRAINT CK_PedHist_EstadoNvo CHECK (
        EstadoNuevo IN ('PENDIENTE','CONFIRMADO','ENTREGADO','CANCELADO')),
    CONSTRAINT CK_PedHist_Cambio CHECK (EstadoAnterior IS NULL OR EstadoAnterior <> EstadoNuevo)
);
GO

CREATE INDEX IX_PedHist_Pedido ON dbo.PedidoEstadoHistorial (PedidoId, FechaHora);
/* Indice de apoyo para localizar los movimientos generados por un documento
   (lo usan sp_CancelarPedido y trg_Pedido_ControlarEstado). */
CREATE INDEX IX_Movimiento_Documento ON dbo.MovimientoStock (DocumentoTipo, DocumentoId);
GO

PRINT 'DDL aplicado correctamente: 23 tablas.';
GO
