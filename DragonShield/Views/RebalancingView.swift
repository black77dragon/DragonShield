import SwiftUI

struct RebalancingView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Rebalancing workflow coming soon")
                .font(.title3)
                .foregroundColor(.secondary)
            Spacer()
        }
        .navigationTitle("Rebalancing")
    }
}

struct RebalancingView_Previews: PreviewProvider {
    static var previews: some View {
        RebalancingView()
    }
}
