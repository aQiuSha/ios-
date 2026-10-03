import Foundation
import Network
import UIKit
import SwiftData
import Combine

/// WiFi 传书服务：在设备上启动本地 HTTP 服务器，
/// 同一局域网内通过浏览器上传漫画文件。
final class WiFiTransferService: NSObject, ObservableObject {
    static let shared = WiFiTransferService()

    @Published var isRunning = false
    @Published var port: UInt16 = 8080
    @Published var uploadedFiles: [UploadedFileInfo] = []
    @Published var currentUploadProgress: Double = 0

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "com.comicreader.wifitransfer", qos: .userInitiated)

    /// 上传完成回调（在主线程调用）
    var onFileReceived: ((URL) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - 服务器控制

    func start(port: UInt16 = 8080) throws {
        guard !isRunning else { return }

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                DispatchQueue.main.async {
                    self?.isRunning = true
                    self?.port = port
                }
            case .failed(let error):
                print("WiFiTransfer listener failed: \(error)")
                DispatchQueue.main.async {
                    self?.isRunning = false
                }
            default:
                break
            }
        }

        listener.start(queue: queue)
        self.listener = listener
        AchievementService.shared.unlock(.wifiTransfer)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        DispatchQueue.main.async {
            self.isRunning = false
        }
    }

    // MARK: - 连接处理

    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: queue)

        receiveRequest(connection: connection, buffer: Data())
    }

    private func receiveRequest(connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let error {
                self.cleanupConnection(connection)
                return
            }

            var newBuffer = buffer
            if let data {
                newBuffer.append(data)
            }

            // 检查是否已收到完整的 HTTP 头部
            if let headerEnd = newBuffer.range(of: Data("\r\n\r\n".utf8)) {
                let headerData = newBuffer.subdata(in: 0..<headerEnd.lowerBound)
                let bodyStart = headerEnd.upperBound
                var body = newBuffer.subdata(in: bodyStart..<newBuffer.count)

                // 解析头部
                guard let request = self.parseHTTPRequest(headerData) else {
                    self.sendResponse(connection: connection, statusCode: 400, body: "Bad Request")
                    return
                }

                // 获取 Content-Length
                let contentLength = request.headers["Content-Length"].flatMap { Int($0) } ?? 0

                // 如果 body 还没收完，继续接收
                if body.count < contentLength {
                    let remaining = contentLength - body.count
                    self.receiveBody(connection: connection, body: body, remaining: remaining, request: request)
                    return
                }

                // 处理完整请求
                self.processRequest(connection: connection, request: request, body: body)
            } else if isComplete {
                self.cleanupConnection(connection)
            } else {
                // 继续接收
                self.receiveRequest(connection: connection, buffer: newBuffer)
            }
        }
    }

    private func receiveBody(connection: NWConnection, body: Data, remaining: Int, request: HTTPRequest) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: min(remaining, 65536)) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let error {
                self.cleanupConnection(connection)
                return
            }

            var newBody = body
            if let data {
                newBody.append(data)
            }

            let newRemaining = remaining - (data?.count ?? 0)

            // 更新上传进度
            let total = request.headers["Content-Length"].flatMap { Double($0) } ?? 1
            let received = total - Double(newRemaining)
            DispatchQueue.main.async {
                self.currentUploadProgress = min(received / total, 1.0)
            }

            if newRemaining <= 0 {
                self.processRequest(connection: connection, request: request, body: newBody)
            } else if isComplete {
                self.processRequest(connection: connection, request: request, body: newBody)
            } else {
                self.receiveBody(connection: connection, body: newBody, remaining: newRemaining, request: request)
            }
        }
    }

    // MARK: - 请求处理

    private func processRequest(connection: NWConnection, request: HTTPRequest, body: Data) {
        if request.method == "GET" {
            // 返回上传页面
            let html = Self.uploadPageHTML
            sendResponse(connection: connection, statusCode: 200, contentType: "text/html; charset=utf-8", body: html)
            return
        }

        if request.method == "POST" && request.path == "/upload" {
            handleUpload(connection: connection, request: request, body: body)
            return
        }

        sendResponse(connection: connection, statusCode: 404, body: "Not Found")
    }

    private func handleUpload(connection: NWConnection, request: HTTPRequest, body: Data) {
        // 解析 multipart/form-data
        guard let contentType = request.headers["Content-Type"],
              contentType.contains("multipart/form-data"),
              let boundary = extractBoundary(from: contentType) else {
            sendResponse(connection: connection, statusCode: 400, body: "Invalid content type")
            return
        }

        let files = parseMultipart(body: body, boundary: boundary)

        guard !files.isEmpty else {
            sendResponse(connection: connection, statusCode: 400, body: "No files uploaded")
            return
        }

        // 保存文件到临时目录并回调
        var savedURLs: [URL] = []
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WiFiUploads", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        for file in files {
            let fileURL = tempDir.appendingPathComponent(file.filename)
            do {
                // 如果已存在同名文件，先删除
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
                try file.data.write(to: fileURL)
                savedURLs.append(fileURL)

                DispatchQueue.main.async {
                    self.uploadedFiles.insert(
                        UploadedFileInfo(name: file.filename, size: file.data.count, time: Date()),
                        at: 0
                    )
                    self.onFileReceived?(fileURL)
                }
            } catch {
                print("Failed to save file: \(error)")
            }
        }

        DispatchQueue.main.async {
            self.currentUploadProgress = 0
        }

        // 返回成功页面
        let fileList = savedURLs.map { $0.lastPathComponent }.joined(separator: ", ")
        let html = Self.successPageHTML(fileCount: savedURLs.count, fileNames: fileList)
        sendResponse(connection: connection, statusCode: 200, contentType: "text/html; charset=utf-8", body: html)
    }

    // MARK: - HTTP 解析

    private func parseHTTPRequest(_ data: Data) -> HTTPRequest? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let lines = text.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return nil }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return nil }

        let method = parts[0]
        let path = parts[1]

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if let colonRange = line.range(of: ": ") {
                let key = String(line[..<colonRange.lowerBound])
                let value = String(line[colonRange.upperBound...])
                headers[key] = value
                // 也存一份不区分大小写的 key
                headers[key.lowercased()] = value
            }
        }

        return HTTPRequest(method: method, path: path, headers: headers)
    }

    private func extractBoundary(from contentType: String) -> String? {
        guard let range = contentType.range(of: "boundary=") else { return nil }
        var boundary = String(contentType[range.upperBound...])
        // 去掉可能的引号
        boundary = boundary.trimmingCharacters(in: .whitespaces)
        if boundary.hasPrefix("\"") && boundary.hasSuffix("\"") {
            boundary.removeFirst()
            boundary.removeLast()
        }
        return boundary
    }

    private func parseMultipart(body: Data, boundary: String) -> [MultipartFile] {
        let boundaryData = Data("--\(boundary)".utf8)
        var files: [MultipartFile] = []

        // 按 boundary 分割
        var searchRange = body.startIndex..<body.endIndex
        while let range = body.range(of: boundaryData, in: searchRange) {
            let partStart = range.upperBound
            // 跳过 boundary 后的 CRLF
            var partDataStart = partStart
            if body[partStart] == 0x0D && body[partStart + 1] == 0x0A {
                partDataStart = partStart + 2
            }

            // 找下一个 boundary
            let remaining = partDataStart..<body.endIndex
            guard let nextRange = body.range(of: boundaryData, in: remaining) else { break }

            let partEnd = nextRange.lowerBound
            // 去掉末尾的 CRLF
            var actualEnd = partEnd
            if actualEnd > partDataStart + 1 && body[actualEnd - 2] == 0x0D && body[actualEnd - 1] == 0x0A {
                actualEnd -= 2
            }

            let partData = body.subdata(in: partDataStart..<actualEnd)

            // 解析 part 头部和内容
            if let headerEnd = partData.range(of: Data("\r\n\r\n".utf8)) {
                let headerData = partData.subdata(in: 0..<headerEnd.lowerBound)
                let fileData = partData.subdata(in: headerEnd.upperBound..<partData.count)

                if let headerStr = String(data: headerData, encoding: .utf8),
                   let filename = extractFilename(from: headerStr),
                   !filename.isEmpty {
                    files.append(MultipartFile(filename: filename, data: fileData))
                }
            }

            searchRange = nextRange.upperBound..<body.endIndex
        }

        return files
    }

    private func extractFilename(from header: String) -> String? {
        guard let range = header.range(of: "filename=\"") else { return nil }
        let rest = header[range.upperBound...]
        guard let endRange = rest.range(of: "\"") else { return nil }
        return String(rest[..<endRange.lowerBound])
    }

    // MARK: - 响应发送

    private func sendResponse(connection: NWConnection, statusCode: Int, contentType: String = "text/plain; charset=utf-8", body: String) {
        let bodyData = body.data(using: .utf8) ?? Data()
        let statusText = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        let response = """
        HTTP/1.1 \(statusCode) \(statusText)\r
        Content-Type: \(contentType)\r
        Content-Length: \(bodyData.count)\r
        Connection: close\r
        \r
        """
        var responseData = response.data(using: .utf8)!
        responseData.append(bodyData)

        connection.send(content: responseData, completion: .contentProcessed { [weak self] _ in
            self?.cleanupConnection(connection)
        })
    }

    private func cleanupConnection(_ connection: NWConnection) {
        connection.cancel()
        connections.removeAll { $0 === connection }
    }

    // MARK: - 获取 WiFi IP 地址

    static func getWiFiIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            guard let interface = ptr?.pointee else { continue }

            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                }
            }
        }
        return address
    }
}

