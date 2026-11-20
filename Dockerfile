# Etapa 1: restaura dependencias y publica la API.
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Se copian primero los archivos de proyecto para aprovechar la cache de Docker.
COPY ["Directory.Build.props", "."]
COPY ["Directory.Packages.props", "."]
COPY ["src/BootcampCLTNoviembre.Domain/BootcampCLTNoviembre.Domain.csproj", "src/BootcampCLTNoviembre.Domain/"]
COPY ["src/BootcampCLTNoviembre.Application/BootcampCLTNoviembre.Application.csproj", "src/BootcampCLTNoviembre.Application/"]
COPY ["src/BootcampCLTNoviembre.Infrastructure/BootcampCLTNoviembre.Infrastructure.csproj", "src/BootcampCLTNoviembre.Infrastructure/"]
COPY ["src/BootcampCLTNoviembre.Api/BootcampCLTNoviembre.Api.csproj", "src/BootcampCLTNoviembre.Api/"]

RUN dotnet restore "src/BootcampCLTNoviembre.Api/BootcampCLTNoviembre.Api.csproj"

# Se copia el codigo fuente despues del restore para reutilizar esa capa mientras
# no cambien los archivos de proyecto o las versiones de los paquetes.
COPY . .

RUN dotnet publish "src/BootcampCLTNoviembre.Api/BootcampCLTNoviembre.Api.csproj" \
    --configuration Release \
    --output /app/publish \
    --no-restore \
    /p:UseAppHost=false

# Etapa 2: imagen final. Solo contiene el runtime y los archivos publicados.
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

ENV ASPNETCORE_HTTP_PORTS=9090
EXPOSE 9090

COPY --from=build /app/publish .

# Usuario sin privilegios incluido en las imagenes oficiales de .NET.
USER $APP_UID

ENTRYPOINT ["dotnet", "BootcampCLTNoviembre.Api.dll"]
