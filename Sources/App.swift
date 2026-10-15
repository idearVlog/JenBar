import SwiftUI
import AppKit
import ServiceManagement

let repoGitHub = "idearvlog/Restante"
let canales = [("idearVlog", "https://www.youtube.com/@IdearVlog"),
               ("Los Viajes del Tío Fabián", "https://www.youtube.com/@losviajesdeltiofabian")]

enum Arranque {
    static var activo: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set { try? newValue ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() }
    }
}

enum Vinculo {
    // Abre Terminal con el inicio de sesión oficial de cada CLI; Restante nunca escribe credenciales.
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
    var resultados: [Servicio: Result<Estado, Error>] = [:]
    var ultima = Date.distantPast
    var ventanaConfig: NSWindow?

    func applicationDidFinishLaunching(_ n: Notification) {
        aplicarApariencia()
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        pintarBarra()
        actualizar()
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in Task { @MainActor in self.actualizar() } }
    }

    var activos: [Servicio] { Servicio.allCases.filter(Ajustes.activo) }

    func actualizar() {
        ultima = Date()
        for s in activos {
            Task {
                do { resultados[s] = .success(try await Lector.leer(s)) } catch { resultados[s] = .failure(error) }
                pintarBarra()
            }
        }
    }

    func pintarBarra() {
        let items = activos.map { s -> (Servicio, String) in
            if case .success(let e) = resultados[s], let l = e.libreMinimo { return (s, porcentaje(l).replacingOccurrences(of: " ", with: "")) }
            return (s, "–")
        }
        item.button?.image = imagenBarra(items)
        item.button?.toolTip = "Restante: porcentaje disponible"
    }

    func aplicarApariencia() {
        switch Ajustes.apariencia {
        case "dia": NSApp.appearance = NSAppearance(named: .aqua)
        case "noche": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }

    // MARK: Menú

    func menuNeedsUpdate(_ menu: NSMenu) {
        if Date().timeIntervalSince(ultima) > 60 { actualizar() }
        menu.removeAllItems()
        for s in activos {
            menu.addItem(vista(TarjetaServicio(servicio: s, resultado: resultados[s])))
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
            w.title = "Restante · Configuración"
            w.isReleasedWhenClosed = false
            ventanaConfig = w
        }
        NSApp.activate(ignoringOtherApps: true)
        ventanaConfig?.center()
        ventanaConfig?.makeKeyAndOrderFront(nil)
    }

    @objc func buscarVersion() {
        Task {
            let actual = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
            let alerta = NSAlert()
            var url: URL?
            do {
                let (d, r) = try await URLSession.shared.data(from: URL(string: "https://api.github.com/repos/\(repoGitHub)/releases/latest")!)
                guard (r as? HTTPURLResponse)?.statusCode == 200,
                      let j = try JSONSerialization.jsonObject(with: d) as? [String: Any],
                      let tag = j["tag_name"] as? String else { throw URLError(.badServerResponse) }
                let nueva = tag.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
                if nueva.compare(actual, options: .numeric) == .orderedDescending {
                    alerta.messageText = "Hay una versión nueva: \(nueva)"
                    alerta.informativeText = "Tenés la \(actual). ¿Abrir la página de descarga?"
                    alerta.addButton(withTitle: "Descargar"); alerta.addButton(withTitle: "Más tarde")
                    url = (j["html_url"] as? String).flatMap(URL.init(string:))
                } else {
                    alerta.messageText = "Restante está al día (\(actual))"
                }
            } catch {
                alerta.messageText = "No se pudo comprobar la versión"
                alerta.informativeText = "github.com/\(repoGitHub)"
            }
            NSApp.activate(ignoringOtherApps: true)
            if alerta.runModal() == .alertFirstButtonReturn, let url { NSWorkspace.shared.open(url) }
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
