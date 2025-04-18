// Copyright (c) 2024 Anass Bouassaba.
//
// Use of this software is governed by the Business Source License
// included in the file LICENSE in the root of this repository.
//
// As of the Change Date specified in that file, in accordance with
// the Business Source License, use of this software will be governed
// by the GNU Affero General Public License v3.0 only, included in the file
// AGPL-3.0-only in the root of this repository.

import Foundation

public struct VOErrorResponse: Decodable, Error {
    public let code: Code
    public let status: Int
    public let message: String
    public let userMessage: String
    public let moreInfo: String

    public init(code: Code, status: Int, message: String, userMessage: String, moreInfo: String) {
        self.code = code
        self.status = status
        self.message = message
        self.userMessage = userMessage
        self.moreInfo = moreInfo
    }

    public enum Code: String, Codable, CaseIterable {
        // API
        case groupNotFound = "group_not_found"
        case fileNotFound = "file_not_found"
        case invalidPath = "invalid_path"
        case workspaceNotFound = "workspace_not_found"
        case organizationNotFound = "organization_not_found"
        case taskNotFound = "task_not_found"
        case snapshotNotFound = "snapshot_not_found"
        case s3ObjectNotFound = "s3_object_not_found"
        case userNotFound = "user_not_found"
        case insightsNotFound = "insights_not_found"
        case mosaicNotFound = "mosaic_not_found"
        case invitationNotFound = "invitation_not_found"
        case snapshotCannotBePatched = "snapshot_cannot_be_patched"
        case snapshotHasPendingTask = "snapshot_has_pending_task"
        case taskIsRunning = "task_is_running"
        case taskBelongsToAnotherUser = "task_belongs_to_another_user"
        case missingOrganizationPermission = "missing_organization_permission"
        case cannotRemoveSoleOwnerOfOrganization = "cannot_remove_sole_owner_of_organization"
        case cannotRemoveLastOwnerOfGroup = "cannot_remove_last_owner_of_group"
        case missingGroupPermission = "missing_group_permission"
        case missingWorkspacePermission = "missing_workspace_permission"
        case missingFilePermission = "missing_file_permission"
        case s3Error = "s3_error"
        case missingQueryParam = "missing_query_param"
        case invalidPathParam = "invalid_path_param"
        case invalidQueryParam = "invalid_query_param"
        case storageLimitExceeded = "storage_limit_exceeded"
        case insufficientStorageCapacity = "insufficient_storage_capacity"
        case fileAlreadyChildOfDestination = "file_already_child_of_destination"
        case fileCannotBeMovedIntoItself = "file_cannot_be_moved_into_itself"
        case fileIsNotAFolder = "file_is_not_a_folder"
        case fileIsNotAFile = "file_is_not_a_file"
        case targetIsGrantChildOfSource = "target_is_grant_child_of_source"
        case cannotDeleteWorkspaceRoot = "cannot_delete_workspace_root"
        case fileCannotBeCopedIntoOwnSubtree = "file_cannot_be_coped_into_own_subtree"
        case fileCannotBeCopiedIntoItself = "file_cannot_be_copied_into_itself"
        case fileWithSimilarNameExists = "file_with_similar_name_exists"
        case invalidPageParameter = "invalid_page_parameter"
        case invalidSizeParameter = "invalid_size_parameter"
        case cannotAcceptNonPendingInvitation = "cannot_accept_non_pending_invitation"
        case cannotDeclineNonPendingInvitation = "cannot_decline_non_pending_invitation"
        case cannotResendNonPendingInvitation = "cannot_resend_non_pending_invitation"
        case userNotAllowedToAcceptInvitation = "user_not_allowed_to_accept_invitation"
        case userNotAllowedToDeclineInvitation = "user_not_allowed_to_decline_invitation"
        case userNotAllowedToDeleteInvitation = "user_not_allowed_to_delete_invitation"
        case userAlreadyMemberOfOrganization = "user_already_member_of_organization"
        case invalidApiKey = "invalid_api_key"
        case pathVariablesAndBodyParametersNotConsistent = "path_variables_and_body_parameters_not_consistent"

        // IdP
        case usernameUnavailable = "username_unavailable"
        case resourceNotFound = "resource_not_found"
        case invalidUsernameOrPassword = "invalid_username_or_password"
        case invalidPassword = "invalid_password"
        case invalidJwt = "invalid_jwt"
        case invalidCredentials = "invalid_credentials"
        case emailNotConfimed = "email_not_confirmed"
        case refreshKeyExpired = "refresh_key_expired"
        case invalidRequest = "invalid_request"
        case unsupportedGrantType = "unsupported_grant_type"
        case passwordValidationFailed = "password_validation_failed"

        // Common
        case internalServerError = "internal_server_error"
        case requestValidationError = "request_validation_error"

        // Unexpected
        case unknown

        public init(rawValue: String) {
            if let validCase = Code.allCases.first(where: { $0.rawValue == rawValue }) {
                self = validCase
            } else {
                self = .unknown
            }
        }
    }
}
