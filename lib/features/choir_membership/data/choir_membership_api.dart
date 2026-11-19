import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/di/core_providers.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../notifications/data/notification_dto.dart';

typedef JoinableChoir = ({String id, String name});

enum ChoirRequestStatus {
  pending('Pending', 'Chờ xử lý'),
  approved('Approved', 'Đã chấp thuận'),
  rejected('Rejected', 'Đã từ chối'),
  cancelled('Cancelled', 'Đã hủy'),
  unknown('', 'Chưa rõ trạng thái');

  const ChoirRequestStatus(this.wire, this.label);
  final String wire;
  final String label;
}

class ChoirJoinRequest {
  ChoirJoinRequest.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      member = json['memberFullName'] as String,
      choirName = json['choirName'] as String,
      currentChoirId = json['currentChoirId'] as String?,
      currentChoirName = json['currentChoirName'] as String?,
      isInvitation = json['isInvitation'] as bool,
      status = ChoirRequestStatus.values.firstWhere(
        (status) => status.wire == json['status'],
        orElse: () => ChoirRequestStatus.unknown,
      ),
      message = json['message'] as String?,
      rejectReason = json['rejectReason'] as String?,
      createdAt = DateTime.parse(json['createdAt'] as String);

  final String id;
  final String member;
  final String choirName;
  final String? currentChoirId;
  final String? currentChoirName;
  final bool isInvitation;
  final ChoirRequestStatus status;
  final String? message;
  final String? rejectReason;
  final DateTime createdAt;
}

enum ChoirRequestAction { approve, reject, cancel }

class ChoirMembershipApi {
  ChoirMembershipApi(this._client, this._epoch);
  final ApiClient _client;
  final int _epoch;
  static const _requests = '/api/choir-join-requests';

  Future<T?> _request<T>(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    try {
      return (await _client.dio.request<T>(
        path,
        queryParameters: query,
        data: body,
        options: Options(
          method: method,
          extra: {'expectedSessionEpoch': _epoch},
        ),
      )).data;
    } on DioException catch (error) {
      throw ApiClient.parseDioException(error);
    }
  }

  Future<List<JoinableChoir>> catalog() async {
    final rows = (await _request<List<dynamic>>('GET', ApiEndpoints.choirs))!;
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        if (row['isActive'] == true)
          (id: row['id'] as String, name: row['name'] as String),
    ];
  }

  Future<PagedList<ChoirJoinRequest>> requests(
    int page, {
    String? choirId,
  }) async {
    final response = (await _request<Map<String, dynamic>>(
      'GET',
      _requests,
      query: {'pageNumber': page, 'pageSize': 20, 'choirId': ?choirId},
    ))!;
    return PagedList.fromJson(response, ChoirJoinRequest.fromJson);
  }

  Future<void> submit(String choirId, {String? message}) async {
    requireMemberManagementId(choirId);
    if ((message?.length ?? 0) > 500) {
      throw const ValidationException(code: 'CHOIR_JOIN_REQUEST_TEXT_TOO_LONG');
    }
    await _request<Object?>(
      'POST',
      _requests,
      body: {'choirId': choirId, 'message': ?message},
    );
  }

  Future<void> review(
    ChoirJoinRequest request,
    ChoirRequestAction action, {
    String? reason,
  }) async {
    requireMemberManagementId(request.id);
    if (request.status != ChoirRequestStatus.pending) {
      throw const ConflictException(code: 'CHOIR_JOIN_REQUEST_NOT_PENDING');
    }
    final text = reason?.trim();
    if (action == ChoirRequestAction.reject) {
      if (!request.isInvitation && (text == null || text.isEmpty)) {
        throw const ValidationException(
          code: 'CHOIR_JOIN_REQUEST_REJECT_REASON_REQUIRED',
        );
      }
      if ((reason?.length ?? 0) > 500) {
        throw const ValidationException(
          code: 'CHOIR_JOIN_REQUEST_TEXT_TOO_LONG',
        );
      }
    }
    await _request<Object?>(
      'POST',
      '$_requests/${Uri.encodeComponent(request.id)}/${action.name}',
      body: action == ChoirRequestAction.reject ? {'reason': ?text} : null,
    );
  }

  Future<void> leave(String choirId) async {
    requireMemberManagementId(choirId);
    await _request<Object?>(
      'POST',
      '${ApiEndpoints.choirs}/${Uri.encodeComponent(choirId)}/leave',
    );
  }
}

final choirMembershipApiProvider = Provider<ChoirMembershipApi>((ref) {
  final epoch = ref.watch(
    sessionManagerProvider.select((session) => session.sessionEpoch),
  );
  return ChoirMembershipApi(ref.watch(apiClientProvider), epoch);
});

final _resourceGuid = RegExp(
  r'^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

void requireMemberManagementId(String value) {
  if (value.length != 36 ||
      !_resourceGuid.hasMatch(value) ||
      value == '00000000-0000-0000-0000-000000000000') {
    throw const ValidationException(code: 'MEMBER_MANAGEMENT_ID_INVALID');
  }
}
