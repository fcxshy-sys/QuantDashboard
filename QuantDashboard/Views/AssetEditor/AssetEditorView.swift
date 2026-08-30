import SwiftUI

struct AssetEditorView: View {
    @Binding var selectedAssets: [TradeAsset]
    @Environment(\.dismiss) private var dismiss
    
    @State private var available: [TradeAsset] = TradeAsset.allCases
    
    var body: some View {
        NavigationView {
            List {
                Section("已选资产 (拖拽排序)") {
                    ForEach(selectedAssets) { asset in
                        HStack {
                            Circle()
                                .fill(asset.themeColor)
                                .frame(width: 10, height: 10)
                            Text(asset.rawValue)
                            Spacer()
                            Button {
                                selectedAssets.removeAll { $0.id == asset.id }
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(LiquidGlassTheme.bearishAccent)
                            }
                        }
                    }
                    .onMove { from, to in
                        selectedAssets.move(fromOffsets: from, toOffset: to)
                    }
                }
                
                Section("可添加资产") {
                    ForEach(available.filter { !selectedAssets.contains($0) }) { asset in
                        Button {
                            selectedAssets.append(asset)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(asset.themeColor)
                                    .frame(width: 10, height: 10)
                                Text(asset.rawValue)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(LiquidGlassTheme.bullishAccent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("自选资产")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }
}
