import '../../domain/institution_group_membership.dart';
import 'institution_group_membership_dto.dart';

class InstitutionGroupMembershipMutationDto {
  const InstitutionGroupMembershipMutationDto({required this.memberships});

  factory InstitutionGroupMembershipMutationDto.fromJson(
    Object? json, {
    required InstitutionGroupMemberKind kind,
    required List<String> submittedIds,
  }) {
    final envelope = readExactMembershipMap(
      json,
      context: 'Institution Group membership assignment envelope',
      keys: const {'data', 'message'},
    );
    final expectedMessage = switch (kind) {
      InstitutionGroupMemberKind.teacher =>
        'Teachers assigned to group successfully.',
      InstitutionGroupMemberKind.student =>
        'Students assigned to group successfully.',
    };
    if (envelope['message'] != expectedMessage) {
      throw const FormatException(
        'Membership assignment message did not match the endpoint.',
      );
    }
    final rawMemberships = envelope['data'];
    if (rawMemberships is! List<Object?> ||
        rawMemberships.length != submittedIds.length) {
      throw const FormatException(
        'Membership assignment data length did not match the request.',
      );
    }
    final memberships = List<InstitutionGroupMembershipDto>.unmodifiable(
      rawMemberships.map(InstitutionGroupMembershipDto.fromJson),
    );
    final seen = <String>{};
    for (var index = 0; index < memberships.length; index += 1) {
      final returnedId = memberships[index].id.toLowerCase();
      if (!seen.add(returnedId) ||
          returnedId != submittedIds[index].toLowerCase()) {
        throw const FormatException(
          'Membership assignment IDs or order did not match the request.',
        );
      }
    }
    return InstitutionGroupMembershipMutationDto(memberships: memberships);
  }

  final List<InstitutionGroupMembershipDto> memberships;

  List<InstitutionGroupMembership> toDomain() =>
      List<InstitutionGroupMembership>.unmodifiable(
        memberships.map((membership) => membership.toDomain()),
      );
}