// MARK: - 数据结构

struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
}

struct MultipartFile {
    let filename: String
    let data: Data
}

struct UploadedFileInfo: Identifiable {
    let id = UUID()
    let name: String
    let size: Int
    let time: Date

    var sizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        return formatter.string(fromByteCount: Int64(size))
    }
}

// MARK: - 内嵌 HTML 页面

extension WiFiTransferService {
    static var uploadPageHTML: String {
        """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>WiFi 传书 - ComicReader</title>
        <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: #1c1c1e;
            color: #fff;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: #2c2c2e;
            border-radius: 16px;
            padding: 40px;
            max-width: 500px;
            width: 100%;
            text-align: center;
        }
        h1 { font-size: 24px; margin-bottom: 8px; }
        .subtitle { color: #8e8e93; font-size: 14px; margin-bottom: 32px; }
        .upload-area {
            border: 2px dashed #48484a;
            border-radius: 12px;
            padding: 48px 24px;
            cursor: pointer;
            transition: all 0.2s;
            margin-bottom: 20px;
        }
        .upload-area:hover, .upload-area.dragover {
            border-color: #007aff;
            background: rgba(0,122,255,0.05);
        }
        .upload-icon { font-size: 48px; margin-bottom: 12px; }
        .upload-text { font-size: 16px; color: #aeaeb2; }
        .upload-hint { font-size: 13px; color: #636366; margin-top: 8px; }
        input[type=file] { display: none; }
        .btn {
            background: #007aff;
            color: #fff;
            border: none;
            padding: 14px 32px;
            border-radius: 10px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            width: 100%;
            transition: opacity 0.2s;
        }
        .btn:disabled { opacity: 0.5; cursor: not-allowed; }
        .btn:hover:not(:disabled) { opacity: 0.9; }
        .progress-bar {
            width: 100%;
            height: 6px;
            background: #3a3a3c;
            border-radius: 3px;
            margin-top: 16px;
            overflow: hidden;
            display: none;
        }
        .progress-fill {
            height: 100%;
            background: #007aff;
            width: 0%;
            transition: width 0.3s;
        }
        .file-list {
            margin-top: 16px;
            text-align: left;
            font-size: 13px;
            color: #8e8e93;
        }
        .file-item {
            padding: 6px 0;
            border-bottom: 1px solid #3a3a3c;
        }
        .formats {
            margin-top: 24px;
            padding-top: 20px;
            border-top: 1px solid #3a3a3c;
            font-size: 12px;
            color: #636366;
        }
        </style>
        </head>
        <body>
        <div class="container">
            <h1>📚 WiFi 传书</h1>
            <p class="subtitle">选择漫画文件上传到设备</p>
            <form id="uploadForm" action="/upload" method="post" enctype="multipart/form-data">
                <label class="upload-area" id="uploadArea">
                    <div class="upload-icon">📁</div>
                    <div class="upload-text">点击选择或拖拽文件到此处</div>
                    <div class="upload-hint">支持多选</div>
                    <input type="file" name="files" id="fileInput" multiple accept=".cbz,.zip,.cbr,.rar,.cb7,.7z,.cbt,.tar,.gz,.tgz,.bz2,.tbz,.xz,.txz,.epub,.pdf,.jpg,.jpeg,.png,.webp,.gif,.bmp,.tiff,.heic,.avif">
                </label>
                <div class="file-list" id="fileList"></div>
                <button type="submit" class="btn" id="submitBtn" disabled>开始上传</button>
                <div class="progress-bar" id="progressBar">
                    <div class="progress-fill" id="progressFill"></div>
                </div>
            </form>
            <div class="formats">支持格式：CBZ / ZIP / CBR / PDF / JPG / PNG / WebP / GIF</div>
        </div>
        <script>
        const fileInput = document.getElementById('fileInput');
        const uploadArea = document.getElementById('uploadArea');
        const fileList = document.getElementById('fileList');
        const submitBtn = document.getElementById('submitBtn');
        const form = document.getElementById('uploadForm');
        const progressBar = document.getElementById('progressBar');
        const progressFill = document.getElementById('progressFill');

        fileInput.addEventListener('change', updateFileList);

        uploadArea.addEventListener('dragover', (e) => {
            e.preventDefault();
            uploadArea.classList.add('dragover');
        });
        uploadArea.addEventListener('dragleave', () => {
            uploadArea.classList.remove('dragover');
        });
        uploadArea.addEventListener('drop', (e) => {
            e.preventDefault();
            uploadArea.classList.remove('dragover');
            fileInput.files = e.dataTransfer.files;
            updateFileList();
        });

        function updateFileList() {
            const files = fileInput.files;
            fileList.innerHTML = '';
            if (files.length > 0) {
                submitBtn.disabled = false;
                for (let f of files) {
                    const size = (f.size / 1024 / 1024).toFixed(2);
                    fileList.innerHTML += '<div class="file-item">📄 ' + f.name + ' (' + size + ' MB)</div>';
                }
            } else {
                submitBtn.disabled = true;
            }
        }

        form.addEventListener('submit', (e) => {
            e.preventDefault();
            const formData = new FormData(form);
            const xhr = new XMLHttpRequest();
            xhr.open('POST', '/upload', true);

            progressBar.style.display = 'block';
            submitBtn.disabled = true;
            submitBtn.textContent = '上传中...';

            xhr.upload.addEventListener('progress', (e) => {
                if (e.lengthComputable) {
                    const pct = (e.loaded / e.total * 100).toFixed(0);
                    progressFill.style.width = pct + '%';
                }
            });

            xhr.onload = () => {
                if (xhr.status === 200) {
                    document.body.innerHTML = xhr.responseText;
                } else {
                    alert('上传失败：' + xhr.status);
                    submitBtn.disabled = false;
                    submitBtn.textContent = '开始上传';
                    progressBar.style.display = 'none';
                }
            };

            xhr.onerror = () => {
                alert('上传出错，请检查网络连接');
                submitBtn.disabled = false;
                submitBtn.textContent = '开始上传';
                progressBar.style.display = 'none';
            };

            xhr.send(formData);
        });
        </script>
        </body>
        </html>
        """
    }

