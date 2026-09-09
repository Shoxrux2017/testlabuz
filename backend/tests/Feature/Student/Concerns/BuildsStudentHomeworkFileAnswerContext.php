<?php

namespace Tests\Feature\Student\Concerns;

use App\Models\AnswerFile;
use App\Models\AssessmentAttempt;
use App\Models\AttemptAnswer;
use App\Models\File;
use App\Models\Question;
use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;

trait BuildsStudentHomeworkFileAnswerContext
{
    use BuildsStudentHomeworkAnswerContext;

    protected function fileAnswerContext(): array
    {
        [$student, $homework, $attempt] = $this->answerContext();

        return [$student, $homework, $attempt, $this->answerQuestion($homework, 'file_based')];
    }

    protected function fileAnswerUpload(string $name = 'answer.pdf', ?string $content = null): UploadedFile
    {
        return UploadedFile::fake()->createWithContent($name, $content ?? "%PDF-1.7\nOriginal Student submission");
    }

    protected function fileAnswerRequest(User $student, AssessmentAttempt $attempt, Question $question, UploadedFile $upload): TestResponse
    {
        $server = [
            'CONTENT_TYPE' => 'multipart/form-data', 'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$student->createToken('student-file-answer-test')->plainTextToken,
        ];
        try {
            return $this->call('PUT', '/api/v1/student/attempts/'.$attempt->id.'/answers/'.$question->id,
                ['type' => 'file_based'], [], ['file' => $upload], $server);
        } finally {
            $this->app['auth']->forgetGuards();
        }
    }

    /** @return array{AttemptAnswer, AnswerFile, File} */
    protected function savedFileAnswer(AssessmentAttempt $attempt, Question $question, ?string $content = null): array
    {
        $content ??= "%PDF-1.7\nOriginal Student submission";
        $answer = AttemptAnswer::factory()->create(['attempt_id' => $attempt->id, 'question_id' => $question->id]);
        $file = File::factory()->studentSubmission()->create([
            'institution_id' => $attempt->institution_id, 'uploaded_by_user_id' => $attempt->student_id,
            'original_name' => 'answer.pdf', 'extension' => 'pdf', 'mime_type' => 'application/pdf',
            'size_bytes' => strlen($content), 'checksum_sha256' => hash('sha256', $content),
            'storage_disk' => 'local', 'storage_key' => 'student-submissions/'.$attempt->institution_id.'/'.$attempt->id.'/'.$question->id.'/'.Str::uuid().'.pdf',
        ]);
        $answerFile = AnswerFile::factory()->create(['answer_id' => $answer->id, 'file_id' => $file->id]);
        Storage::disk('local')->put($file->storage_key, $content);

        return [$answer->fresh(), $answerFile->fresh(), $file->fresh()];
    }

    protected function fileAnswerSnapshot(): array
    {
        return $this->answerSnapshot() + [
            'files' => DB::table('files')->orderBy('id')->get()->map(fn (object $row): array => (array) $row)->all(),
        ];
    }

    protected function assertNoFileAnswerSecrets(array $value): void
    {
        foreach ($value as $key => $child) {
            $this->assertNotContains($key, ['storage_disk', 'storage_key', 'mime_type', 'checksum_sha256',
                'uploaded_by_user_id', 'institution_id', 'removed_at']);
            if (is_array($child)) {
                $this->assertNoFileAnswerSecrets($child);
            }
        }
    }
}
