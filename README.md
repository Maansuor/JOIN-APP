# Join App

¡Bienvenido a Join! Esta aplicación está construida con Flutter.

## Requisitos Previos

Para ejecutar este proyecto, necesitas tener instalado **Flutter SDK**.

### Instalar Flutter en Windows
1. Descarga el zip de Flutter desde: [flutter.dev/docs/get-started/install/windows](https://flutter.dev/docs/get-started/install/windows)
2. Extrae el zip en `C:\src\flutter` (o donde prefieras, pero no en Archivos de Programa).
3. Añade `flutter\bin` a tu variable de entorno PATH.
4. Abre una nueva terminal y ejecuta `flutter doctor`.

## Configuración del Proyecto

Como he generado los archivos Dart pero no la estructura completa de plataformas (Android/iOS), debes ejecutar el siguiente comando para reparar y generar los archivos faltantes:

```bash
flutter create . --project-name join_app
```

Luego, instala las dependencias:

```bash
flutter pub get
```

## Ejecutar la App

Para ver la aplicación en tu navegador (si no tienes un emulador configurado):

```bash
flutter run -d chrome
```

Para ejecutar en un emulador Android/iOS:

```bash
flutter run
```

## Estructura
- `lib/features/home`: Pantalla principal y filtros.
- `lib/features/activity`: Detalles de actividad y tarjetas.
- `lib/main.dart`: Configuración de tema y rutas.
