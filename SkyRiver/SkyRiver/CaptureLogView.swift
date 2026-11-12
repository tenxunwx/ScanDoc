import SwiftUI
import UIKit

struct FileRef: Identifiable {
    let id = UUID()
    let url: URL
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct CaptureLogView: View {
    @ObservedObject var store: CaptureStore
    @Environment(\.dismiss) private var dismiss

    @State private var shareFile: FileRef?
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if store.items.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("抓到的接口（\(store.items.count)）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            if let url = store.exportJSON() {
                                shareFile = FileRef(url: url)
                            }
                        } label: {
                            Label("导出 JSON", systemImage: "doc.badge.arrow.up")
                        }
                        Button {
                            UIPasteboard.general.string = store.exportText()
                        } label: {
                            Label("复制为文本", systemImage: "doc.on.doc")
                        }
                        Divider()
                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            Label("清空记录", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $shareFile) { file in
                ActivityView(items: [file.url])
            }
            .confirmationDialog("清空后无法恢复", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("清空", role: .destructive) { store.clear() }
                Button("取消", role: .cancel) {}
            }
        }
    }

    private var list: some View {
        List {
            ForEach(store.items) { item in
                NavigationLink {
                    CaptureDetailView(item: item)
                } label: {
                    row(item)
                }
            }
        }
        .listStyle(.plain)
    }

    private func row(_ item: CapturedRequest) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(item.method)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(methodColor(item.method))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(methodColor(item.method).opacity(0.12), in: RoundedRectangle(cornerRadius: 4))

                Text(item.statusText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(item.time.formatted(date: .omitted, time: .standard))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text(item.path)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
    }

    private func methodColor(_ method: String) -> Color {
        switch method.uppercased() {
        case "GET": return .blue
        case "POST": return .green
        case "PUT", "PATCH": return .orange
        case "DELETE": return .red
        default: return .gray
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("还没有抓到请求")
                .font(.headline)
            Text("回到页面里正常操作几步，比如打开课程分类、查一次课，这里就会出现记录。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CaptureDetailView: View {
    let item: CapturedRequest

    var body: some View {
        List {
            Section("请求") {
                labeled("方法", item.method)
                labeled("状态", item.statusText)
                labeled("地址", item.url)
            }

            if !item.body.isEmpty {
                Section("请求参数") {
                    Text(item.body)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            if !item.response.isEmpty {
                Section {
                    Text(item.response)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                } header: {
                    Text("响应")
                }
            }

            Section {
                Button {
                    UIPasteboard.general.string = "\(item.method) \(item.url)\n\(item.body)\n\n\(item.response)"
                } label: {
                    Label("复制这一条", systemImage: "doc.on.doc")
                }
            }
        }
        .navigationTitle(item.path)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}
