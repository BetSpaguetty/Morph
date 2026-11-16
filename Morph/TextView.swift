//
//  TextView.swift
//  Morph
//
//  Created by Betsabé Oliveira Nogueira on 16/11/26.
//

import SwiftUI

struct TextView: View {
    @State private var texto: String = ""

    var body: some View {
        TextEditor(text: $texto)
            .font(.body)
            .padding()
            .scrollContentBackground(.hidden)
        // Mantém o fundo transparente para combinar com o estilo da T
    }
}

#Preview {
    TextView()
}
