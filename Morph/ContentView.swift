import SwiftUI


struct ContentView: View {
    var body: some View {
        
        ZStack{
            Image("borda_tv")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                
            Text("Hello, world!")
                        .padding()
        }
        
    }
}

#Preview {
    ContentView()
}

