// JenBar — lectura de uso de Claude y ChatGPT/Codex. Sólo lee credenciales; nunca las escribe.
import Foundation

struct Ventana {
    var usado: Double          // 0–100
    var reinicio: Date?
    var libre: Double { max(0, 100 - usado) }
}

struct Estado {
    var plan: String
    var cincoHoras: Ventana?
    var semana: Ventana?
    var libreMinimo: Double? {
        [cincoHoras, semana].compactMap { $0?.libre }.min()
    }
}

enum Servicio: String, CaseIterable, Identifiable {
    case claude, chatgpt
    var id: String { rawValue }
    var nombre: String { self == .claude ? "Claude" : "ChatGPT" }
    var glifo: String { self == .claude ? "claude" : "openai" }
}

enum FalloLectura: LocalizedError {
    case sinVincular, sesionVencida, respuesta(Int)
    var errorDescription: String? {
        switch self {
        case .sinVincular: return "No vinculado"
        case .sesionVencida: return "Sesión de Claude Code vencida: abrí Claude Code o volvé a vincular"
        case .respuesta(429): return "Demasiadas consultas: reintento en 15 min"
        case .respuesta(let c): return "El servicio respondió \(c)"
        }
    }
}

enum Lector {
    static func leer(_ s: Servicio) async throws -> Estado {
        s == .claude ? try await claude() : try await chatgpt()
    }

    static func vinculado(_ s: Servicio) -> Bool {
        switch s {
        case .claude: return (try? tokenClaude()) != nil
        case .chatgpt: return FileManager.default.fileExists(atPath: rutaCodex)
        }
    }

    // MARK: Claude (token OAuth de Claude Code en el llavero)

    private static func tokenClaude() throws -> (token: String, plan: String, vence: Date?) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        p.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        try p.run()
        p.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        guard p.terminationStatus == 0,
              let j = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let o = j["claudeAiOauth"] as? [String: Any],
              let t = o["accessToken"] as? String else { throw FalloLectura.sinVincular }
        return (t, (o["subscriptionType"] as? String) ?? "",
                (o["expiresAt"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) })
    }

    // El token de Claude Code dura unas 8 h y sólo Claude Code lo renueva. Vencido, el servicio
    // responde 429 (no 401). Para renovarlo sin tocar el llavero se le pide a Claude Code una
    // respuesta mínima (modelo haiku, un turno), como mucho una vez cada 30 min.
    private static var ultimoIntento = Date.distantPast
    static let rutaClaude = ["/opt/homebrew/bin/claude", "/usr/local/bin/claude", NSHomeDirectory() + "/.local/bin/claude"]
        .first { FileManager.default.isExecutableFile(atPath: $0) }

    private static func renovarClaude() async {
        guard let bin = rutaClaude, Date().timeIntervalSince(ultimoIntento) > 1800 else { return }
        ultimoIntento = Date()
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: bin)
            p.arguments = ["-p", "ok", "--model", "haiku", "--max-turns", "1"]
            p.currentDirectoryURL = FileManager.default.temporaryDirectory
            p.standardOutput = Pipe(); p.standardError = Pipe()
            p.terminationHandler = { _ in c.resume() }
            if (try? p.run()) == nil { c.resume() }
        }
    }

    private static func claude() async throws -> Estado {
        var (token, plan, vence) = try tokenClaude()
        if let v = vence, v.timeIntervalSinceNow < 60 {
            await renovarClaude()
            (token, plan, vence) = try tokenClaude()
            if let v = vence, v.timeIntervalSinceNow < 60 { throw FalloLectura.sesionVencida }
        }
        let j = try await pedir("https://api.anthropic.com/api/oauth/usage",
                                ["Authorization": "Bearer \(token)", "anthropic-beta": "oauth-2025-04-20"])
        func v(_ k: String) -> Ventana? {
            guard let d = j[k] as? [String: Any], let u = d["utilization"] as? Double else { return nil }
            return Ventana(usado: u, reinicio: (d["resets_at"] as? String).flatMap(fechaISO))
        }
        return Estado(plan: plan, cincoHoras: v("five_hour"), semana: v("seven_day"))
    }

    // MARK: ChatGPT / Codex (~/.codex/auth.json, sólo lectura)

    static let rutaCodex = NSHomeDirectory() + "/.codex/auth.json"

    private static func chatgpt() async throws -> Estado {
        guard let data = FileManager.default.contents(atPath: rutaCodex),
              let j = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let t = j["tokens"] as? [String: Any],
              let token = t["access_token"] as? String else { throw FalloLectura.sinVincular }
        var h = ["Authorization": "Bearer \(token)"]
        if let a = t["account_id"] as? String { h["ChatGPT-Account-Id"] = a }
        let u = try await pedir("https://chatgpt.com/backend-api/wham/usage", h)
        let rl = u["rate_limit"] as? [String: Any] ?? [:]
        var e = Estado(plan: (u["plan_type"] as? String) ?? "")
        // Las ventanas se ubican por duración: algunos planes sólo traen la semanal.
        for k in ["primary_window", "secondary_window"] {
            guard let w = rl[k] as? [String: Any], let used = w["used_percent"] as? Double else { continue }
            let v = Ventana(usado: used, reinicio: (w["reset_at"] as? Double).map { Date(timeIntervalSince1970: $0) })
            if ((w["limit_window_seconds"] as? Double) ?? 0) >= 86_400 { e.semana = v } else { e.cincoHoras = v }
        }
        return e
    }

    // MARK: Utilidades

    private static func pedir(_ url: String, _ headers: [String: String]) async throws -> [String: Any] {
        var r = URLRequest(url: URL(string: url)!, timeoutInterval: 15)
        r.setValue("JenBar", forHTTPHeaderField: "User-Agent")
        headers.forEach { r.setValue($1, forHTTPHeaderField: $0) }
        let (data, resp) = try await URLSession.shared.data(for: r)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 || code == 403 { throw FalloLectura.sesionVencida }
        guard code == 200 else { throw FalloLectura.respuesta(code) }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private static func fechaISO(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}
