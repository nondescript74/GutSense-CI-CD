//
//  QueryInputView.swift
//  GutSense
//
//  Created by Zahirudeen Premji on 3/5/26.
//


// GutSense — QueryInputView.swift
// Main query entry screen: text / photo / barcode modes
// Fires the 3-agent pipeline via QueryViewModel

import Foundation
import SwiftUI
import PhotosUI

// MARK: - Query Input View

struct QueryInputView: View {
    @ObservedObject var viewModel: QueryViewModel
    @EnvironmentObject var credentialsStore: CredentialsStore
    @Environment(\.modelContext) private var context

    // Inject profile from SwiftData
    var userProfile: UserProfile = .default
    var userSources: [UserSource] = []
    
    // Convenience accessor
    private var vm: QueryViewModel { viewModel }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Input mode selector
                    InputModePicker(selectedMode: $viewModel.inputMode)
                        .padding(.horizontal)

                    // Active input panel
                    Group {
                        switch vm.inputMode {
                        case .text:    TextInputPanel(vm: vm)
                        case .photo:   PhotoInputPanel(vm: vm)
                        case .barcode: BarcodeInputPanel(vm: vm)
                        }
                    }
                    .padding(.horizontal)

                    // Serving size selector
                    if !vm.textQuery.isEmpty || vm.capturedImage != nil || vm.barcodeValue != nil {
                        ServingAmountView(vm: vm.servingViewModel)
                            .padding(.horizontal)
                    }

                    // Credentials readiness warning
                    if !credentialsStore.isReadyForAnalysis {
                        ReadinessWarningCard()
                            .padding(.horizontal)
                    }

                    // Analyze button
                    AnalyzeButton(vm: vm)
                        .padding(.horizontal)

                    // Example queries
                    if vm.inputMode == .text && vm.textQuery.isEmpty {
                        ExampleQueriesGrid { example in
                            vm.textQuery = example
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
            .navigationTitle("GutSense")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $viewModel.showResults) {
                ThreePaneResultsView(
                    query: vm.resolvedQuery,
                    claudeResult: vm.claudeResult,
                    geminiResult: vm.geminiResult,
                    appleResult: vm.appleResult,
                    servingInfo: vm.servingViewModel.summaryLabel,
                    capturedImage: vm.capturedImage,
                    productName: vm.productName,
                    productImage: vm.productImage,
                    barcodeValue: vm.barcodeValue,
                    userProfile: vm.userProfile,
                    appleService: AppleFoundationModelService.shared,
                    simulationVM: vm.simulationVM
                )
                .navigationBarBackButtonHidden(vm.phase.isRunning)
                // Live-update as results arrive
                .onReceive(vm.$appleResult)  { _ in }
                .onReceive(vm.$claudeResult) { _ in }
                .onReceive(vm.$geminiResult) { _ in }
            }
            .onAppear {
                vm.userProfile = userProfile
                vm.userSources = userSources
                vm.modelContext = context
            }
        }
    }
}

// MARK: - Input Mode Picker

struct InputModePicker: View {
    @Binding var selectedMode: QueryInputMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(QueryInputMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedMode = mode }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.icon)
                            .font(.subheadline)
                        Text(mode.rawValue)
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedMode == mode
                        ? Color.accentColor
                        : Color.clear
                    )
                    .foregroundColor(selectedMode == mode ? .white : .secondary)
                }
                .accessibilityIdentifier("inputMode.\(mode.rawValue.lowercased())")
                .buttonStyle(.plain)

                if mode != QueryInputMode.allCases.last {
                    Divider().frame(height: 36)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
    }
}

// MARK: - Text Input Panel

struct TextInputPanel: View {
    @ObservedObject var vm: QueryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What food or meal would you like to analyze?")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)

            TextEditor(text: $vm.textQuery)
                .font(.body)
                .frame(minHeight: 100, maxHeight: 160)
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2))
                )
                .accessibilityIdentifier("queryInput.textEditor")

            if !vm.textQuery.isEmpty {
                HStack {
                    Spacer()
                    Button("Clear") {
                        vm.textQuery = ""
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("queryInput.clearButton")
                }
            }
        }
    }
}

// MARK: - Photo Input Panel

struct PhotoInputPanel: View {
    @ObservedObject var vm: QueryViewModel

