# Ventas API — Rama deploy-eks

    Backend en **Java / Spring Boot** para la gestión de ventas, equipado con un pipeline de integración y despliegue continuo (CI/CD) automatizado hacia **AWS EKS** (Elastic Kubernetes Service) a través de **GitHub Actions**.

    ---

    ## 1. Arquitectura del Backend

    El proyecto sigue una arquitectura tradicional por capas, garantizando la separación de responsabilidades:

    * **Framework:** Spring Boot 3.4.x, Java 17.
    * **Capas del Código:**
        * `controller`: Expone la API REST (`VentaController`).
        * `services`: Contiene la lógica de negocio (`VentaService`, `VentaServiceImpl`).
        * `repository`: Acceso a datos mediante Spring Data JPA (`VentaRepository`).
        * `entity`: Modelo de datos persistente (`Venta`).
        * `exceptions`: Manejo global de errores (`RestResponseEntityExceptionHandler`).
    * **Bases de Datos:** MySQL en entorno de producción/runtime, y H2 en memoria para la ejecución de pruebas unitarias e integracionales.
    * **Documentación de la API:** Generada automáticamente con Springdoc OpenAPI y accesible vía Swagger UI.

    ---

    ## 2. Configuración de Base de Datos

    La aplicación requiere las siguientes variables de entorno para construir dinámicamente la propiedad `spring.datasource.url`, el usuario y la contraseña en el archivo `application.properties`:

    * `DB_ENDPOINT` (Host del servidor de base de datos)
    * `DB_PORT` (Puerto de conexión, por defecto `3306`)
    * `DB_NAME` (Nombre de la base de datos)
    * `DB_USERNAME` (Usuario de conexión)
    * `DB_PASSWORD` (Contraseña de conexión)

    ---

    ## 3. Pipeline CI/CD (`deploy-eks.yml`)

    El flujo de despliegue automatizado está definido en `.github/workflows/deploy-eks.yml` y se dispara automáticamente al hacer un `push` a la rama `deploy-eks`, o bien de forma manual (`workflow_dispatch`).

    El workflow se compone de dos trabajos (`jobs`) principales:

    ### Job 1: Build and Push Image
    1. Código fuente mediante **Checkout**.
    2. Configuración de credenciales de AWS.
    3. Autenticación en **Amazon ECR**.
    4. Construcción (Build) de la imagen Docker.
    5. Publicación (Push) de la imagen utilizando dos tags de forma simultánea: el hash del commit (`${github.sha}`) y `latest`.

    ### Job 2: Deploy to EKS
    1. Código fuente (**Checkout** de los manifiestos de Kubernetes).
    2. Configuración de credenciales de AWS.
    3. Instalación y configuración de `kubectl`.
    4. Actualización del contexto de Kubernetes con `aws eks update-kubeconfig` apuntando a `EKS_CLUSTER_NAME`.
    5. Creación o actualización del secreto de Kubernetes (`backend2-db-secret`) inyectando las siguientes variables:
       * `MYSQL_DATABASE` <- `DB_NAME`
       * `MYSQL_ROOT_PASSWORD` <- `DB_PASSWORD`
       * `MYSQL_USER` <- `DB_USER`
       * `MYSQL_PASSWORD` <- `DB_PASSWORD`
    6. Aplicación de manifiestos: `kubectl apply -f k8s/ -n <namespace>`.
    7. Actualización de la imagen del Deployment (`kubectl set image`) utilizando la nueva imagen publicada en ECR.
    8. Verificación del estado del despliegue (`rollout status`) y listado de Pods/Services.

    ---

    ## 4. Recursos de Kubernetes

    ### Existentes en el directorio `k8s/`
    * `deployment.yaml`: Configuración del pod del backend de la aplicación.
    * `service.yaml`: Expone el backend internamente dentro del clúster (`ClusterIP`).
    * `hpa.yaml`: Escalado horizontal automático (`Horizontal Pod Autoscaler`) para el backend.
    * `mysql-deployment.yaml`: Pod dedicado a la base de datos MySQL.
    * `mysql-service.yaml`: Expone la base de datos de manera interna (`ClusterIP`).

    ### Faltantes o recomendables para entornos de producción
    > ⚠️ **Notas de optimización arquitectónica:**
    > * **Manifiesto del Namespace:** Actualmente se asume preexistente en el clúster. Se recomienda incluir su declaración explícita.
    > * **Acceso Externo:** Implementar un recurso `Ingress` o configurar el Service como tipo `LoadBalancer`.
    > * **Persistencia:** La plantilla de MySQL actual utiliza `emptyDir` (almacenamiento efímero). Es crítico migrar a un `PersistentVolumeClaim` (PVC) respaldado por AWS EBS o EFS para evitar la pérdida de datos al reiniciar el pod.
    > * **Políticas y Probes:** Se sugiere robustecer los parámetros de `Liveness/Readiness Probes`, añadir `NetworkPolicy` para aislar el tráfico de la BD y configurar un `PodDisruptionBudget`.

    ---

    ## 5. Endpoints y Documentación Expuesta

    **Base Path:** `/api/v1/ventas`

    | Método | Endpoint | Descripción |
    | :--- | :--- | :--- |
    | **POST** | `/api/v1/ventas` | Registra una nueva venta |
    | **PUT** | `/api/v1/ventas/{idVenta}` | Actualiza una venta existente por ID |
    | **GET** | `/api/v1/ventas` | Obtiene el listado completo de ventas |
    | **GET** | `/api/v1/ventas/{idVenta}` | Obtiene el detalle de una venta específica |
    | **DELETE** | `/api/v1/ventas/{idVenta}` | Elimina el registro de una venta |

    * **Swagger UI:** Disponible localmente y en ambientes desplegados a través de la ruta `/swagger-ui.html`.

    ---

    ## 6. Clonado y Ejecución Local

    ### Requisitos Previos
    * Java 17 (JDK)
    * Maven (o utilizar el wrapper `./mvnw` incluido)
    * Instancia de MySQL activa

    ### Construcción y ejecución local con Docker

    Para validar el empaquetado de la imagen de forma local, ejecuta:

