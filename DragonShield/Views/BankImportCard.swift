import SwiftUI

struct BankImportCard: View {
    let bankName: String
    let expectedFilename: String
    let selectedFileURL: URL?
    let note: String?
    let instructionsEnabled: Bool
    let instructionsTooltip: String
    let openInstructions: () -> Void
    let dropAction: ([URL]) -> Void
    let selectFileAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(bankName) Statement")
                    .font(.system(size: 16, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: openInstructions) {
                    Label("Instructions", systemImage: "info.circle")
                }
                .accessibilityLabel("Open instructions for \(bankName)")
                .disabled(!instructionsEnabled)
                .opacity(instructionsEnabled ? 1 : 0.5)
                .help(instructionsTooltip)
            }

            if let url = selectedFileURL {
                Text(url.lastPathComponent)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .help(url.path)
            }

            Text("Expected filename: \"\(expectedFilename)\"")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            if let note {
                Text(note)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            DropZone { urls in dropAction(urls) }
                .frame(height: 120)
                .accessibilityLabel("Drop file here to import")

            Button("Select File", action: selectFileAction)
                .buttonStyle(SecondaryButtonStyle())
                .frame(height: 32)
        }
        .padding(16)
        .background(Theme.surface)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
}

struct DropZone: View {
    var onDrop: ([URL]) -> Void
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundColor(.gray)
                .background(isTargeted ? Color.blue.opacity(0.1) : Color.clear)
            VStack {
                Image(systemName: "tray.and.arrow.down")
                Text("Drag & Drop")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers in
            var urls: [URL] = []
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url { urls.append(url) }
                }
            }
            DispatchQueue.main.async { onDrop(urls) }
            return true
        }
    }
}
