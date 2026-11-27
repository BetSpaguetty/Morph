import SwiftUI

// MARK: - Subcomponentes de Exibição dos Parâmetros

struct PainelRecolhivel<Conteudo: View>: View {
    let titulo: String
    @Binding var aberto: Bool
    @ViewBuilder var conteudo: Conteudo

    var body: some View {
        GroupBox {
            DisclosureGroup(isExpanded: $aberto) {
                conteudo.padding(.top, 6)
            } label: {
                Text(titulo)
                    .font(FontRegistrationManager.chicago(size: 14))
                    .foregroundStyle(.primary)
            }
        }
    }
}

struct LinhaParametro: View {
    let def: DefinicaoParametro
    let media: Double
    let desvio: Double?
    let ultimo: ResultadoParametro?
    var estrutura: EstruturaResposta = .niveis

    private var semValor: Bool { def.escala == .bipolar && abs(media) < 0.05 }

    private var rotulo: String {
        if semValor { return "sem valor" }
        var s = def.escala == .unipolar
            ? String(format: "%.1f", media)
            : String(format: "%+.1f", media)
        if let d = desvio { s += String(format: " ± %.2f", d) }
        return s
    }

    private var nivelFormatado: String {
        guard let u = ultimo else { return "" }
        return def.escala == .unipolar ? "\(u.nivel)" : (u.nivel > 0 ? "+\(u.nivel)" : "\(u.nivel)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(def.nome).font(FontRegistrationManager.chicago(size: 14))
                if def.candidata {
                    Text("candidata")
                        .font(FontRegistrationManager.chicago(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                Spacer()
                Text(rotulo)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(semValor ? .secondary : .primary)
            }

            if estrutura == .partes {
                let partes = ultimo?.partes ?? []
                if partes.isEmpty {
                    Text("sem partes nesta execução").font(.caption).foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(partes) { parte in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(parte.nivel > 0 ? "+\(parte.nivel)" : "\(parte.nivel)")
                                    .font(.caption2.bold().monospacedDigit())
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(.quaternary, in: Capsule())
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("“\(parte.inicioTexto)…\(parte.fimTexto)”")
                                        .font(.caption)
                                    if !parte.nucleosTexto.isEmpty {
                                        Text("núcleos: \(parte.nucleosTexto.joined(separator: ", "))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                if let u = ultimo, u.naoLiteral {
                    Label("parte não encontrada literalmente no texto", systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            } else {
                if def.escala == .unipolar {
                    BarraUnipolar(valor: max(0, media)).frame(height: 10)
                } else {
                    BarraBipolar(valor: media).frame(height: 10)
                }

                HStack {
                    Text(def.poloNegativo)
                    Spacer()
                    Text(def.poloPositivo)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                if let u = ultimo, let ev = u.evidencia, (u.nivel != 0 || def.escala == .unipolar) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Última execução: nível \(nivelFormatado), evidência “\(ev)”")
                            .font(.caption)
                            .italic()
                            .foregroundStyle(.secondary)
                        if u.contradicao {
                            Label("o modelo deu nível sem apresentar evidência", systemImage: "exclamationmark.triangle")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        } else if u.naoLiteral {
                            Label("citação não encontrada literalmente no texto", systemImage: "exclamationmark.triangle")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
    }
}

struct BarraBipolar: View {
    let valor: Double

    var body: some View {
        GeometryReader { g in
            let meio = g.size.width / 2
            let largura = abs(valor) * meio
            ZStack(alignment: .leading) {
                Rectangle().fill(.quaternary)
                Rectangle()
                    .fill(valor >= 0 ? Color.indigo : Color.teal)
                    .frame(width: largura)
                    .offset(x: valor >= 0 ? meio : meio - largura)
                Rectangle().fill(.secondary).frame(width: 1).offset(x: meio)
            }
            .clipShape(Capsule())
        }
    }
}

struct BarraUnipolar: View {
    let valor: Double

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Rectangle().fill(.quaternary)
                Rectangle()
                    .fill(Color.indigo)
                    .frame(width: CGFloat(max(0, min(1, valor))) * g.size.width)
            }
            .clipShape(Capsule())
        }
    }
}
