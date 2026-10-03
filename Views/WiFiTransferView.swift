import SwiftUI
import SwiftData

/// WiFi 传书页面
struct WiFiTransferView: View {
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var transferService = WiFiTransferService.shared
    @State private var ipAddress: String = ""
    @State private var showStartError = false
    @State private var startErrorMessage = ""
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            List {
                // 服务器状态
                Section {
                    VStack(spacing: 16) {
                        // 状态图标
                        ZStack {
                            Circle()
                                .fill(transferService.isRunning ? Color.green.opacity(0.15) : Color.gray.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Image(systemName: transferService.isRunning ? "wifi.circle.fill" : "wifi.slash")
                                .font(.system(size: 40))
                                .foregroundColor(transferService.isRunning ? .green : .gray)
                        }

                        Text(transferService.isRunning ? "WiFi 传书已开启" : "WiFi 传书未开启")
                            .font(.headline)

                        if transferService.isRunning {
                            // 地址显示
                            VStack(spacing: 8) {
                                Text("在电脑浏览器中访问：")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                if let ip = ipAddress.isEmpty ? WiFiTransferService.getWiFiIPAddress() : ipAddress, !ip.isEmpty {
                                    Text("http://\(ip):\(transferService.port)")
                                        .font(.system(.title3, design: .monospaced))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                        .textSelection(.enabled)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                } else {
                                    Text("未检测到 WiFi 连接")
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                }

                                Text("确保手机和电脑连接同一个 WiFi")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // 开关按钮
                        Button {
                            toggleServer()
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: transferService.isRunning ? "stop.circle.fill" : "play.circle.fill")
                                Text(transferService.isRunning ? "停止服务" : "开启服务")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .foregroundColor(transferService.isRunning ? .red : .white)
                            .padding(.vertical, 14)
                            .background(transferService.isRunning ? Color.red.opacity(0.15) : Color.blue)
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 8)
                }

                // 上传进度
                if transferService.isRunning && transferService.currentUploadProgress > 0 {
                    Section("正在上传") {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: transferService.currentUploadProgress)
                            Text("\(Int(transferService.currentUploadProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // 已上传文件列表
                if !transferService.uploadedFiles.isEmpty {
                    Section("已上传 (\(transferService.uploadedFiles.count))") {
                        ForEach(transferService.uploadedFiles) { file in
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Text(file.sizeString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // 使用说明
                Section("使用说明") {
                    VStack(alignment: .leading, spacing: 12) {
                        stepView(number: 1, text: "确保手机和电脑连接同一个 WiFi 网络")
                        stepView(number: 2, text: "点击「开启服务」启动传书服务")
                        stepView(number: 3, text: "在电脑浏览器中输入显示的地址")
                        stepView(number: 4, text: "选择 CBZ/ZIP/CBR/PDF 或图片文件，点击上传")
                        stepView(number: 5, text: "上传完成后自动导入漫画书架")
                    }
                    .padding(.vertical, 4)
                }

                Section("注意事项") {
                    Label("传书过程中请保持 App 在前台运行", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Label("支持格式：CBZ / ZIP / CBR / PDF / JPG / PNG / WebP / GIF", systemImage: "doc")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Label("大文件上传可能需要较长时间", systemImage: "clock")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("WiFi 传书")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("启动失败", isPresented: $showStartError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(startErrorMessage)
            }
            .overlay {
                if isImporting {
                    ProgressView("正在导入漫画...")
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
            .onAppear {
                ipAddress = WiFiTransferService.getWiFiIPAddress() ?? ""
                setupFileCallback()
            }
            .onDisappear {
                // 页面关闭时不自动停止服务，让用户可以后台保持（虽然 iOS 后台有限制）
            }
        }
    }

    private func stepView(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.blue))
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
        }
    }

    private func toggleServer() {
        if transferService.isRunning {
            transferService.stop()
        } else {
            do {
                try transferService.start(port: 8080)
                ipAddress = WiFiTransferService.getWiFiIPAddress() ?? ""
            } catch {
                startErrorMessage = "无法启动服务：\(error.localizedDescription)\n请尝试更换端口或检查网络设置。"
                showStartError = true
            }
        }
    }

    private func setupFileCallback() {
        transferService.onFileReceived = { (fileURL: URL) in
            Task { @MainActor in
                isImporting = true
                defer { isImporting = false }

                do {
                    _ = try await ComicImportService.shared.importComic(
                        from: fileURL,
                        modelContext: modelContext
                    )
                    // 导入成功后删除临时文件
                    try? FileManager.default.removeItem(at: fileURL)
                } catch {
                    print("WiFi import failed: \(error)")
                }
            }
        }
    }
}
