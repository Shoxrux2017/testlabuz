class ApiSuccessEnvelope<T> {
  const ApiSuccessEnvelope({required this.data});

  factory ApiSuccessEnvelope.fromJson(
    Object? json,
    T Function(Object? json) readData,
  ) {
    if (json case {'data': final data}) {
      return ApiSuccessEnvelope(data: readData(data));
    }

    throw const ApiEnvelopeFormatException('Missing data envelope.');
  }

  final T data;
}

class ApiCollectionEnvelope<T> {
  const ApiCollectionEnvelope({required this.data, required this.pagination});

  factory ApiCollectionEnvelope.fromJson(
    Object? json,
    T Function(Object? json) readItem,
  ) {
    if (json case {'data': final List<Object?> data}) {
      final pagination = ApiPaginationMeta.tryParse(json);

      return ApiCollectionEnvelope(
        data: List.unmodifiable(data.map(readItem)),
        pagination: pagination,
      );
    }

    throw const ApiEnvelopeFormatException('Missing collection envelope.');
  }

  final List<T> data;
  final ApiPaginationMeta? pagination;
}

class ApiPaginationMeta {
  const ApiPaginationMeta({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  static ApiPaginationMeta? tryParse(Object? json) {
    if (json case {
      'meta': {
        'pagination': {
          'current_page': final int currentPage,
          'per_page': final int perPage,
          'total': final int total,
          'last_page': final int lastPage,
        },
      },
    }) {
      return ApiPaginationMeta(
        currentPage: currentPage,
        perPage: perPage,
        total: total,
        lastPage: lastPage,
      );
    }

    return null;
  }

  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;
}

class ApiEnvelopeFormatException implements Exception {
  const ApiEnvelopeFormatException(this.message);

  final String message;

  @override
  String toString() => 'ApiEnvelopeFormatException: $message';
}
