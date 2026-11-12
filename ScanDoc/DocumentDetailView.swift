import SwiftUI
import UIKit

struct DocumentDetailView: View {
    @EnvironmentObject private var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    let documentID: UUID

    @State private var showScanner = false
    @State private var showExport = false
    @State private var shareFile: ShareFile?
    @State private var isExporting = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?
    @State private var isRecognizingAll = false
    @State private var ocrProgress = ""
    @State private var exportOptions = ExportOptions()

    private let columns = [GridItem(.adaptive(minimum: 130, maximum: 200), spacing: 14)]

    private var document: ScanDocument? {
        store.document(id: documentID)
    }

    private var hasOCR: Bool {
        document?.pages.contains(where: { $0.hasOCR }) ?? false
    }

    var body: some View {
        Group {
            if let doc = document {
                content(doc)
            } else {
                EmptyStateView(icon: "questionmark.folder",
                               title: "文档不存在",
                               message: "它可能已经被删除了。")
            }
        }
        .navigationTitle(document?.title ?? "扫描件")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showExport = true
                } label: {
                    if isExporting {
                        ProgressView()
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(isExporting || isRecognizingAll)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showScanner = true
                    } label: {
                        Label("继续扫描", systemImage: "doc.badge.plus")
                    }
                    Button {
                        recognizeAll()
                    } label: {
                        Label("全部识别文字", systemImage: "text.viewfinder")
                    }
                    .disabled(isRecognizingAll)
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("删除文档", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay {
            if isRecognizingAll {
                recognizingOverlay
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView { images in
                showScanner = false
                store.appendPages(documentID: documentID, images: images)
            } onCancel: {
                showScanner = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showExport) {
            ExportSheet(documentTitle: document?.title ?? "扫描件",
                        hasOCR: hasOCR,
                        options: exportOptions) { options in
                exportOptions = options
                exportPDF(options: options)
            }
        }
        .sheet(item: $shareFile) { file in
            ShareSheet(items: [file.url])
        }
        .confirmationDialog("删除后无法恢复", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除文档", role: .destructive) {
                store.delete(documentID: documentID)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        }
        .alert("出错了", isPresented: errorBinding) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - 子视图

    private func content(_ doc: ScanDocument) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                ForEach(Array(doc.pages.enumerated()), id: \.element.id) { index, page in
                    NavigationLink {
                        PageDetailView(documentID: doc.id, pageID: page.id)
                    } label: {
                        pageCell(page: page, index: index, total: doc.pages.count)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            store.rotatePage(documentID: doc.id, pageID: page.id, by: 90)
                        } label: {
                            Label("顺时针旋转", systemImage: "rotate.right")
                        }
                        Button {
                            store.movePage(documentID: doc.id, pageID: page.id, offset: -1)
                        } label: {
                            Label("前移一页", systemImage: "arrow.left")
                        }
                        .disabled(index == 0)
                        Button {
                            store.movePage(documentID: doc.id, pageID: page.id, offset: 1)
                        } label: {
                            Label("后移一页", systemImage: "arrow.right")
                        }
                        .disabled(index == doc.pages.count - 1)
                        Divider()
                        Button(role: .destructive) {
                            store.deletePage(documentID: doc.id, pageID: page.id)
                        } label: {
                            Label("删除这一页", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func pageCell(page: ScannedPage, index: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                if let image = store.thumbnail(page, maxSide: 400) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(5)
                } else {
                    Color(uiColor: .secondarySystemBackground)
                }
            }
            .frame(height: 170)
            .frame(maxWidth: .infinity)
            .paperStyle()
            .overlay(alignment: .topTrailing) {
                Text("\(index + 1)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.45), in: Capsule())
                    .padding(6)
            }
            .overlay(alignment: .bottomLeading) {
                if page.hasOCR {
                    Image(systemName: "text.viewfinder")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.accentColor.opacity(0.9), in: Circle())
                        .padding(6)
                }
            }

            Text(page.enhance.title + (page.rotation == 0 ? "" : " · \(page.rotation)°"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var recognizingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 10) {
                ProgressView()
                Text(ocrProgress.isEmpty ? "正在识别文字…" : ocrProgress)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - 逻辑

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } })
    }

    private func exportPDF(options: ExportOptions) {
        isExporting = true
        defer { isExporting = false }
        do {
            let url = try store.exportPDF(documentID: documentID, options: options)
            shareFile = ShareFile(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recognizeAll() {
        isRecognizingAll = true
        ocrProgress = "正在识别 0/\(document?.pages.count ?? 0)"
        Task { @MainActor in
            let result = await store.recognizeAllPages(documentID: documentID) { done, total in
                ocrProgress = "正在识别 \(done)/\(total)"
            }
            isRecognizingAll = false
            ocrProgress = ""
            if result.done == 0 {
                errorMessage = "这些页面没有识别到文字"
            }
        }
    }
}

// MARK: - 导出设置

struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss

    let documentTitle: String
    let hasOCR: Bool
    let onExport: (ExportOptions) -> Void

    @State private var options: ExportOptions

    init(documentTitle: String,
         hasOCR: Bool,
         options: ExportOptions,
         onExport: @escaping (ExportOptions) -> Void) {
        self.documentTitle = documentTitle
        self.hasOCR = hasOCR
        self.onExport = onExport
        self._options = State(initialValue: options)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("页面尺寸") {
                    Picker("页面尺寸", selection: $options.pageSize) {
                        ForEach(ExportOptions.PageSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    Text(options.pageSize.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("文字") {
                    Toggle("嵌入可搜索文字层", isOn: $options.embedTextLayer)
                        .disabled(!hasOCR)

                    Text(hasOCR
                         ? "文字层是隐形的，不影响外观，但导出的 PDF 可以在阅读器里搜索和选中文字。"
                         : "这份文档还没识别过文字。先用「全部识别文字」跑一遍，导出的 PDF 才能搜索。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("导出 PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("导出") {
                        onExport(options)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
