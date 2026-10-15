import SwiftUI
import AppKit

enum Ajustes {
    static let d = UserDefaults.standard
    static var apariencia: String { d.string(forKey: "apariencia") ?? "sistema" }   // sistema | dia | noche
    static func activo(_ s: Servicio) -> Bool { d.object(forKey: "activo." + s.rawValue) as? Bool ?? true }
}

func glifo(_ nombre: String) -> NSImage {
    let img = Bundle.main.url(forResource: nombre, withExtension: "svg").flatMap(NSImage.init(contentsOf:)) ?? NSImage()
    img.isTemplate = true
    return img
}

func porcentaje(_ v: Double) -> String { "\(Int(v.rounded())) %" }

func cuando(_ d: Date?) -> String {
    guard let d else { return "—" }
    let f = DateFormatter()
    f.locale = Locale(identifier: "es_AR")
    f.dateFormat = Calendar.current.isDateInToday(d) ? "'hoy' HH:mm" : "EEE d HH:mm"
    let min = max(0, Int(d.timeIntervalSinceNow / 60))
    let falta = min < 60 ? "\(min) min" : min < 1440 ? "\(min / 60) h \(min % 60) min" : "\(min / 1440) d \(min % 1440 / 60) h"
    return "\(f.string(from: d)) · en \(falta)"
}

// MARK: Título de la barra (plantilla monocroma: macOS la pinta blanca o negra según el esquema)

func imagenBarra(_ items: [(Servicio, String)]) -> NSImage {
    let font = NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .semibold)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
    let ico: CGFloat = 14, gap: CGFloat = 4, sep: CGFloat = 10, h: CGFloat = 18
    let textos = items.map { NSAttributedString(string: $0.1, attributes: attrs) }
    let w = zip(items, textos).reduce(CGFloat(0)) { $0 + ico + gap + ceil($1.1.size().width) }
        + sep * CGFloat(max(items.count - 1, 0))
    let img = NSImage(size: NSSize(width: max(w, 1), height: h), flipped: false) { _ in
        var x: CGFloat = 0
        for ((s, _), t) in zip(items, textos) {
            glifo(s.glifo).draw(in: NSRect(x: x, y: (h - ico) / 2, width: ico, height: ico))
            x += ico + gap
            t.draw(at: NSPoint(x: x, y: (h - t.size().height) / 2))
            x += ceil(t.size().width) + sep
        }
        return true
    }
    img.isTemplate = true
    return img
}

// MARK: Desplegable

struct BarraUso: View {
    let v: Ventana
    var color: Color { v.usado >= 80 ? .red : .orange }
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.green.opacity(0.75))                       // restante
                Capsule().fill(color).frame(width: max(6, g.size.width * v.usado / 100))   // consumido
            }
        }
        .frame(height: 7)
    }
}

struct FilaVentana: View {
    let titulo: String
    let v: Ventana
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(titulo).font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(porcentaje(v.libre)) libre").font(.system(size: 12, weight: .semibold)).monospacedDigit()
            }
            BarraUso(v: v)
            HStack {
                Text("Usado \(porcentaje(v.usado))")
                Spacer()
                Text("Reinicia \(cuando(v.reinicio))")
            }
            .font(.system(size: 10.5)).foregroundStyle(.primary.opacity(0.75)).monospacedDigit()
        }
    }
}

struct TarjetaServicio: View {
    let servicio: Servicio
    let resultado: Result<Estado, Error>?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(nsImage: glifo(servicio.glifo)).resizable().frame(width: 15, height: 15)
                Text(servicio.nombre).font(.system(size: 13, weight: .semibold))
                if case .success(let e) = resultado, !e.plan.isEmpty {
                    Text(e.plan.uppercased()).font(.system(size: 9, weight: .bold)).tracking(0.6)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .overlay(Capsule().stroke(.primary.opacity(0.35)))
                }
                Spacer()
            }
            switch resultado {
            case .none: Text("Leyendo…").font(.system(size: 11))
            case .failure(let e): Text(e.localizedDescription).font(.system(size: 11))
            case .success(let e):
                if let v = e.cincoHoras { FilaVentana(titulo: "Ventana de 5 horas", v: v) }
                if let v = e.semana { FilaVentana(titulo: "Semanal", v: v) }
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(width: 300, alignment: .leading)
    }
}

struct Creditos: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Hecho por Fabián Fernández").font(.system(size: 10.5, weight: .medium))
            Text("Software libre · GPL v3").font(.system(size: 10.5))
            Text("Gentileza de idearVlog y Los Viajes del Tío Fabián").font(.system(size: 10.5))
            Text("¿Querés apoyarme? Sólo suscribite a mis canales.").font(.system(size: 10.5))
        }
        .foregroundStyle(.primary.opacity(0.8))
        .padding(.horizontal, 14).padding(.vertical, 6)
        .frame(width: 300, alignment: .leading)
    }
}

// MARK: Configuración

struct VistaConfig: View {
    @AppStorage("apariencia") var apariencia = "sistema"
    @AppStorage("activo.claude") var claude = true
    @AppStorage("activo.chatgpt") var chatgpt = true
    @State var alIniciar = Arranque.activo
    @State var refresco = 0
    var alCambiar: () -> Void

    var body: some View {
        Form {
            Section("Apariencia") {
                Picker("Modo", selection: $apariencia) {
                    Text("Sistema").tag("sistema"); Text("Día").tag("dia"); Text("Noche").tag("noche")
                }
                .pickerStyle(.segmented)
                Toggle("Abrir al iniciar sesión", isOn: $alIniciar)
                    .onChange(of: alIniciar) { _, v in Arranque.activo = v }
            }
            Section("Servicios") {
                fila(.claude, $claude)
                fila(.chatgpt, $chatgpt)
            }
            Section {
                Text("Hecho por Fabián Fernández · GPL-3.0 · Gentileza de idearVlog y Los Viajes del Tío Fabián")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .id(refresco)
        .onChange(of: apariencia) { _, _ in alCambiar() }
        .onChange(of: claude) { _, _ in alCambiar() }
        .onChange(of: chatgpt) { _, _ in alCambiar() }
    }

    func fila(_ s: Servicio, _ on: Binding<Bool>) -> some View {
        HStack {
            Image(nsImage: glifo(s.glifo)).resizable().frame(width: 16, height: 16)
            VStack(alignment: .leading) {
                Text(s.nombre)
                Text(Lector.vinculado(s) ? "Vinculado" : "No vinculado").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Vincular…") { Vinculo.abrir(s); DispatchQueue.main.asyncAfter(deadline: .now() + 5) { refresco += 1 } }
            Toggle("", isOn: on).labelsHidden().toggleStyle(.switch)
        }
    }
}