    var body: some View {
        VStack(spacing: 12) {
            if let image = vm.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        Button {
                            vm.capturedImage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white, Color.black.opacity(0.6))
                        }
                        .padding(8),
                        alignment: .topTrailing
                    )
            } else {
                PhotosPicker(
                    selection: $vm.selectedPhoto,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus.fill")
                            .font(.largeTitle)
                            .foregroundColor(.accentColor)
                        Text("Choose Photo")
                            .font(.subheadline.weight(.medium))
                        Text("Select a food or meal photo from your library")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                            .foregroundColor(.gray.opacity(0.4))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("photoInput.prompt")
                .onChange(of: vm.selectedPhoto) { _, newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            vm.capturedImage = uiImage
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Barcode Input Panel

struct BarcodeInputPanel: View {
    @ObservedObject var vm: QueryViewModel
    @State private var showScanner = false

    var body: some View {
        VStack(spacing: 12) {
            if let code = vm.barcodeValue {
                VStack(spacing: 12) {
                    // Product info card
                    HStack(alignment: .top, spacing: 12) {
                        // Product image thumbnail
                        if let productImage = vm.productImage {
                            Image(uiImage: productImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        } else {
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundColor(.secondary)
                                .frame(width: 80, height: 80)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            // Product name
                            if let productName = vm.productName {
                                Text(productName)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)
                            } else {
                                Text("Loading product info...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Barcode
                            HStack(spacing: 4) {
                                Image(systemName: "barcode")
                                    .font(.caption2)
                                    .foregroundColor(.accentColor)
                                Text(code)
                                    .font(.caption.monospaced())
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Remove button
                        Button {
                            vm.barcodeValue = nil
                            vm.barcodeDetected = false
                            vm.productName = nil
                            vm.productImage = nil
                            vm.productImageURL = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(14)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .task {
                    await vm.lookupProduct(barcode: code)
                }
            } else {
                Button {
                    showScanner = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                        Text("Tap to Scan Barcode")
                            .font(.subheadline.weight(.medium))
                        Text("Point your camera at a food product barcode")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                            .foregroundColor(.gray.opacity(0.4))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("barcodeInput.prompt")
                .sheet(isPresented: $showScanner) {
                    BarcodeScannerView { code in
                        vm.barcodeValue = code
                        vm.barcodeDetected = true
                        showScanner = false
                    }
                }
            }
        }
    }
}

// MARK: - Analyze Button

struct AnalyzeButton: View {
    @ObservedObject var vm: QueryViewModel

    var body: some View {
        VStack(spacing: 8) {
            Button {
                Task { await vm.analyze() }
            } label: {
                HStack(spacing: 10) {
                    if vm.phase.isRunning {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "flask.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    Text(vm.phase.isRunning ? "Analyzing…" : "Analyze Food")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(vm.canSubmit ? Color.accentColor : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!vm.canSubmit)
            .animation(.easeInOut(duration: 0.2), value: vm.canSubmit)

            if let reason = vm.submitBlockReason {
                Text(reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Readiness Warning Card

struct ReadinessWarningCard: View {
    var body: some View {
        NavigationLink(destination: APIKeysView()) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("API Keys Required")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                    Text("Tap to configure \(CredentialsStore.shared.primaryProvider.label), Gemini, and Backend URL")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if CredentialsStore.shared.primaryProvider == .openai {
                        Text("Note: OpenAI key must be verified before use")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.25)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Example Queries Grid

struct ExampleQueriesGrid: View {
    let onSelect: (String) -> Void

    private let examples = [
        "Garlic bread with olive oil — safe for IBS-D?",
        "Is overnight oats with honey low FODMAP?",
        "Hummus and pita — fructan content?",
        "Avocado toast — polyol risk?",
        "Lentil soup cooked vs raw difference?",
        "Onion in cooking oil — does frying reduce FODMAPs?"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try an example")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .accessibilityIdentifier("exampleQueries.header")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(examples.enumerated()), id: \.offset) { index, example in
                    Button {
                        onSelect(example)
                    } label: {
                        Text(example)
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("exampleQuery.\(index)")
                }
            }
        }
    }
}

// MARK: - Barcode Scanner View (AVFoundation)

#if !os(visionOS)
import AVFoundation
import AudioToolbox

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> BarcodeScannerVC {
        BarcodeScannerVC(onScan: onScan)
    }

    func updateUIViewController(_ vc: BarcodeScannerVC, context: Context) {}
}

final class BarcodeScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    let onScan: (String) -> Void
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?

    init(onScan: @escaping (String) -> Void) {
        self.onScan = onScan
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCapture()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCapture() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { 
            print("⚠️ Failed to get camera device or input")
            return 
        }

        let session = AVCaptureSession()
        session.beginConfiguration()
        
        guard session.canAddInput(input) else {
            print("⚠️ Cannot add camera input")
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            print("⚠️ Cannot add metadata output")
            return
        }
        session.addOutput(output)
        
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean8, .ean13, .upce, .qr, .dataMatrix, .code39, .code128]
        
        session.commitConfiguration()

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(preview, at: 0)
        
        previewLayer = preview
        captureSession = session
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            print("📷 Camera session started")
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput objects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = objects.first as? AVMetadataMachineReadableCodeObject,
              let code = obj.stringValue else { return }
        print("✅ Barcode detected: \(code)")
        
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        
        captureSession?.stopRunning()
        DispatchQueue.main.async {
            self.onScan(code)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
}
#else
// visionOS fallback - barcode scanning not available
struct BarcodeScannerView: View {
    let onScan: (String) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("Barcode scanning is not available on visionOS")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Please use text input or photo mode instead")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
#endif
