import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Basketball emoji with animation
                Text("🏀")
                    .font(.system(size: 80))
                    .rotationEffect(.degrees(45))
                    .animation(.easeInOut(duration: 2).repeatForever(), value: true)
                
                // App title
                Text("Sahil's Stats")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                Text("Native iOS Basketball Tracker")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Simple button
                Button("Start Game") {
                    print("Start game tapped!")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Basketball Stats")
        }
        TabView {
            GameListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Games")
                }
            
            Text("Settings")
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
