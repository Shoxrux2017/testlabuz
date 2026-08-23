import 'teacher_learning_material.dart';
import 'teacher_learning_material_mutation.dart';

abstract interface class TeacherLearningMaterialRepository {
  Future<TeacherLearningMaterialCollection> fetchMaterials(String topicId);

  Future<TeacherLearningMaterial> uploadMaterial({
    required String topicId,
    required TeacherMaterialUploadFile file,
    required String? title,
    TeacherMaterialUploadProgress? onProgress,
  });

  Future<TeacherLearningMaterial> replaceMaterialFile({
    required String topicId,
    required TeacherLearningMaterial current,
    required TeacherMaterialUploadFile file,
    TeacherMaterialUploadProgress? onProgress,
  });

  Future<TeacherLearningMaterial> updateMaterialTitle({
    required String topicId,
    required TeacherLearningMaterial current,
    required String? title,
  });

  Future<void> removeMaterial({
    required String topicId,
    required TeacherLearningMaterial current,
  });
}
