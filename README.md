# JenBar

**JenBar · cuánto te queda en Claude y ChatGPT, en tu barra de menú.**

Medidor mínimo para la barra de menú de macOS: muestra cuánto te queda en **Claude** (ventana de 5 horas y semanal) y en **ChatGPT / Codex**, con el logo de cada servicio.

- La barra muestra el porcentaje disponible, en monocromo, y se adapta al modo día o noche.
- El desplegable muestra, por servicio, barras de consumido y restante y la hora de cada reinicio.
- En Configuración elegís el modo (Sistema / Día / Noche), activás o vinculás cada servicio y decidís si se abre al iniciar sesión.
- Desde el menú podés buscar actualizaciones de la app.

## Cómo lee los datos
Sólo lee credenciales; nunca las escribe ni las envía a terceros.
- **Claude**: lee el token OAuth de Claude Code guardado en el llavero (`Claude Code-credentials`). Para vincularlo, corré `claude /login`.
- **ChatGPT/Codex**: lee `~/.codex/auth.json`. Para vincularlo, corré `codex login`.

Los endpoints de uso no están documentados públicamente y pueden cambiar.

## Compilar
Requiere macOS 14 o posterior y las Command Line Tools.
```
./build.sh   # genera build/JenBar.app
```

## Créditos
Hecho por Fabián Fernández. Software libre bajo **GPL-3.0**.
Gentileza de [idearVlog](https://www.youtube.com/@IdearVlog) y [Los Viajes del Tío Fabián](https://www.youtube.com/@losviajesdeltiofabian).
¿Querés apoyarme? Sólo suscribite a mis canales.

Los logos (Simple Icons, CC0) son marcas de sus respectivos dueños. JenBar no está afiliado a Anthropic ni a OpenAI.
