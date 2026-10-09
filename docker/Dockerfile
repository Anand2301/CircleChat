FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /app

# Copy solution and project files for layer caching
COPY backend/CircleChat.slnx backend/
COPY backend/src/CircleChat.Domain/CircleChat.Domain.csproj backend/src/CircleChat.Domain/
COPY backend/src/CircleChat.Application/CircleChat.Application.csproj backend/src/CircleChat.Application/
COPY backend/src/CircleChat.Infrastructure/CircleChat.Infrastructure.csproj backend/src/CircleChat.Infrastructure/
COPY backend/src/CircleChat.API/CircleChat.API.csproj backend/src/CircleChat.API/

RUN dotnet restore backend/src/CircleChat.API/CircleChat.API.csproj

# Copy all source files
COPY backend/ backend/

# Publish
WORKDIR /app/backend/src/CircleChat.API
RUN dotnet publish -c Release -o /app/publish --no-restore

# Runtime Image
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:5000
EXPOSE 5000

ENTRYPOINT ["dotnet", "CircleChat.API.dll"]
