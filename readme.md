# Flujo CI/CD.

Este repositorio usa el workflow **`.github/workflows/main.yml`** para construir, publicar y desplegar la aplicación automáticamente.

## Disparador

El pipeline se ejecuta cuando hay `push` a la rama:

- `main`

## Variables y secretos requeridos

### Variables derivadas

- `REGISTRY_URL = <AWS_ACCOUNT_ID>.dkr.ecr.<AWS_REGION>.amazonaws.com`

### Secrets usados en GitHub Actions

- `AWS_ACCOUNT_ID`
- `AWS_REGION`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`
- `AWS_ECR_REPOSITORY`
- `EC2_INSTANCE_ID`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`

## Etapas del pipeline

## 1) Build and Push Image (`build-and-push`)

Pasos:

1. Checkout del repositorio.
2. Configuración de credenciales AWS.
3. Login en Amazon ECR.
4. Build de la imagen Docker con dos tags:
   - `${github.sha}`
   - `latest`
5. Push de ambos tags al repositorio ECR.

Resultado: imagen disponible en ECR lista para despliegue.

## 2) Deploy to EC2 via SSM (`deploy-to-ec2`)

Esta etapa depende de `build-and-push` (`needs: build-and-push`).

Pasos:

1. Configuración de credenciales AWS para SSM.
2. Ejecución de `aws ssm send-command` sobre la instancia EC2.
3. En EC2 se ejecutan comandos para:
   - crear carpeta de trabajo `/home/ec2-user/backend-ventas`
   - autenticarse en ECR
   - descargar imagen `latest`
   - crear red Docker `api-network` si no existe
   - detener y eliminar contenedores previos (`springboot-api`, `mysql-db`)
   - levantar MySQL (`mysql:8.0`) con volumen persistente `mysql_data`
   - esperar 15 segundos
   - levantar backend `springboot-api` con variables `DB_*`
   - limpiar imágenes Docker no utilizadas

Resultado: aplicación desplegada en EC2 con MySQL y backend corriendo en contenedores.

## Orden de ejecución

1. `build-and-push`
2. `deploy-to-ec2`

Si falla la primera etapa, la segunda no se ejecuta.

## Resumen operacional

- **CI**: build de imagen Docker y publicación en ECR.
- **CD**: despliegue remoto en EC2 usando AWS SSM, recreando contenedores de BD y API.
