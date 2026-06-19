import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = VoiceViewModel()

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                conversationArea
                controls
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var header: some View {
        HStack {
            Text("Funtimefirst AI")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            Button {
                viewModel.clearConversation()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.secondary)
            }
            .disabled(viewModel.isRecording)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }

    private var conversationArea: some View {
        ScrollView {
            VStack(spacing: 12) {
                if viewModel.transcript.isEmpty && viewModel.response.isEmpty {
                    Spacer(minLength: 100)
                    Image(systemName: "waveform.circle")
                        .font(.system(size: 64))
                        .foregroundColor(.blue.opacity(0.3))
                    Text("Your AI voice assistant")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Tap the mic and start speaking")
                        .font(.subheadline)
                        .foregroundColor(.secondary.opacity(0.7))
                    Spacer(minLength: 100)
                } else {
                    if !viewModel.transcript.isEmpty {
                        MessageBubble(text: viewModel.transcript, isUser: true)
                    }
                    if !viewModel.response.isEmpty {
                        MessageBubble(text: viewModel.response, isUser: false)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .animation(.easeInOut, value: viewModel.statusMessage)

            MicButton(isRecording: viewModel.isRecording) {
                viewModel.toggleRecording()
            }
        }
        .padding(.vertical, 24)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Subviews

struct MessageBubble: View {
    let text: String
    let isUser: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            if !isUser {
                Image(systemName: "cpu")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Circle())
            }

            Text(text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Color.blue : Color(.secondarySystemBackground))
                .foregroundColor(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if isUser { Spacer(minLength: 0) }
            if !isUser { Spacer(minLength: 60) }
        }
    }
}

struct MicButton: View {
    let isRecording: Bool
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.25))
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulse ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                }

                Circle()
                    .fill(isRecording ? Color.red : Color.blue)
                    .frame(width: 76, height: 76)
                    .shadow(color: isRecording ? .red.opacity(0.5) : .blue.opacity(0.4),
                            radius: isRecording ? 12 : 8)

                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .onChange(of: isRecording) { _, recording in
            pulse = recording
        }
    }
}

#Preview {
    ContentView()
}
