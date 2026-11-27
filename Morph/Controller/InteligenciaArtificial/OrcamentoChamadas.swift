import Foundation
import Observation

protocol RelogioOrcamento {
    var agora: Date { get }
}

final class RelogioSistema: RelogioOrcamento {
    var agora: Date { Date() }
}

enum PrioridadeChamada: Equatable {
    case aoVivo
    case concluir
    case diagnostico
}

enum ErroOrcamento: Error, Equatable {
    case cotaDiariaEsgotada
    case semVagaNoMinuto(espera: TimeInterval)
    case pausadoAte(Date)
}

struct StatusOrcamento: Equatable {
    let usadasNoMinuto: Int
    let capacidadeMinuto: Int
    let usadasNoDia: Int
    let capacidadeDia: Int
    let pausadoAte: Date?

    var restantesMinuto: Int { max(0, capacidadeMinuto - usadasNoMinuto) }
    var restantesDia: Int { max(0, capacidadeDia - usadasNoDia) }
    var esgotadoNoDia: Bool { usadasNoDia >= capacidadeDia }
}

@MainActor
@Observable
final class OrcamentoChamadas {
    var capacidadeMinuto: Int
    var capacidadeDia: Int
    var semLimite: Bool
    var maxEsperaAoVivo: TimeInterval
    var cooldownRecusa: TimeInterval
    var maxRecusasConsecutivas: Int

    private let relogio: RelogioOrcamento
    private let defaults: UserDefaults
    private let chaveDia = "orcamento.dia"
    private let chaveUsadas = "orcamento.usadas"
    private let dormir: (TimeInterval) async throws -> Void

    private var horarios: [Date] = []
    private var diaAtual: String
    private(set) var usadasNoDia: Int
    private(set) var pausadoAte: Date?
    private(set) var recusasConsecutivas = 0

    init(capacidadeMinuto: Int = 15,
         capacidadeDia: Int = 500,
         semLimite: Bool = false,
         maxEsperaAoVivo: TimeInterval = 5,
         cooldownRecusa: TimeInterval = 60,
         maxRecusasConsecutivas: Int = 2,
         relogio: RelogioOrcamento? = nil,
         defaults: UserDefaults = .standard,
         dormir: @escaping (TimeInterval) async throws -> Void = { segundos in
             try await Task.sleep(for: .seconds(segundos))
         }) {
        self.capacidadeMinuto = capacidadeMinuto
        self.capacidadeDia = capacidadeDia
        self.semLimite = semLimite
        self.maxEsperaAoVivo = maxEsperaAoVivo
        self.cooldownRecusa = cooldownRecusa
        self.maxRecusasConsecutivas = maxRecusasConsecutivas
        let relogio = relogio ?? RelogioSistema()
        self.relogio = relogio
        self.defaults = defaults
        self.dormir = dormir

        let hoje = Self.chaveDia(relogio.agora)
        self.diaAtual = hoje
        let diaSalvo = defaults.string(forKey: chaveDia)
        if diaSalvo == hoje {
            self.usadasNoDia = max(0, defaults.integer(forKey: chaveUsadas))
        } else {
            self.usadasNoDia = 0
            defaults.set(hoje, forKey: chaveDia)
            defaults.set(0, forKey: chaveUsadas)
        }
    }

    var status: StatusOrcamento {
        let hoje = Self.chaveDia(relogio.agora)
        let limite = relogio.agora.addingTimeInterval(-60)
        let noMinuto = horarios.filter { $0 > limite }.count
        let usadasHoje = hoje == diaAtual ? usadasNoDia : 0
        return StatusOrcamento(usadasNoMinuto: noMinuto,
                               capacidadeMinuto: capacidadeMinuto,
                               usadasNoDia: usadasHoje,
                               capacidadeDia: capacidadeDia,
                               pausadoAte: pausadoAte)
    }

    func atualizarVisitante() {
        let hoje = Self.chaveDia(relogio.agora)
        guard hoje != diaAtual else { return }
        diaAtual = hoje
        usadasNoDia = 0
        horasLimpar()
        defaults.set(hoje, forKey: chaveDia)
        defaults.set(0, forKey: chaveUsadas)
        pausadoAte = nil
        recusasConsecutivas = 0
    }

    func reservar(_ quantidade: Int, prioridade: PrioridadeChamada) async throws {
        guard quantidade > 0 else { return }
        atualizarVisitante()
        if semLimite { return }

        if let pausadoAte, pausadoAte > relogio.agora {
            throw ErroOrcamento.pausadoAte(pausadoAte)
        }

        while true {
            atualizarVisitante()
            podar()

            if let pausadoAte, pausadoAte > relogio.agora {
                throw ErroOrcamento.pausadoAte(pausadoAte)
            }
            if usadasNoDia + quantidade > capacidadeDia {
                throw ErroOrcamento.cotaDiariaEsgotada
            }

            let vagas = capacidadeMinuto - horarios.count
            if vagas >= quantidade {
                let agora = relogio.agora
                for _ in 0..<quantidade { horarios.append(agora) }
                usadasNoDia += quantidade
                defaults.set(usadasNoDia, forKey: chaveUsadas)
                return
            }

            let espera = Self.esperaParaVaga(horarios: horarios, quantidade: quantidade,
                                             capacidade: capacidadeMinuto, agora: relogio.agora)
            if prioridade == .aoVivo, espera > maxEsperaAoVivo {
                throw ErroOrcamento.semVagaNoMinuto(espera: espera)
            }
            try await dormir(max(0.05, espera))
        }
    }

    func registrarSucesso() {
        recusasConsecutivas = 0
    }

    func registrarRecusaDeLimite() {
        recusasConsecutivas += 1
        if recusasConsecutivas >= maxRecusasConsecutivas {
            pausadoAte = relogio.agora.addingTimeInterval(cooldownRecusa)
        }
    }

    func registrarCotaEsgotada() {
        usadasNoDia = capacidadeDia
        defaults.set(usadasNoDia, forKey: chaveUsadas)
    }

    func pausar(por segundos: TimeInterval) {
        pausadoAte = relogio.agora.addingTimeInterval(segundos)
    }

    func retomar() {
        pausadoAte = nil
        recusasConsecutivas = 0
    }

    private func podar() {
        let limite = relogio.agora.addingTimeInterval(-60)
        horarios.removeAll { $0 <= limite }
    }

    private func horasLimpar() {
        horarios.removeAll()
    }

    private static func esperaParaVaga(horarios: [Date], quantidade: Int,
                                       capacidade: Int, agora: Date) -> TimeInterval {
        guard quantidade > 0 else { return 0 }
        let necessarias = max(0, horarios.count - (capacidade - quantidade))
        guard necessarias > 0 else { return 0 }
        let ordenados = horarios.sorted()
        let indice = min(necessarias - 1, ordenados.count - 1)
        return max(0, ordenados[indice].addingTimeInterval(60).timeIntervalSince(agora))
    }

    private static func chaveDia(_ data: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: data)
    }
}

extension ErroOrcamento: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .cotaDiariaEsgotada:
            return "Cota diária de chamadas esgotada. Tente novamente amanhã."
        case .semVagaNoMinuto(let espera):
            return "Sem vaga no minuto atual. Nova tentativa em \(Int(espera.rounded()))s."
        case .pausadoAte(let data):
            return "Interpretação pausada até \(data.formatted(date: .omitted, time: .shortened))."
        }
    }
}
