import '../../../../core/network/api_envelope.dart';
import 'auth_user_dto.dart';

class AuthMeResponseDto {
  const AuthMeResponseDto({required this.user});

  factory AuthMeResponseDto.fromJson(Object? json) {
    return AuthMeResponseDto(
      user: ApiSuccessEnvelope.fromJson(
        json,
        (data) => AuthUserDto.fromJson(data, requireInstitutionContext: true),
      ).data,
    );
  }

  final AuthUserDto user;
}
