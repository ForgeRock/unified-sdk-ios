//
//  RecognizeEnrollCallbackView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingRecognize

struct RecognizeEnrollCallbackView: View {
    @StateObject private var viewModel: RecognizeEnrollViewModel

    init(callback: PingOneRecognizeEnrollCallback, onNext: @escaping () -> Void) {
        self._viewModel = StateObject(wrappedValue: RecognizeEnrollViewModel(callback: callback, onNext: onNext))
    }

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)

            Text("Processing biometric enrollment...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .onAppear {
            viewModel.startIfNeeded()
        }
        .onDisappear {
            viewModel.cancel()
        }
    }
}

class RecognizeEnrollViewModel: ObservableObject {
    private var task: Task<Void, Never>?
    private let callback: PingOneRecognizeEnrollCallback
    private let onNext: () -> Void
    private var hasStarted = false

    init(callback: PingOneRecognizeEnrollCallback, onNext: @escaping () -> Void) {
        self.callback = callback
        self.onNext = onNext
    }

    @MainActor
    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true

        task = Task {
            let result = await callback.enroll()
            switch result {
            case .success:
                print("Recognize enrollment succeeded")
            case .failure(let error):
                if let recognizeError = error as? RecognizeError {
                    print("Recognize enrollment failed [\(recognizeError.code)]: \(recognizeError.message)")
                } else {
                    print("Recognize enrollment failed: \(error.localizedDescription)")
                }
            }

            if !Task.isCancelled {
                await MainActor.run {
                    self.onNext()
                }
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    deinit {
        cancel()
    }
}
