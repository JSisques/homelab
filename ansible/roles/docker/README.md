# Docker Ansible Role

Instala y habilita Docker Engine, Buildx y el plugin de Docker Compose en hosts Debian-family.

## Responsabilidades

- Configurar el repositorio oficial de Docker.
- Instalar Docker Engine y sus plugins.
- Habilitar e iniciar el servicio Docker.

La configuración de cada aplicación y sus archivos Compose pertenece al rol de la aplicación correspondiente.

## Uso

```yaml
roles:
  - common
  - docker
  - it-tools
```

## Variables

- `docker_apt_channel`: canal del repositorio, por defecto `stable`.
- `docker_packages`: paquetes instalados.
- `docker_service_name`: nombre del servicio, por defecto `docker`.

El rol es idempotente y no añade usuarios al grupo `docker` automáticamente.
