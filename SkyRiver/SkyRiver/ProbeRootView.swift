import SwiftUI
import WebKit

struct ProbeWebView: UIViewRepresentable {
    @ObservedObject var controller: ProbeWebController

    func makeUIView(context: Context) -> WKWebView {
        controller.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct ProbeRootView: View {
    @StateObject private var store: CaptureStore
    @StateObject private var controller: ProbeWebController

    @State private var showLog = false
    @State private var showGuide = true

    init() {
        let store = CaptureStore()
        _store = StateObject(wrappedValue: store)
        _controller = StateObject(wrappedValue: ProbeWebController(store: store))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ProbeWebView(controller: controller)
                    .ignoresSafeArea(edges: .bottom)

                logButton
            }
            .navigationTitle(controller.pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        controller.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!controller.canGoBack)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        controller.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showLog) {
                CaptureLogView(store: store)
            }
            .overlay(alignment: .top) {
                if showGuide {
                    guideCard
                }
            }
            .task {
                controller.startPolling()
            }
        }
    }

    private var logButton: some View {
        Button {
            showLog = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.footnote)
                Text("\(store.items.count)")
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .overlay(
                Capsule().stroke(Color.accentColor.opacity(store.items.isEmpty ? 0.2 : 0.55), lineWidth: 1)
            )
        }
        .padding(16)
    }

    private var guideCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "hand.point.up.left.fill")
                    .foregroundStyle(Color.accentColor)
                Text("怎么用")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    withAnimation { showGuide = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("1. 用你的账号在下面登录\n2. 依次点开：分类 → 查课 → 下单 → 我的作业 → 余额\n3. 点右下角数字，就能看到这一路所有接口")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }
}
