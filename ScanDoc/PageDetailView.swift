import SwiftUI
import UIKit

struct PageDetailView: View {
    @EnvironmentObject private var store: DocumentStore

    let documentID: UUID
    let pageID: UUID

    @State private var mode: EnhanceMode = .enhanced
    @State private var rendered: UIImage?
    @State private var isRecognizing = false
    @State private var ocrText = ""
    @State private var shareFile: ShareFile?
    @State private var errorMessage: String?
    @State private var didLoad = false

    private var page: ScannedPage? {
        store.document(id: documentID)?.pages.first(where: { $0.id == pageID })
    }

    private var pageNumber: Int {
        guard let pages = store.document(id: documentID)?.pages,
              let index = pages.firstIndex(where: { $0.id == pageID }) else { return 1 }
        return index + 1
    }

    /// 任一影响画面的因素变化，都会触发重新渲染。
    private var renderKey: String {
        "\(mode.rawValue)-\(page?.rotation ?? 0)-\(page?.imageName ?? "")"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                imageCard
                modePicker
                ocrSection
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("第 \(pageNumber) 页")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    rotate()
                } label: {
                    Image(systemName: "rotate.right")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    sharePageImage()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(item: $shareFile) { file in
            ShareSheet(items: [file.url])
        }
        .alert("出错了", isPresented: errorBinding) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear(perform: loadInitialState)
        .onChange(of: mode) { newValue in
            guard didLoad else { return }
            store.setEnhanceMode(newValue, documentID: documentID, pageID: pageID)
        }
        .task(id: renderKey) {
            await renderCurrent()
        }
    }

    // MARK: - 子视图

    private var imageCard: some View {
        ZStack {
            if let image = rendered {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(8)
            } else {
                ProgressView()
                    .frame(height: 360)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .paperStyle()
    }

    private var modePicker: some View {
        Picker("处理方式", selection: $mode) {
            ForEach(EnhanceMode.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }

    private var ocrSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("文字内容")
                    .font(.headline)
                Spacer()
                Button {
                    recognize()
                } label: {
                    if isRecognizing {
                        ProgressView()
                    } else {
                        Label(ocrText.isEmpty ? "识别文字" : "重新识别",
                              systemImage: "text.viewfinder")
                            .font(.subheadline)
                    }
                }
                .disabled(isRecognizing || rendered == nil)
            }

            if ocrText.isEmpty {
                Text("识别后可以把这一页的文字复制出来，导出的 PDF 也会变成可搜索的。全程离线，不上传任何内容。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(ocrText)
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button {
                    UIPasteboard.general.string = ocrText
                } label: {
                    Label("复制全部文字", systemImage: "doc.on.doc")
                        .font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 逻辑

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } })
    }

    private func loadInitialState() {
        guard !didLoad, let page = page else { return }
        didLoad = true
        mode = page.enhance
        ocrText = page.ocrText ?? ""
    }

    @MainActor
    private func renderCurrent() async {
        guard let page = page, let raw = store.pageImage(page) else {
            rendered = nil
            return
        }
        let target = mode
        let angle = page.rotation
        let output = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            ImageTools.render(raw, mode: target, rotation: angle)
        }.value
        rendered = output
    }

    private func rotate() {
        store.rotatePage(documentID: documentID, pageID: pageID, by: 90)
    }

    private func recognize() {
        guard let image = rendered else { return }
        isRecognizing = true
        Task { @MainActor in
            do {
                let result = try await OCRService.recognize(image)
                ocrText = result.text
                store.setOCR(result, documentID: documentID, pageID: pageID)
            } catch {
                errorMessage = error.localizedDescription
            }
            isRecognizing = false
        }
    }

    private func sharePageImage() {
        do {
            let url = try store.exportImagePage(documentID: documentID, pageID: pageID)
            shareFile = ShareFile(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
