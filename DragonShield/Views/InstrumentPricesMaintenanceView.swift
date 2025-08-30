import SwiftUI

struct InstrumentPricesMaintenanceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instrument Prices Maintenance")
                .font(.title2).bold()
            Text("View, filter, and update latest prices across instruments.")
                .foregroundColor(.secondary)
            Divider()
            Text("This is a placeholder. See docs/price_maintenance_ui_proposal.md for the full plan.")
                .font(.callout)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(24)
    }
}

#if DEBUG
struct InstrumentPricesMaintenanceView_Previews: PreviewProvider {
    static var previews: some View {
        InstrumentPricesMaintenanceView()
            .frame(width: 720, height: 420)
    }
}
#endif

