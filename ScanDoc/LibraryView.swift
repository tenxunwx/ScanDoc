import SwiftUI
import UIKit
import PhotosUI

struct LibraryView: View {
    @EnvironmentObject private var store: DocumentStore

    @State private var showScanner = false
    @State private var showPhotoPicker = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isImporting = false

    @State private var renameTarget: ScanDocument?
    @State private var renameText = ""
    @State private var deleteTarget: ScanDocument?
    @State private var searchText = ""

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 16)]

    private var filteredDocuments: [ScanDocument] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return store.documents
        }
        return store.documents.filter { $0.matches(searchText) }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("扫描件")
                .searchable(text: $searchText, prompt: "搜索标题或文内文字")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                showScanner = true
                            } label: {
                                Label("扫描文档", systemImage: "doc.text.viewfinder")
                            }
                            Button {
                                showPhotoPicker = true
                            } label: {
                                Label("从相册导入", systemImage: "photo.on.rectangle")
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                    }
                }
                .overlay {
                    if isImporting {
                        importingOverlay
                    }
                }
                .fullScreenCover(isPresented: $showScanner) {
                    scannerCover
                }
                .photosPicker(isPresented: $showPhotoPicker,
                              selection: $pickerItems,
                              maxSelectionCount: 30,
                              matching: .images)
                .onChange(of: pickerItems) { _ in
                    handleImport()
                }
                .alert("重命名", isPresented: renameBinding) {
                    TextField("文档名称", text: $renameText)
                    Button("取消", role: .cancel) { renameTarget = nil }
                    Button("保存") {
                        if let target = renameTarget {
                            store.rename(documentID: target.id, title: renameText)
                        }
                        renameTarget = nil
                    }
                }
                .confirmationDialog("删除后无法恢复",
                                    isPresented: deleteBinding,
                                    titleVisibility: .visible) {
                    Button("删除", role: .destructive) {
                        if let target = deleteTarget {
                            store.delete(documentID: target.id)
                        }
                        deleteTarget = nil
                    }
                    Button("取消", role: .cancel) { deleteTarget = nil }
                } message: {
                    Text(deleteTarget?.title ?? "")
                }
        }
    }

    // MARK: - 子视图

    @ViewBuilder
    private var content: some View {
        if store.documents.isEmpty {
            emptyState
        } else if filteredDocuments.isEmpty {
            EmptyStateView(icon: "magnifyingglass",
                           title: "没有找到",
                           message: "换个关键词试试。搜索会同时匹配文档标题和识别出来的文字。")
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(filteredDocuments) { document in
                        NavigationLink {
                            DocumentDetailView(documentID: document.id)
                        } label: {
                            DocumentCard(document: document)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                renameText = document.title
                                renameTarget = document
                            } label: {
                                Label("重命名", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                deleteTarget = document
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    private var emptyState: some View {
        VStack {
            EmptyStateView(icon: "doc.viewfinder",
                           title: "还没有扫描件",
                           message: "把纸张平放，用相机对准它。系统会自动找到边缘、把拍歪的画面拉正。")
            Button {
                showScanner = true
            } label: {
                Label("开始扫描", systemImage: "camera.viewfinder")
                    .font(.headline)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 60)
        }
    }

    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 10) {
                ProgressView()
                Text("正在导入 …").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    @ViewBuilder
    private var scannerCover: some View {
        if DocumentScannerView.isSupported {
            DocumentScannerView { images in
                showScanner = false
                store.addDocument(images: images)
            } onCancel: {
                showScanner = false
            }
            .ignoresSafeArea()
        } else {
            VStack(spacing: 20) {
                Text("这台设备不支持系统文档相机")
                    .font(.headline)
                Text("可以从相册导入照片后使用。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("关闭") { showScanner = false }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    // MARK: - 逻辑

    private var renameBinding: Binding<Bool> {
        Binding(get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } })
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } })
    }

    private func handleImport() {
        let items = pickerItems
        guard !items.isEmpty else { return }
        isImporting = true
        Task { @MainActor in
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            if !images.isEmpty {
                store.addDocument(images: images)
            }
            pickerItems = []
            isImporting = false
        }
    }
}

private struct DocumentCard: View {
    @EnvironmentObject private var store: DocumentStore
    let document: ScanDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cover
                .frame(height: 190)
                .frame(maxWidth: .infinity)
                .paperStyle()

            Text(document.title)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(document.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let page = document.pages.first, let image = store.thumbnail(page, maxSide: 440) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(6)
        } else {
            ZStack {
                Color(uiColor: .secondarySystemBackground)
                Image(systemName: "doc.text")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
