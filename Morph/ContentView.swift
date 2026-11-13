import SwiftUI


struct ContentView: View {
    var body: some View {
        ZStack{
            
            NavigationStack {
                            HomeView()
                        }
            
            Image("borda_tv")
                .resizable()
                .ignoresSafeArea()
                
            
        }
        
    }
}

#Preview {
    ContentView()
}