```bash
    # Construir la imagen local
    docker build -t ventas-api:local .

    # Ejecutar el contenedor conectándolo a una base de datos local
    docker run --rm -p 8080:8080 \
      -e DB_ENDPOINT=host.docker.internal \
      -e DB_PORT=3306 \
      -e DB_NAME=ventas \
      -e DB_USERNAME=root \
      -e DB_PASSWORD=secret \
      ventas-api:local
    ```

    ---

    ## 7. Despliegue en EKS (Resumen Operacional)

    Para que el flujo de GitHub Actions se ejecute de manera correcta, es mandatorio configurar los siguientes secretos en el repositorio (**Settings > Secrets and variables > Actions**):

    * **Credenciales AWS:** `AWS_ACCOUNT_ID`, `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` (si aplica), `AWS_ECR_REPOSITORY`.
    * **Variables de EKS:** `EKS_CLUSTER_NAME`, `EKS_NAMESPACE`, `K8S_DEPLOYMENT_NAME`, `K8S_CONTAINER_NAME`.
    * **Variables de BD:** `DB_NAME`, `DB_USER`, `DB_PASSWORD`.

    Una vez configurados los secretos, basta con realizar un push a la rama `deploy-eks` para iniciar el despliegue automático. Puedes monitorear el progreso en la pestaña **Actions** de GitHub.

    ---

    ## 8. Notas Importantes

    * **Imagen Placeholder:** El archivo `deployment.yaml` original define una imagen ligera temporal (`nginx:alpine`). El workflow se encarga de sobreescribir esta propiedad dinámicamente con la imagen correcta construida en ECR mediante el comando `kubectl set image`.
    * **Secreto de Base de Datos:** Los manifiestos incluidos en `k8s/` consumen de forma mandatoria un secret de Kubernetes llamado `backend2-db-secret`.
    * **Flujos Alternativos:** El repositorio cuenta con otro archivo de workflow (`.github/workflows/main.yml`) diseñado exclusivamente para despliegues orientados a instancias **AWS EC2** tradicionales a través de AWS Systems Manager (SSM). No debe confundirse con la arquitectura EKS de esta rama.