    static func successPageHTML(fileCount: Int, fileNames: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>上传成功 - ComicReader</title>
        <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            background: #1c1c1e;
            color: #fff;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: #2c2c2e;
            border-radius: 16px;
            padding: 48px 40px;
            max-width: 500px;
            width: 100%;
            text-align: center;
        }
        .icon { font-size: 64px; margin-bottom: 20px; }
        h1 { font-size: 24px; margin-bottom: 12px; }
        .info { color: #8e8e93; font-size: 14px; margin-bottom: 8px; word-break: break-all; }
        .btn {
            display: inline-block;
            margin-top: 28px;
            background: #007aff;
            color: #fff;
            text-decoration: none;
            padding: 14px 32px;
            border-radius: 10px;
            font-size: 16px;
            font-weight: 600;
        }
        .hint { margin-top: 20px; font-size: 13px; color: #636366; }
        </style>
        </head>
        <body>
        <div class="container">
            <div class="icon">✅</div>
            <h1>上传成功</h1>
            <p class="info">已接收 \(fileCount) 个文件</p>
            <p class="info">\(fileNames)</p>
            <p class="hint">文件正在后台导入，请在设备上查看漫画书架</p>
            <a href="/" class="btn">继续上传</a>
        </div>
        </body>
        </html>
        """
    }
}
