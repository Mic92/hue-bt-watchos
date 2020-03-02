import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @ObservedObject private var bleManager = BleManager()
    var body: some View {
        Text(bleManager.status)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
