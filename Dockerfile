# https://hub.docker.com/_/microsoft-dotnet
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /source

# copy csproj and restore as distinct layers
COPY *.sln .
COPY BadgeryApi/*.csproj ./b/
RUN dotnet restore

# copy everything else and build app
COPY BadgeryApi/. ./BadgeryApi/
WORKDIR /source/BadgeryApi
RUN dotnet publish -c release -o /app

# final stage/image
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app ./

ENTRYPOINT ["dotnet", "BadgeryApi.dll"]

EXPOSE 8080
