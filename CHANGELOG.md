# Cambios

## 1.2.0 — 2026-11-18
- Claude no se desconecta más: JenBar renueva la sesión de Claude Code 10 minutos antes de que venza (igual que Claude Code) y la guarda en el mismo lugar del llavero, así Claude Code también queda al día.
- Umbrales más prudentes: una consulta cada 5 min por servicio; ante «demasiadas consultas» respeta el tiempo que indica el servicio o espera 5, 10, 20 y hasta 30 min.

## 1.1.2 — 2026-11-17
- JenBar ya no lanza Claude Code en segundo plano para renovar la sesión: en algunas Mac provocaba pedidos de permiso a Documentos en bucle.
- Si la sesión de Claude venció o se cerró, el menú lo dice y ofrece «Iniciar sesión en Claude…».
- «Actualizar ahora» reintenta en el momento, sin esperar la pausa entre consultas.

## 1.1.1 — 2026-11-10
- La barra muestra el disponible de la ventana semanal (antes, el de la ventana más gastada). Si el plan no tiene semanal, muestra el de 5 h.

## 1.1.0 — 2026-10-18
- Aviso automático de actualizaciones: JenBar revisa GitHub al abrirse y cada 6 h. Cuando hay una versión nueva, avisa una vez con un cartel; hasta que actualices, la barra muestra una flecha de descarga y el menú arranca con «Nueva versión · Instalar y reiniciar». Un clic descarga, instala y vuelve a abrir JenBar.

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
