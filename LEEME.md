# Senpai de la Semana

## Subir a GitHub Pages
1. Crea un repositorio y sube **todo el contenido de esta carpeta** a la raíz (index.html, sw.js, manifest.webmanifest, img/).
2. Settings → Pages → Source: "Deploy from a branch" → rama `main`, carpeta `/ (root)`.
3. Abre la URL en el móvil y "Añadir a pantalla de inicio" (en iPhone, desde Safari → Compartir).
   Tras la primera carga, la app funciona sin conexión.

Cada vez que cambies index.html o imágenes, sube `VERSION` en sw.js (v1 → v2) para que los móviles se actualicen.

## Conectar Supabase
1. Crea el proyecto en Supabase.
2. Authentication → Sign In / Providers → activa **Allow anonymous sign-ins**.
3. SQL Editor → pega `supabase/schema.sql`, cambia el código `CAMBIAME` de la última línea por el tuyo y ejecuta.
4. Project Settings → API → copia **Project URL** y la clave **anon public**.
5. En index.html, rellena `const CONFIG={supabaseUrl:'…',supabaseAnonKey:'…'}` y súbelo.

Sin CONFIG, la app funciona en modo demo con rivales de ejemplo.
