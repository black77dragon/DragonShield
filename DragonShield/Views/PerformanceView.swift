import SwiftUI

struct PerformanceView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Portfolio performance coming soon")
                .font(.title3)
                .foregroundColor(.secondary)
            Spacer()
        }
        .navigationTitle("Performance")
    }
}

struct PerformanceView_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceView()
    }
}
