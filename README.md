# BootcampCLTNoviembre — Products API (Clean Architecture + CQRS + PostgreSQL)

API de productos en **.NET 10** con **Minimal API**, **Clean Architecture + CQRS** (mediator propio, igual que
`03-CleanArchitecture-CQRS`) y persistencia en **PostgreSQL** con **EF Core + Npgsql**
(según *Clase 3 - Data Persistencia*).

## Estructura

```
BootcampCLTNoviembre.slnx
Directory.Build.props / Directory.Packages.props   <- net10.0 + Central Package Management
database/
  01_create_tables.sql                             <- CREATE TABLE products (+ índice único, checks)
  02_insert_products.sql                           <- 20 productos de electrónica y computación
  03_select_products.sql                           <- consultas de ejemplo
src/
  BootcampCLTNoviembre.Domain          Product (entidad rica), IProductRepository, IUnitOfWork, DomainException
  BootcampCLTNoviembre.Application     Commands/Queries + Validators + Handlers, ISender, Behaviors (Logging, Validation)
  BootcampCLTNoviembre.Infrastructure  AppDbContext, ProductConfiguration (Fluent API), ProductRepository, ProductsReadStore
  BootcampCLTNoviembre.Api             Minimal API (ProductsEndpoints), GlobalExceptionHandler, Program.cs
```

Dependencias: `Api -> Application, Infrastructure`, `Infrastructure -> Application -> Domain`. Domain no depende de nada.

### Cómo se relaciona con la Clase 3

| Concepto de la clase            | Dónde está |
|---------------------------------|------------|
| DbContext (el núcleo)           | `Infrastructure/Persistence/AppDbContext.cs` |
| DbSet (colecciones)             | `AppDbContext.Products` |
| Configuración Fluent API        | `Infrastructure/Persistence/Configurations/ProductConfiguration.cs` |
| Npgsql + connection pooling     | `Infrastructure/DependencyInjection.cs` (`UseNpgsql`, pooling activado por defecto) |
| Cadena de conexión              | `Api/appsettings.Development.json` -> `ConnectionStrings:BootcampDb` |
| DTOs (frontera de la aplicación)| `ProductResponse`, `CreateProductCommand`, `UpdateProductRequest`, `PatchProductRequest` |
| Entidad de dominio              | `Domain/Products/Product.cs` |
| FluentValidation                | `*CommandValidator` + `ValidationBehavior` (se ejecuta antes de cada handler) |

## Contrato HTTP

| Método | Ruta | Tipo CQRS | Respuestas |
|---|---|---|---|
| GET    | `/v1/api/products?search=` | Query   | 200 |
| GET    | `/v1/api/products/{id}`    | Query   | 200, 404 |
| POST   | `/v1/api/products`         | Command | 201, 400 |
| PUT    | `/v1/api/products/{id}`    | Command | 200, 400, 404 |
| PATCH  | `/v1/api/products/{id}`    | Command | 200, 400, 404 |
| DELETE | `/v1/api/products/{id}`    | Command | 204, 404 |

- **400**: datos inválidos:
  - formato (FluentValidation): nombre vacío, precio o stock negativos, PATCH sin campos.
  - regla de dominio (`DomainException`): el nombre del producto ya existe (sin distinguir mayúsculas).
- **404**: el producto no existe.
- **503**: PostgreSQL no disponible (tras agotar los reintentos de `EnableRetryOnFailure`).

## Ejecutar

### 1. Preparar PostgreSQL

Con PostgreSQL instalado y en ejecución, crear el usuario y la base como superusuario (ej. `postgres`):
```sql
CREATE DATABASE bootcamp_db OWNER bootcamp_user;
```
Luego crear la tabla y cargar los productos (con psql, pgAdmin o DBeaver):
```bash
psql -h localhost -U bootcamp_user -d bootcamp_db -f database/01_create_tables.sql
psql -h localhost -U bootcamp_user -d bootcamp_db -f database/02_insert_products.sql
```
`database/03_select_products.sql` tiene consultas de ejemplo para practicar.

### 2. Levantar la API
```bash
dotnet run --project src/BootcampCLTNoviembre.Api
```
Abrir http://localhost:5234/scalar. `src/BootcampCLTNoviembre.Api/BootcampCLTNoviembre.http` tiene un request
por endpoint, con los casos de error incluidos.

## Cadena de conexión y seguridad

Npgsql usa el formato clave=valor (no el formato URI `postgresql://user:pass@host:5432/db`):
```
Host=localhost;Port=5432;Database=bootcamp_db;Username=bootcamp_user;Password=...
```
`appsettings.Development.json` trae una clave de ejemplo para desarrollo local. Fuera de desarrollo **no** se versiona:
```bash
# user-secrets (local)
dotnet user-secrets set "ConnectionStrings:BootcampDb" "Host=...;Password=..." --project src/BootcampCLTNoviembre.Api
# variable de entorno (servidores)
ConnectionStrings__BootcampDb="Host=...;Password=..."
```

## Esquema: scripts SQL vs. migraciones

En este proyecto, el esquema lo definen los **scripts SQL** de `database/`. EF Core solo mapea
(`ProductConfiguration`) y la API no crea tablas al iniciar. Si se cambia la entidad, actualizar el script y el
mapeo juntos.

Para trabajar con **migraciones** (el pilar 4 de la clase), en lugar de los scripts:
```bash
dotnet tool install --global dotnet-ef
# agregar el paquete Microsoft.EntityFrameworkCore.Design (10.0.x) al proyecto Api
dotnet ef migrations add Inicial --project src/BootcampCLTNoviembre.Infrastructure --startup-project src/BootcampCLTNoviembre.Api
dotnet ef database update     --project src/BootcampCLTNoviembre.Infrastructure --startup-project src/BootcampCLTNoviembre.Api
```
