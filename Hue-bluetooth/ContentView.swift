import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @ObservedObject private var bleManager = BleManager()
    var body: some View {
        VStack {
            Text(bleManager.status)
            List(bleManager.bulbs) {bulb in
                HStack {
                  Text(bulb.lightOn ? "on" : "off")
                  Text(bulb.name ?? "Lookup name")
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
