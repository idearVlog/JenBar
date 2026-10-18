# Cambios

## 1.1.0 — 2026-10-18
- Aviso automático de actualizaciones: JenBar revisa GitHub al abrirse y cada 6 h. Cuando hay una versión nueva, avisa una vez con un cartel, muestra un punto en la barra y agrega «Actualización disponible» arriba del menú.

## 1.0.1 — 2026-10-18
- Claude: cuando vence la sesión de Claude Code (unas 8 h), JenBar la renueva sola a través de Claude Code. Antes quedaba fija en «demasiadas consultas».
- El plan se lee de nuevo en cada consulta (por ejemplo, muestra Max después de mejorar el plan y volver a iniciar sesión).

## 1.0.0 — 2026-10-15
Primera versión pública.
- Barra de menú: logos de Claude y ChatGPT con el % disponible, siguiendo el esquema del sistema.
- Desplegable: ventana de 5 h y semanal, con barras de consumido y restante y la hora de reinicio.
- Configuración: modo Sistema/Día/Noche, activar y vincular servicios, abrir al iniciar sesión.
- Conserva el último dato bueno y espera 15 min si el servicio responde «demasiadas consultas».
- Buscar actualizaciones desde GitHub Releases.
- Instalador DMG universal (Apple Silicon e Intel), macOS 14 o posterior.
