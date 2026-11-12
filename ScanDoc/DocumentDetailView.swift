import SwiftUI
import UIKit

struct DocumentDetailView: View {
    @EnvironmentObject private var store: DocumentStore
    @Environment(\.dismiss) private var dismiss

    let documentID: UUID

    @State private var showScanner = false
    @State private var shareFile: ShareFile?
    @State private var isExporting = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 130, maximum: 200), spacing: 14)]

    private var document: ScanDocument? {
        store.document(id: documentID)
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
                    exportPDF()
                } label: {
                    if isExporting {
                        ProgressView()
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(isExporting)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showScanner = true
                    } label: {
                        Label("继续扫描", systemImage: "doc.badge.plus")
                    }
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
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView { images in
                showScanner = false
                store.appendPages(documentID: documentID, images: images)
            } onCancel: {
                showScanner = false
            }
            .ignoresSafeArea()
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
        .alert("导出失败", isPresented: errorBinding) {
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
                        pageCell(page: page, index: index)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
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

    private func pageCell(page: ScannedPage, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                if let image = store.thumbnail(page, maxSide: 400) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(5)
                } else {
                    Color(uiColor: .secondarySystemBackground)
                        .frame(height: 160)
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

            Text(page.enhance.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 逻辑

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } })
    }

    private func exportPDF() {
        isExporting = true
        defer { isExporting = false }
        do {
            let url = try store.exportPDF(documentID: documentID)
            shareFile = ShareFile(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
