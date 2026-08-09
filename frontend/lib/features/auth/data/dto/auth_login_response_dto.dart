import '../../../../core/network/api_envelope.dart';
import 'auth_dto_parse.dart';
import 'auth_user_dto.dart';

class AuthLoginResponseDto {
  const AuthLoginResponseDto({
    required this.token,
    required this.tokenType,
    required this.user,
  });

  factory AuthLoginResponseDto.fromJson(Object? json) {
    return ApiSuccessEnvelope.fromJson(json, (data) {
      final map = readRequiredMap(data, 'auth login response');
      final tokenType = readRequiredString(map, 'token_type');

      if (tokenType != 'Bearer') {
        throw const FormatException('Auth token type must be Bearer.');
      }

      return AuthLoginResponseDto(
        token: readRequiredString(map, 'token'),
        tokenType: tokenType,
        user: AuthUserDto.fromJson(
          map['user'],
          requireInstitutionContext: false,
        ),
      );
    }).data;
  }

  final String token;
  final String tokenType;
  final AuthUserDto user;
}
