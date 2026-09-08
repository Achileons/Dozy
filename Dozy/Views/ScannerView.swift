//
//  ScannerView.swift
//  Dozy
//

import AVFoundation
import SwiftUI
import Vision
import VisionKit
import UIKit

/// Points the camera at a medicine box and hands back the first code it can read a barcode
/// out of — the 2D DataMatrix or the linear barcode printed beside it.
///
/// Shown as a sheet. The first code recognised is the result: the view buzzes, dismisses
/// itself, and calls `onScan`. A code the camera saw but that yields no barcode — a
/// DataMatrix that is not GS1, say — also ends the scan, with `nil`, so the caller can say so
/// rather than leave the camera running with nothing happening.
struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss

    let onScan: (ScanResult?) -> Void

    /// Asked for up front rather than left to VisionKit, whose availability check reports
    /// "not available" while permission is still undecided — which on a first run would
    /// show the unsupported message in place of the system prompt.
    @State private var cameraAccess = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.surface.ignoresSafeArea()
                content
            }
            .navigationTitle("Kodu okut")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
        .environment(\.locale, .turkish)
        .task {
            guard cameraAccess == .notDetermined else { return }
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraAccess = granted ? .authorized : .denied
        }
    }

    @ViewBuilder
    private var content: some View {
        if !DataScannerViewController.isSupported {
            // The simulator, and hardware without a capable camera.
            notice(
                icon: "camera.fill",
                title: "Bu cihazda kod okuma kullanılamıyor",
                detail: "Karekod veya barkod okumak için kameralı bir iPhone gerekir."
            )
        } else {
            switch cameraAccess {
            case .authorized:
                CodeScanner { result in
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                    onScan(result)
                }
                .ignoresSafeArea()
                .overlay(alignment: .bottom) { guidance }

            case .notDetermined:
                // The system prompt is up; nothing to show behind it yet.
                ProgressView()

            case .denied, .restricted:
                notice(
                    icon: "camera.fill",
                    title: "Kamera erişimi kapalı",
                    detail: "Kod okumak için Ayarlar'dan kamera iznini açabilirsin."
                )

            @unknown default:
                notice(
                    icon: "camera.fill",
                    title: "Kamera erişimi kapalı",
                    detail: "Kod okumak için Ayarlar'dan kamera iznini açabilirsin."
                )
            }
        }
    }

    /// Sits over the camera so the user knows either code on the box will do.
    private var guidance: some View {
        Text("Kutudaki karekodu veya barkodu okut")
            .font(Typography.control)
            .foregroundStyle(Palette.accentLabel)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(
                Palette.accentFill.opacity(0.85),
                in: Capsule()
            )
            .padding(.bottom, Spacing.xxl)
    }

    private func notice(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: Layout.statusIcon))
                .foregroundStyle(Palette.secondaryText)

            Text(title)
                .font(Typography.itemTitle)
                .foregroundStyle(Palette.primaryText)
                .multilineTextAlignment(.center)

            Text(detail)
                .font(Typography.itemDetail)
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
    }
}

// MARK: - VisionKit bridge

private struct CodeScanner: UIViewControllerRepresentable {
    let onScan: (ScanResult?) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            // The 2D code carries the most, but the linear barcode beside it is often the
            // easier one to get in frame, and it names the product just as well.
            recognizedDataTypes: [.barcode(symbologies: [.dataMatrix, .ean13, .ean8, .upce])],
            qualityLevel: .accurate,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        guard !controller.isScanning, !context.coordinator.didScan else { return }
        try? controller.startScanning()
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScan: (ScanResult?) -> Void
        /// Only the first code counts; the camera keeps reporting until it is stopped.
        private(set) var didScan = false

        init(onScan: @escaping (ScanResult?) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(
            _ scanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !didScan else { return }

            for item in addedItems {
                guard case .barcode(let barcode) = item,
                      let payload = barcode.payloadStringValue,
                      !payload.isEmpty
                else { continue }

                didScan = true
                scanner.stopScanning()
                onScan(ScanResolver.resolve(payload: payload, symbology: barcode.observation.symbology))
                return
            }
        }
    }
}
