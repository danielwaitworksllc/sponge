import SwiftUI

struct ToastMessage: Equatable {
    let id: UUID
    let message: String
    let icon: String
    let type: ToastType

    enum ToastType {
        case success
        case error
        case info

        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .info: return .blue
            }
        }
    }

    init(message: String, icon: String = "checkmark.circle.fill", type: ToastType = .success) {
        self.id = UUID()
        self.message = message
        self.icon = icon
        self.type = type
    }

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(toast.type.color)

            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusM)
                .fill(SpongeTheme.surfacePrimary)
                .shadow(color: SpongeTheme.shadowM, radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SpongeTheme.cornerRadiusM)
                .stroke(toast.type.color.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

// Toast container that handles showing/hiding
struct ToastContainerModifier: ViewModifier {
    @Binding var toast: ToastMessage?
    let duration: Double

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toast {
                    ToastView(toast: toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 10)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    self.toast = nil
                                }
                            }
                        }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toast)
    }
}

extension View {
    func toast(_ toast: Binding<ToastMessage?>, duration: Double = 3.0) -> some View {
        modifier(ToastContainerModifier(toast: toast, duration: duration))
    }
}


#Preview {
    VStack {
        Spacer()
        ToastView(toast: ToastMessage(message: "PDF saved to Google Drive/Classes", icon: "checkmark.circle.fill", type: .success))
        Spacer()
    }
}
