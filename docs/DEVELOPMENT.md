# Stocklet

App de gestión para microempresas (ventas, inventario, gastos, pedidos, notas y equipo con roles), hecha en **Flutter + Firebase**. Multiempresa y multi-idioma (es/en/pt/fr).

Publicada por **BuildLark S.A.S.** · Package: `com.buildlark.stocklet`

> Nota: el nombre interno del paquete Dart sigue siendo `reposteria_app` (histórico, no afecta a los usuarios).

## Stack

- **Flutter / Dart** (Android, iOS, web/PWA).
- **Firebase**: Auth, Firestore, Storage, Cloud Functions, Cloud Messaging, Analytics, Crashlytics.
- **RevenueCat** (`purchases_flutter`) para suscripciones (freemium; inactivo hasta configurar la cuenta de Play).
- i18n con ARB + `gen-l10n`.

## Puesta en marcha

```
flutter pub get
flutter gen-l10n
flutter run
```

Requiere los archivos de configuración de Firebase (no versionados): `android/app/google-services.json`, `lib/firebase_options.dart`, y para iOS `ios/Runner/GoogleService-Info.plist`.

## Comandos frecuentes

```
flutter analyze
flutter build appbundle              # .aab para Google Play
firebase deploy --only functions     # Cloud Functions
firebase deploy --only hosting       # web/ (tras flutter build web)
```

## Cloud Functions

Tres funciones en `functions/`: `inventarioBajo` (push cuando un insumo cruza su
mínimo), `recordatorioPedidos` (aviso diario de pedidos por entregar) y
`eliminarCuenta` (borrado de cuenta, requisito de las tiendas). Requieren plan
Blaze.

Corren en **Node 22**. Se subió desde Node 20 porque Google lo apaga el
2026-10-30, y con él vinieron `firebase-admin` 14 y `firebase-functions` 7.

**`firebase-admin` 14 eliminó el espacio de nombres**: `admin.firestore()`,
`admin.auth()`, `admin.messaging()` y `admin.storage()` ya no existen. Todo entra
por imports modulares (`getFirestore()`, `getAuth()`, …). Si algún día se copia
código de un ejemplo viejo, fallará con `admin.X is not a function`.

**Hay que desplegar con el CLI de npm, no con el de winget.** `firebase-admin` 14
arrastra `jose`, que es solo ESM, y el CLI empaquetado de winget lleva Node 20
dentro y revienta al analizar el código:

```
Error [ERR_REQUIRE_ESM]: require() of ES Module .../jose/dist/webapi/index.js
```

El de npm usa el Node del sistema. Si `firebase --version` no dice 15 o más:

```
npm install -g firebase-tools
winget uninstall Google.FirebaseCLI
```

Para probarlas antes de desplegar, los emuladores cargan las tres si arrancan con
`--only functions,firestore,auth,storage`; el log debe decir
`Using node@22 from host`. `recordatorioPedidos` queda fuera sin el emulador de
pubsub, pero su handler se puede llamar a mano con `.run({})`.

## Negocio de demo (capturas de la tienda)

Las capturas de la ficha de Google Play **no deben salir del negocio real**: las
pantallas muestran nombres y teléfonos de clientes, ventas, costos y márgenes, y
una captura en Play es pública y permanente.

Para eso hay un negocio de demo sembrado en los emuladores. El `--project` tiene
que ser el mismo de `firebase_options.dart`: el emulador de Firestore separa los
datos por proyecto, así que con otro nombre la app entra pero encuentra la base
vacía y te manda a crear negocio. En una terminal:

```
firebase emulators:start --only auth,firestore,storage --project mi-reposteria-app
```

En otra, una sola vez `npm install` dentro de `tool/demo`, y luego:

```
cd tool/demo
npm run sembrar
```

Y la app apuntando a los emuladores:

```
flutter run --dart-define=STOCKLET_EMULADOR=true
```

Entrar con `demo@stocklet.app` / `demo1234` (credenciales del emulador; no
existen en el proyecto real). Volver a sembrar deja todo igual que la primera
vez, así que las capturas son repetibles.

Los emuladores tienen que seguir corriendo mientras usas la app: si los paras,
el login falla con un error genérico y los datos sembrados se pierden (se
vuelven a sembrar en segundos).

La dirección del host se resuelve sola: `10.0.2.2` en el emulador de Android,
`localhost` en web y escritorio. Desde un **teléfono físico** hay que pasar la
IP de tu máquina en la red local:

```
flutter run --dart-define=STOCKLET_EMULADOR=true --dart-define=STOCKLET_EMULADOR_HOST=192.168.1.X
```

**Si el emulador de Android no alcanza `10.0.2.2`** (síntoma: el login falla con
el error genérico, y `adb shell nc -w 3 10.0.2.2 9099` responde
`Network is unreachable`), su stack de red está roto. En vez de pelearse con
él, se tuneliza por el cable de depuración:

```
adb reverse tcp:8080 tcp:8080
adb reverse tcp:9099 tcp:9099
adb reverse tcp:9199 tcp:9199
```

Y se compila apuntando a `localhost`, que ahora sale por el túnel:

```
flutter run --dart-define=STOCKLET_EMULADOR=true --dart-define=STOCKLET_EMULADOR_HOST=localhost
```

Los túneles se pierden al reiniciar el AVD; hay que volver a crearlos.

El interruptor `STOCKLET_EMULADOR` es `const` y está apagado por defecto: un
build de release lo elimina del binario.

## Pruebas

Lógica pura (costeo, unidades, formato):

```
flutter test
```

Las reglas de seguridad tienen su propia suite, aparte (ver abajo).

## Reglas de seguridad

Las reglas viven en el repositorio y son la única barrera real entre un negocio
y los datos de otro (la UI solo oculta botones):

- `firestore.rules` — aislamiento por negocio y permisos por rol (`dueno`,
  `socio`, `empleado`).
- `storage.rules` — fotos de perfil, logo del negocio y catálogos en PDF.

Tienen una suite que las ejerce contra el emulador. Requiere Java y una vez
`npm install` dentro de `test/rules`:

```
cd test/rules
npm test
```

Para desplegarlas (sobrescribe lo que haya en la consola de Firebase):

```
firebase deploy --only firestore:rules,storage
```

Ojo con el nombre del objetivo: `firestore:rules` existe, pero `storage:rules`
no. En Storage lo que va después de los dos puntos es un *deploy target* de
bucket, así que las reglas van con `storage` a secas.

## Documentación

- `docs/ficha-play.md` — guion de capturas y textos de la ficha de Google Play.
- `docs/data-safety.md` — inventario de datos para el formulario de Seguridad de
  los datos de Google Play. Hay que actualizarlo cuando la app recoja un dato nuevo.


El estado del proyecto, el plan de monetización y el checklist para publicar están en
`Creador Apps/Stocklet - Estado del proyecto.md`.
