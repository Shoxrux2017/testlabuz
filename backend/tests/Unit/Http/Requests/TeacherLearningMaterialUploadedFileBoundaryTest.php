<?php

namespace Tests\Unit\Http\Requests;

use App\Http\Requests\Teacher\TeacherLearningMaterialReplaceRequest;
use App\Http\Requests\Teacher\TeacherLearningMaterialUploadRequest;
use Illuminate\Http\UploadedFile as LaravelUploadedFile;
use PHPUnit\Framework\TestCase;
use Symfony\Component\HttpFoundation\File\UploadedFile as SymfonyUploadedFile;
use Symfony\Component\HttpFoundation\Request as SymfonyRequest;

class TeacherLearningMaterialUploadedFileBoundaryTest extends TestCase
{
    public function test_upload_validation_data_converts_symfony_uploaded_file_to_laravel_uploaded_file(): void
    {
        $temporaryPath = tempnam(sys_get_temp_dir(), 'testlabuz_upload_boundary_');
        $this->assertIsString($temporaryPath);

        try {
            $this->assertNotFalse(file_put_contents($temporaryPath, 'non-empty PDF contents'));

            $symfonyUpload = new SymfonyUploadedFile(
                $temporaryPath,
                'teacher-material.pdf',
                'application/pdf',
                UPLOAD_ERR_OK,
            );
            $symfonyRequest = new SymfonyRequest(
                request: ['title' => 'Boundary title'],
                files: ['file' => $symfonyUpload],
            );
            $request = TeacherLearningMaterialUploadRequest::createFromBase($symfonyRequest);

            $validationData = $request->validationData();

            $this->assertInstanceOf(LaravelUploadedFile::class, $validationData['file']);
            $this->assertSame('teacher-material.pdf', $validationData['file']->getClientOriginalName());
            $this->assertSame('Boundary title', $validationData['title']);
        } finally {
            if (is_file($temporaryPath)) {
                unlink($temporaryPath);
            }
        }
    }

    public function test_replace_validation_data_converts_symfony_uploaded_file_to_laravel_uploaded_file(): void
    {
        $temporaryPath = tempnam(sys_get_temp_dir(), 'testlabuz_replace_boundary_');
        $this->assertIsString($temporaryPath);

        try {
            $this->assertNotFalse(file_put_contents($temporaryPath, 'non-empty PDF contents'));

            $symfonyUpload = new SymfonyUploadedFile(
                $temporaryPath,
                'replacement-material.pdf',
                'application/pdf',
                UPLOAD_ERR_OK,
            );
            $symfonyRequest = new SymfonyRequest(files: ['file' => $symfonyUpload]);
            $request = TeacherLearningMaterialReplaceRequest::createFromBase($symfonyRequest);

            $validationData = $request->validationData();

            $this->assertInstanceOf(LaravelUploadedFile::class, $validationData['file']);
            $this->assertSame('replacement-material.pdf', $validationData['file']->getClientOriginalName());
        } finally {
            if (is_file($temporaryPath)) {
                unlink($temporaryPath);
            }
        }
    }
}
