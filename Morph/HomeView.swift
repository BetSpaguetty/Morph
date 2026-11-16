//
//  HomeView.swift
//  Morph
//
//  Created by Betsabé Oliveira Nogueira on 13/11/26.
//
import SwiftUI

struct HomeView: View {
    // Tom marrom-oliva profundo e quente para integrar a logo à iluminação amarelada da tela
    private let logoTopColor = Color(red: 0.235, green: 0.200, blue: 0.086)    // #3C3316
    private let logoBottomColor = Color(red: 0.180, green: 0.153, blue: 0.063) // #2E2710
    private let logoHalationColor = Color(red: 0.345, green: 0.286, blue: 0.110) // #58491C

    var body: some View {
        VStack {
            ZStack {
                // Preenchimento principal em marrom-oliva profundo mesclado ao fundo amarelado
                
                Image("logo_morph")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [logoTopColor, logoBottomColor],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(0.90)
            }
            .frame(width: 620, height: 200)
            .blendMode(.multiply)
            
            Button {
                // O que acontece quando clicar na imagem
            } label: {
                Image("botao_create")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 350, height: 100)
            }
            .buttonStyle(.plain)
        }
        .blendMode(.multiply)
    }
}

#Preview {
    ZStack {
        Color(red: 0.910, green: 0.847, blue: 0.588) // #E8D896
            .ignoresSafeArea()
        HomeView()
    }
}

