/* ==========================================================================
   AE4 - TRABAJO FINAL INTEGRADOR - BASE DE DATOS (ISI17BAD28V26AE4V26)
   Proyecto StockFlow - SCRIPT INTEGRAL
   Estudiantes: Leandro Acosta - Nahuel Villegas
   Motor: Microsoft SQL Server 2022. Ejecutable de principio a fin sobre un
   servidor sin la base StockFlow (la crea desde cero).
   SSMS: abrir y ejecutar (F5). sqlcmd:
     sqlcmd -S .\SQLEXPRESS -E -f 65001 -i AE4_StockFlow_script_integral.sql
   Archivo generado a partir de los modulos de la carpeta sql/:
     01_ddl.sql
     02_datos_prueba.sql
     03_pruebas_integridad.sql
     04_programacion.sql
     05_vistas.sql
     06_manipulacion_dml.sql
     07_consultas.sql
     08_pruebas_programacion.sql
   ========================================================================== */

/* ##########################################################################
   MODULO 01_ddl.sql
   ########################################################################## */
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

/* ##########################################################################
   MODULO 02_datos_prueba.sql
   ########################################################################## */
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

/* ##########################################################################
   MODULO 03_pruebas_integridad.sql
   ########################################################################## */
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

/* ##########################################################################
   MODULO 04_programacion.sql
   ########################################################################## */
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

/* ##########################################################################
   MODULO 05_vistas.sql
   ########################################################################## */
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

/* ##########################################################################
   MODULO 06_manipulacion_dml.sql
   ########################################################################## */
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

/* ##########################################################################
   MODULO 07_consultas.sql
   ########################################################################## */
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

/* ##########################################################################
   MODULO 08_pruebas_programacion.sql
   ########################################################################## */
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
