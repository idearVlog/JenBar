import SwiftUI
import AppKit
import ServiceManagement

let repoGitHub = "idearVlog/JenBar"
let canales = [("idearVlog", "https://www.youtube.com/@IdearVlog"),
               ("Los Viajes del Tío Fabián", "https://www.youtube.com/@losviajesdeltiofabian")]

enum Arranque {
    static var activo: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set { try? newValue ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() }
    }
}

enum Vinculo {
    // Abre Terminal con el inicio de sesión oficial de cada CLI; JenBar nunca escribe credenciales.
    static func abrir(_ s: Servicio) {
        let cmd: String
        switch s {
        case .claude:
            cmd = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/claude") ? "claude /login"
                : "brew install --cask claude-code && claude /login"
        case .chatgpt:
            cmd = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/codex") ? "codex login"
                : "brew install --cask codex && codex login"
        }
        let script = "tell application \"Terminal\" to activate\ntell application \"Terminal\" to do script \"\(cmd)\""
        NSAppleScript(source: script)?.executeAndReturnError(nil)
    }
}

@MainActor
final class Controlador: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var ultimos: [Servicio: (estado: Estado, cuando: Date)] = [:]   // último dato bueno: se conserva si falla una lectura
    var errores: [Servicio: Error] = [:]
    var proximo: [Servicio: Date] = [:]                            // pausa entre lecturas (evita el 429 del servicio)
    var ventanaConfig: NSWindow?

    func applicationDidFinishLaunching(_ n: Notification) {
        aplicarApariencia()
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        pintarBarra()
        actualizar()
        if CommandLine.arguments.contains("--config") { abrirConfig() }
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in Task { @MainActor in self.actualizar() } }
        revisarEnSegundoPlano()
        Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { _ in Task { @MainActor in self.revisarEnSegundoPlano() } }
    }

    var activos: [Servicio] { Servicio.allCases.filter(Ajustes.activo) }

    func actualizar() {
        for s in activos where Date() >= proximo[s, default: .distantPast] {
            proximo[s] = Date().addingTimeInterval(240)
            Task {
                do {
                    ultimos[s] = (try await Lector.leer(s), Date()); errores[s] = nil
                } catch {
                    errores[s] = error
                    if case FalloLectura.respuesta(429) = error { proximo[s] = Date().addingTimeInterval(900) }
                }
                pintarBarra()
            }
        }
    }

    func pintarBarra() {
        let items = activos.map { s -> (Servicio, String) in
            if let l = ultimos[s]?.estado.libreMinimo { return (s, porcentaje(l).replacingOccurrences(of: " ", with: "")) }
            return (s, "–")
        }
        // Plantilla: la barra sigue siempre al sistema, como las demás apps; el modo forzado sólo cambia menú y ventanas.
        item.button?.image = imagenBarra(items, aviso: novedad != nil)
        item.button?.toolTip = "JenBar: porcentaje disponible"
    }

    func aplicarApariencia() {
        switch Ajustes.apariencia {
        case "dia": NSApp.appearance = NSAppearance(named: .aqua)
        case "noche": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
        // El menú de la barra no hereda NSApp.appearance: se fuerza aparte.
        item.menu?.appearance = NSApp.appearance
    }

    // MARK: Menú

    func menuNeedsUpdate(_ menu: NSMenu) {
        actualizar()
        menu.appearance = NSApp.appearance
        menu.removeAllItems()
        if let n = novedad {
            let m = accion("Nueva versión: JenBar \(n.version) · Instalar y reiniciar", "arrow.down.circle.fill", #selector(abrirNovedad), "")
            m.attributedTitle = NSAttributedString(string: m.title, attributes: [.font: NSFont.menuFont(ofSize: 13).withTraits(.bold)])
            menu.addItem(m)
            menu.addItem(.separator())
        }
        for s in activos {
            menu.addItem(vista(TarjetaServicio(servicio: s, ultimo: ultimos[s], error: errores[s])))
            menu.addItem(.separator())
        }
        if activos.isEmpty { menu.addItem(withTitle: "Activá un servicio en Configuración", action: nil, keyEquivalent: "") }
        menu.addItem(accion("Actualizar ahora", "arrow.clockwise", #selector(actualizarAhora), "r"))
        menu.addItem(accion("Configuración…", "gearshape", #selector(abrirConfig), ","))
        menu.addItem(accion("Buscar actualizaciones…", "arrow.down.circle", #selector(buscarVersion), ""))
        menu.addItem(.separator())
        menu.addItem(vista(Creditos()))
        for (i, c) in canales.enumerated() {
            let m = accion("Suscribite a \(c.0)", "play.rectangle", #selector(abrirCanal(_:)), "")
            m.tag = i
            menu.addItem(m)
        }
        menu.addItem(.separator())
        menu.addItem(accion("Salir", "power", #selector(NSApplication.terminate(_:)), "q"))
    }

    func vista<V: View>(_ v: V) -> NSMenuItem {
        let h = NSHostingView(rootView: v)
        // Sin apariencia propia: hereda la del menú real, así texto y fondo coinciden siempre.
        h.frame.size = h.fittingSize
        let m = NSMenuItem()
        m.view = h
        return m
    }

    func accion(_ t: String, _ simbolo: String, _ sel: Selector, _ tecla: String) -> NSMenuItem {
        let m = NSMenuItem(title: t, action: sel, keyEquivalent: tecla)
        m.target = sel == #selector(NSApplication.terminate(_:)) ? NSApp : self
        m.image = NSImage(systemSymbolName: simbolo, accessibilityDescription: nil)
        return m
    }

    @objc func actualizarAhora() { actualizar() }
    @objc func abrirCanal(_ m: NSMenuItem) { NSWorkspace.shared.open(URL(string: canales[m.tag].1)!) }

    @objc func abrirConfig() {
        if ventanaConfig == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: VistaConfig {
                self.aplicarApariencia(); self.pintarBarra(); self.actualizar()
            }))
            w.title = "JenBar · Configuración"
            w.isReleasedWhenClosed = false
            w.styleMask = [.titled, .closable]
            w.setContentSize(NSSize(width: 420, height: 400))
            ventanaConfig = w
        }
        // macOS 14+: activate(ignoringOtherApps:) ya no trae al frente una app de barra de menú.
        NSApp.activate()
        ventanaConfig?.center()
        ventanaConfig?.makeKeyAndOrderFront(nil)
        ventanaConfig?.orderFrontRegardless()
    }

    // MARK: Actualizaciones

    var novedad: (version: String, url: URL, dmg: URL?)?
    var actual: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }

    func consultarVersion() async throws -> (version: String, url: URL, dmg: URL?)? {
        let (d, r) = try await URLSession.shared.data(from: URL(string: "https://api.github.com/repos/\(repoGitHub)/releases/latest")!)
        guard (r as? HTTPURLResponse)?.statusCode == 200,
              let j = try JSONSerialization.jsonObject(with: d) as? [String: Any],
              let tag = j["tag_name"] as? String,
              let url = (j["html_url"] as? String).flatMap(URL.init(string:)) else { throw URLError(.badServerResponse) }
        let v = tag.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        let dmg = (j["assets"] as? [[String: Any]])?
            .compactMap { $0["browser_download_url"] as? String }.first { $0.hasSuffix(".dmg") }
            .flatMap(URL.init(string:))
        return v.compare(actual, options: .numeric) == .orderedDescending ? (v, url, dmg) : nil
    }

    // Revisión silenciosa al abrir y cada 6 h: avisa una sola vez por versión.
    func revisarEnSegundoPlano() {
        Task {
            guard let n = try? await consultarVersion() else { return }
            novedad = n
            pintarBarra()
            if CommandLine.arguments.contains("--instalar-novedad") { instalar(n); return }   // para pruebas
            let clave = "avisada." + n.version
            guard !UserDefaults.standard.bool(forKey: clave) else { return }
            UserDefaults.standard.set(true, forKey: clave)
            let a = NSAlert()
            a.messageText = "JenBar \(n.version) está disponible"
            a.informativeText = "Tenés la \(actual). Se instala sola y JenBar se vuelve a abrir."
            a.addButton(withTitle: "Instalar y reiniciar"); a.addButton(withTitle: "Más tarde")
            NSApp.activate()
            if a.runModal() == .alertFirstButtonReturn { instalar(n) }
        }
    }

    @objc func abrirNovedad() { if let n = novedad { instalar(n) } }

    // Descarga el DMG de la release, reemplaza la app y la vuelve a abrir.
    // Si algo falla, abre la página de la release para descargarla a mano.
    func instalar(_ n: (version: String, url: URL, dmg: URL?)) {
        guard let dmg = n.dmg else { NSWorkspace.shared.open(n.url); return }
        item.button?.toolTip = "Descargando JenBar \(n.version)…"
        Task {
            do {
                let (tmp, r) = try await URLSession.shared.download(from: dmg)
                guard (r as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                let destino = Bundle.main.bundlePath
                let script = """
                set -e
                MNT=$(hdiutil attach -nobrowse -noverify -noautoopen "\(tmp.path)" | awk -F'\\t' '/Volumes/{print $NF}')
                while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
                rm -rf "\(destino)"
                ditto "$MNT/JenBar.app" "\(destino)"
                hdiutil detach -quiet "$MNT"
                rm -f "\(tmp.path)"
                open "\(destino)"
                """
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/bin/zsh")
                p.arguments = ["-c", script]
                try p.run()
                NSApp.terminate(nil)
            } catch {
                NSWorkspace.shared.open(n.url)
            }
        }
    }

    @objc func buscarVersion() {
        Task {
            let alerta = NSAlert()
            var url: URL?
            do {
                if let n = try await consultarVersion() {
                    novedad = n; pintarBarra()
                    alerta.messageText = "Hay una versión nueva: \(n.version)"
                    alerta.informativeText = "Tenés la \(actual). Se instala sola y JenBar se vuelve a abrir."
                    alerta.addButton(withTitle: "Instalar y reiniciar"); alerta.addButton(withTitle: "Más tarde")
                    url = n.url
                } else {
                    alerta.messageText = "JenBar está al día (\(actual))"
                }
            } catch {
                alerta.messageText = "No se pudo comprobar la versión"
                alerta.informativeText = "github.com/\(repoGitHub)"
            }
            NSApp.activate()
            if alerta.runModal() == .alertFirstButtonReturn, url != nil, let n = novedad { instalar(n) }
        }
    }
}

@main
struct Principal {
    @MainActor static func main() {
        let app = NSApplication.shared
        let c = Controlador()
        app.delegate = c
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

extension NSFont {
    func withTraits(_ t: NSFontDescriptor.SymbolicTraits) -> NSFont {
        NSFont(descriptor: fontDescriptor.withSymbolicTraits(t), size: pointSize) ?? self
    }
}
