import SwiftUI
import VoltaserveCore

struct TaskStatusBadge: View {
    var status: VOTask.Status

    init(_ status: VOTask.Status) {
        self.status = status
    }

    var body: some View {
        Text(text())
            .font(.footnote)
            .padding(.horizontal)
            .frame(height: 20)
            .foregroundStyle(background().textColor())
            .background(background())
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    func text() -> String {
        switch status {
        case .waiting:
            "Waiting"
        case .running:
            "Running"
        case .success:
            "Success"
        case .error:
            "Error"
        }
    }

    func background() -> Color {
        switch status {
        case .waiting:
            Color.gray300
        case .running:
            Color.blue300
        case .success:
            Color.green300
        case .error:
            Color.red300
        }
    }
}

#Preview {
    TaskStatusBadge(.waiting)
    TaskStatusBadge(.running)
    TaskStatusBadge(.success)
    TaskStatusBadge(.error)
}