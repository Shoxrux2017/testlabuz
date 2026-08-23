import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/teacher_learning_material.dart';
import '../domain/teacher_learning_material_mutation.dart';
import '../domain/teacher_learning_material_repository.dart';
import 'teacher_learning_material_remote_data_source.dart';

final teacherLearningMaterialRepositoryProvider =
    Provider<TeacherLearningMaterialRepository>((ref) {
      return TeacherLearningMaterialRepositoryImpl(
        remoteDataSource: ref.watch(
          teacherLearningMaterialRemoteDataSourceProvider,
        ),
      );
    });

class TeacherLearningMaterialRepositoryImpl
    implements TeacherLearningMaterialRepository {
  const TeacherLearningMaterialRepositoryImpl({required this.remoteDataSource});

  final TeacherLearningMaterialRemoteDataSource remoteDataSource;

  @override
  Future<TeacherLearningMaterialCollection> fetchMaterials(
    String topicId,
  ) async {
    final dto = await remoteDataSource.fetchMaterials(topicId);
    return dto.toDomain();
  }

  @override
  Future<TeacherLearningMaterial> uploadMaterial({
    required String topicId,
    required TeacherMaterialUploadFile file,
    required String? title,
    TeacherMaterialUploadProgress? onProgress,
  }) async {
    final dto = await remoteDataSource.uploadMaterial(
      topicId: topicId,
      file: file,
      title: title,
      onProgress: onProgress,
    );
    final material = dto.material.toDomain();
    if (material.topicId.toLowerCase() != topicId.toLowerCase()) {
      throw const TeacherMaterialMutationOutcomeUnknownException();
    }
    return material;
  }

  @override
  Future<TeacherLearningMaterial> replaceMaterialFile({
    required String topicId,
    required TeacherLearningMaterial current,
    required TeacherMaterialUploadFile file,
    TeacherMaterialUploadProgress? onProgress,
  }) async {
    final dto = await remoteDataSource.replaceMaterialFile(
      topicId: topicId,
      materialId: current.id,
      file: file,
      onProgress: onProgress,
    );
    final material = dto.material.toDomain();
    if (!_sameIdentity(material, current, topicId) ||
        material.title != current.title) {
      throw const TeacherMaterialMutationOutcomeUnknownException();
    }
    return material;
  }

  @override
  Future<TeacherLearningMaterial> updateMaterialTitle({
    required String topicId,
    required TeacherLearningMaterial current,
    required String? title,
  }) async {
    final dto = await remoteDataSource.updateMaterialTitle(
      topicId: topicId,
      materialId: current.id,
      title: title,
    );
    final material = dto.material.toDomain();
    if (!_sameIdentity(material, current, topicId) || material.title != title) {
      throw const TeacherMaterialMutationOutcomeUnknownException();
    }
    return material;
  }

  @override
  Future<void> removeMaterial({
    required String topicId,
    required TeacherLearningMaterial current,
  }) {
    return remoteDataSource.removeMaterial(
      topicId: topicId,
      materialId: current.id,
    );
  }
}

bool _sameIdentity(
  TeacherLearningMaterial returned,
  TeacherLearningMaterial current,
  String topicId,
) {
  return returned.id.toLowerCase() == current.id.toLowerCase() &&
      returned.file.id.toLowerCase() == current.file.id.toLowerCase() &&
      returned.topicId.toLowerCase() == topicId.toLowerCase();
}
