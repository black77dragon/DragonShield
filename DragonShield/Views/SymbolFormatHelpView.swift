import SwiftUI

struct SymbolFormatHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Symbol Formats")
                    .font(.title3).bold()
                Spacer()
                Button(role: .cancel) { dismiss() } label: {
                    Label("Close", systemImage: "xmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.gray)
                .foregroundColor(.white)
                .keyboardShortcut("w", modifiers: .command)
            }

            GroupBox(label: Text("Yahoo Finance").font(.headline)) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("- Use exchange suffixes (region-specific):")
                    Text("  • Switzerland (SIX): NESN.SW, SIKA.SW")
                    Text("  • Germany (XETRA): SIE.DE, ADS.DE")
                    Text("  • London (LSE): VOD.L, HSBA.L")
                    Text("  • US (NASDAQ/NYSE): AAPL, MSFT, IBM")
                    Text("- Indices/ETFs typically use the listing suffix as shown on finance.yahoo.com")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(label: Text("Finnhub").font(.headline)) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("- US tickers: use the raw symbol without .US (e.g., BE, AAPL)")
                    Text("- London (LSE): VOD.L")
                    Text("- Swiss (SIX): NESN.SW")
                    Text("- Many other exchanges follow Yahoo-style suffixes")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox(label: Text("CoinGecko (Crypto)").font(.headline)) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("- Use the CoinGecko asset id, not ticker: bitcoin, ethereum, solana")
                    Text("- See https://www.coingecko.com/en for ids")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Tip: After setting Provider + External ID, enable ‘Auto’ and click ‘Fetch Latest (Enabled)’. Use ‘View Logs’ to inspect the network details if a symbol fails.")
                .font(.footnote)
                .foregroundColor(.secondary)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(minWidth: 720, minHeight: 520)
    }
}

#if DEBUG
struct SymbolFormatHelpView_Previews: PreviewProvider {
    static var previews: some View {
        SymbolFormatHelpView()
    }
}
#endif
