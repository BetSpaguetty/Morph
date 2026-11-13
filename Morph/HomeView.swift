//
//  HomeView.swift
//  Morph
//
//  Created by Betsabé Oliveira Nogueira on 13/11/26.
//
import SwiftUI

struct HomeView: View {
    var body: some View {
        
        VStack(spacing: 24) {
            
            Image("logo_morph")
                .resizable()
                .scaledToFit()
                .frame(width: 500, height: 250)
                

        }
        
    }
}

#Preview {
    HomeView()
}
