import Foundation

struct WorkspaceModel {
    var config: Config
    var token: TokenModel.Token

    enum SortBy: Decodable, CustomStringConvertible {
        case name
        case dateCreated
        case dateModified

        var description: String {
            switch self {
            case .name:
                "name"
            case .dateCreated:
                "date_created"
            case .dateModified:
                "date_modified"
            }
        }
    }

    enum SortOrder: String, Decodable {
        case asc
        case desc
    }

    struct Workspace: Decodable {
        let id: String
        let name: String
        let permission: PermissionModel.PermissionType
        let storageCapacity: Int
        let rootId: String
        let organization: OrganizationModel.Organization
        let createTime: String
        let updateTime: String?
    }

    struct List: Decodable {
        let data: [Workspace]
        let totalPages: Int
        let totalElements: Int
        let page: Int
        let size: Int
    }
}