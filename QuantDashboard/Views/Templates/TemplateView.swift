import SwiftUI

struct TemplateView: View {
    @ObservedObject var indicatorVM: IndicatorViewModel
    @StateObject private var templateManager = IndicatorTemplateManager.shared
    @State private var showSaveSheet = false
    @State private var templateName = ""
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                HStack {
                    Text("指标模板")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LiquidGlassTheme.primaryText)
                    Spacer()
                    Button { showSaveSheet = true } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 20))
                            .foregroundStyle(LiquidGlassTheme.neutralAccent)
                    }
                }
                .padding(.horizontal, 4)
                
                ForEach(templateManager.templates) { template in
                    GlassCard(title: template.name, icon: template.isDefault ? "star.fill" : "doc.text") {
                        VStack(spacing: 8) {
                            HStack {
                                Text("\(template.configs.count) 个指标")
                                    .font(.system(size: 11))
                                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
                                Spacer()
                                Text(template.createdAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 10))
                                    .foregroundStyle(LiquidGlassTheme.tertiaryText)
                            }
                            
                            Button("应用模板") {
                                templateManager.applyTemplate(template, engine: IndicatorEngine.shared)
                                indicatorVM.reloadFromEngine()
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(LiquidGlassTheme.neutralAccent))
                            
                            if !template.isDefault {
                                Button("删除") { templateManager.deleteTemplate(template) }
                                    .font(.system(size: 11))
                                    .foregroundStyle(LiquidGlassTheme.bearishAccent)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .sheet(isPresented: $showSaveSheet) {
            NavigationView {
                VStack(spacing: 16) {
                    TextField("模板名称", text: $templateName)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                    Button("保存当前配置") {
                        templateManager.saveTemplate(name: templateName, configs: indicatorVM.configs)
                        showSaveSheet = false
                        templateName = ""
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(LiquidGlassTheme.neutralAccent))
                    .disabled(templateName.isEmpty)
                    Spacer()
                }
                .padding(20)
                .background(Color.black.ignoresSafeArea())
                .navigationTitle("保存模板")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { showSaveSheet = false } } }
            }
            .preferredColorScheme(.dark)
        }
    }
}
