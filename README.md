# 💀 Jam Día de Muertos

Videojuego para game jam hecho en **Godot 4.7.2**, exportado a navegador (itch.io).

Esta guía te lleva desde cero hasta ver el proyecto corriendo en tu computadora.

---

## ✅ Requisitos

| Herramienta | Versión | Dónde |
|---|---|---|
| Godot Engine | **4.7.2 estándar** (NO la .NET / C#) | https://godotengine.org/download/windows/ |
| Git | La más reciente | https://git-scm.com/downloads |
| Cuenta de GitHub | — | https://github.com |

> ⚠️ **Todo el equipo debe usar exactamente Godot 4.7.2.** Si abres el proyecto con otra versión, Godot puede modificar archivos y romper el proyecto.

---

## 1. Descargar Godot 4.7.2

1. Entra a https://godotengine.org/download/windows/ y busca **4.7.2*.
2. Descarga la versión **estándar** para tu sistema operativo (no la que dice .NET).
3. **Windows:** descomprime el `.zip` en una carpeta fija, por ejemplo `C:\Godot\`. Dentro verás dos `.exe`; usa el que **no** dice `console`. Godot no se instala: ese `.exe` es el programa. (Opcional: clic derecho → Enviar a → Escritorio para crear un acceso directo.)
4. **macOS:** descomprime y arrastra `Godot.app` a **Aplicaciones**.
5. **Linux:** descomprime y dale permisos con `chmod +x` al ejecutable.

Para confirmar la versión: abre Godot y revisa la esquina inferior del Project Manager. Debe decir `v4.7.2`.

---

## 2. Instalar Git

1. Descarga Git desde https://git-scm.com/downloads e instálalo con las opciones por defecto.
2. En Windows se instala también **Git Bash**, la terminal que usaremos.
3. Abre Git Bash (o tu terminal) y configura tu nombre y correo **una sola vez**:

```bash
git config --global user.name "Tu Nombre"
git config --global user.email "tu_correo@ejemplo.com"
```

Usa el mismo correo de tu cuenta de GitHub.

---

## 3. Aceptar la invitación al repositorio

Te llegará un correo de GitHub con la invitación al repositorio `Haziel08/JamDiaDeMuertos`. Da clic en **Accept invitation**. Sin esto no podrás subir cambios.

---

## 4. Clonar el repositorio

1. Abre Git Bash en la carpeta donde quieras guardar el proyecto (por ejemplo `Documentos`). En Windows: clic derecho dentro de la carpeta → **Open Git Bash here**.
2. Ejecuta:

```bash
git clone https://github.com/Haziel08/JamDiaDeMuertos.git
```

3. La primera vez se abrirá una ventana del navegador para iniciar sesión en GitHub; acéptala.
4. Se creará la carpeta `JamDiaDeMuertos` con el proyecto.

---

## 5. Abrir el proyecto en Godot

1. Abre Godot 4.7.2.
2. En el Project Manager da clic en **Importar** (Import).
3. Busca la carpeta `JamDiaDeMuertos` y selecciona el archivo **`project.godot`**.
4. Da clic en **Importar y Editar** (Import & Edit).
5. La primera vez tardará unos segundos importando recursos. Es normal: está creando la carpeta `.godot/`, que es caché local y **nunca** se sube al repositorio.

---

## 6. Ejecutar

Presiona **F5** (o el botón ▶ arriba a la derecha).

Debe abrirse una ventana con el texto:

### EJECUCIÓN CORRECTA JAM DÍA DE MUERTOS

Si lo ves, ¡todo quedó listo! 🎉

---

## 🧯 Problemas comunes

**"Este proyecto fue creado con otra versión de Godot" / te pide convertir el proyecto**
Estás usando una versión distinta a la 4.7.2. Cierra **sin convertir** y descarga la versión correcta.

**Al darle F5 pregunta cuál es la escena principal**
Probablemente abriste otra carpeta. Asegúrate de haber importado el `project.godot` de la carpeta clonada.

**`git clone` dice "Repository not found"**
No has aceptado la invitación o no iniciaste sesión con la cuenta correcta de GitHub.

**`git` no se reconoce como comando**
Git no está instalado o no reiniciaste la terminal después de instalarlo.

---

## 📏 Recomendaciones

1. **Nadie actualiza Godot**. Todos en 4.7.2.
2. **Nunca subas la carpeta `.godot/`** (el `.gitignore` ya lo evita; no lo borres).
3. **Antes de empezar a trabajar**, trae los cambios de los demás:
   ```bash
   git pull
   ```
4. **Avisa al equipo qué escena vas a editar**, para que dos personas no modifiquen la misma escena al mismo tiempo (los conflictos en archivos `.tscn` son difíciles de resolver).
