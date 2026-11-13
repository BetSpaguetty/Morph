import SwiftUI


struct ContentView: View {
    var body: some View {
        
        ZStack{
            Image("borda_tv")
                .resizable()
                .scaledToFit()
                
            Text("Hello, world!")
                        .padding()
        }
        
    }
}

#Preview {
    ContentView()
}

