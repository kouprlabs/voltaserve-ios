import SwiftUI
import VoltaserveCore

struct InvitationRowOutgoing: View {
    @Environment(\.colorScheme) private var colorScheme
    private let invitation: VOInvitation.Entity

    init(_ invitation: VOInvitation.Entity) {
        self.invitation = invitation
    }

    var body: some View {
        HStack(spacing: VOMetrics.spacing) {
            VStack(alignment: .leading) {
                Text(invitation.email)
                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                Text(invitation.createTime.relativeDate())
                    .foregroundStyle(.gray)
                    .font(.footnote)
                if UIDevice.current.userInterfaceIdiom == .phone {
                    InvitationStatusBadge(invitation.status)
                }
            }
            Spacer()
            if UIDevice.current.userInterfaceIdiom == .pad {
                InvitationStatusBadge(invitation.status)
            }
        }
    }
}

#Preview {
    let owner = VOUser.Entity(
        id: UUID().uuidString,
        username: "anass@example.com",
        email: "anass@example.com",
        fullName: "Anass",
        createTime: Date().ISO8601Format()
    )
    NavigationView {
        List {
            InvitationRowOutgoing(
                VOInvitation.Entity(
                    id: UUID().uuidString,
                    owner: owner,
                    email: "bruce@koupr.com",
                    organization: VOOrganization.Entity(
                        id: UUID().uuidString,
                        name: "Koupr",
                        permission: .none,
                        createTime: Date().ISO8601Format()
                    ),
                    status: .pending,
                    createTime: "2024-09-23T10:00:00Z"
                )
            )
            InvitationRowOutgoing(
                VOInvitation.Entity(
                    id: UUID().uuidString,
                    owner: owner,
                    email: "tony@koupr.com",
                    organization: VOOrganization.Entity(
                        id: UUID().uuidString,
                        name: "Apple",
                        permission: .none,
                        createTime: Date().ISO8601Format()
                    ),
                    status: .accepted,
                    createTime: "2024-09-22T19:53:41Z"
                )
            )
            InvitationRowOutgoing(
                VOInvitation.Entity(
                    id: UUID().uuidString,
                    owner: owner,
                    email: "steve@koupr.com",
                    organization: VOOrganization.Entity(
                        id: UUID().uuidString,
                        name: "Qualcomm",
                        permission: .none,
                        createTime: Date().ISO8601Format()
                    ),
                    status: .declined,
                    createTime: "2024-08-22T19:53:41Z"
                )
            )
        }
    }
}