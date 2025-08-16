import SwiftUI

// TODO: Fix type references when database layer is stable

/*
struct AssetMenuView: View {
    @State private var showingAddAsset = false
    @State private var showingModifyAsset = false
    @State private var showingDeleteAsset = false
    @State private var selectedAsset: DragonAsset? = nil
    @EnvironmentObject var assetManager: AssetManager
    
    var body: some View {
        VStack {
            // Dropdown menu implementation
            Menu {
                Button(action: {
                    showingAddAsset = true
                }) {
                    Label("Add an Asset", systemImage: "plus")
                }
                
                Button(action: {
                    showingModifyAsset = true
                }) {
                    Label("Modify an Asset", systemImage: "pencil")
                }
                
                Button(action: {
                    showingDeleteAsset = true
                }) {
                    Label("Delete an Asset", systemImage: "trash")
                }
            } label: {
                HStack {
                    Text("Assets")
                    Image(systemName: "chevron.down")
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Main content here
            
            // Sheet for adding a new asset
            .sheet(isPresented: $showingAddAsset) {
                VStack {
                    HStack {
                        Button("Cancel") {
                            showingAddAsset = false
                        }
                        .padding(.leading)
                        
                        Spacer()
                        
                        Text("Add New Asset")
                            .font(.headline)
                        
                        Spacer()
                    }
                    .padding(.top)
                    
                    DragonAddAssetView(onDismiss: {
                        showingAddAsset = false
                    })
                    .padding()
                }
                .frame(width: 500, height: 400)
            }
            
            // Sheet for selecting an asset to modify
            .sheet(isPresented: $showingModifyAsset) {
                VStack {
                    HStack {
                        Button("Cancel") {
                            showingModifyAsset = false
                        }
                        .padding(.leading)
                        
                        Spacer()
                        
                        Text("Select Asset to Modify")
                            .font(.headline)
                        
                        Spacer()
                    }
                    .padding(.top)
                    
                    DragonAssetSelectionView(onSelect: { asset in
                        selectedAsset = asset
                        showingModifyAsset = false
                        // Show the modification popup
                        showModificationPopup()
                    })
                    .padding()
                }
                .frame(width: 500, height: 400)
            }
            
            // Sheet for selecting an asset to delete
            .sheet(isPresented: $showingDeleteAsset) {
                VStack {
                    HStack {
                        Button("Cancel") {
                            showingDeleteAsset = false
                        }
                        .padding(.leading)
                        
                        Spacer()
                        
                        Text("Select Asset to Delete")
                            .font(.headline)
                        
                        Spacer()
                    }
                    .padding(.top)
                    
                    DragonAssetSelectionView(onSelect: { asset in
                        // Confirm deletion
                        confirmDeletion(asset)
                    })
                    .padding()
                }
                .frame(width: 500, height: 400)
            }
        }
    }
    
    // Function to show modification popup
    func showModificationPopup() {
        guard let asset = selectedAsset else { return }
        
        let modifyPopup = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        modifyPopup.title = "Modify Asset: \(asset.name)"
        modifyPopup.center()
        
        let modifyView = DragonModifyAssetView(asset: asset, onSave: {
            // Handle saving changes
            modifyPopup.close()
        }, onCancel: {
            // Handle cancellation
            modifyPopup.close()
        })
        
        modifyPopup.contentView = NSHostingView(rootView: modifyView)
        NSApp.mainWindow?.beginSheet(modifyPopup, completionHandler: nil)
    }
    
    // Function to confirm deletion
    func confirmDeletion(_ asset: DragonAsset) {
        let alert = NSAlert()
        alert.messageText = "Delete Asset"
        alert.informativeText = "Are you sure you want to delete \(asset.name)? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        alert.beginSheetModal(for: NSApp.mainWindow!) { response in
            if response == .alertFirstButtonReturn {
                // Proceed with deletion
                assetManager.deleteAsset(asset)
            }
        }
    }
}
*/
