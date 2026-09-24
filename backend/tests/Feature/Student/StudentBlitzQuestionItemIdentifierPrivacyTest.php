<?php

namespace Tests\Feature\Student;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\Feature\Student\Concerns\AssertsQuestionItemIdentifierPrivacy;
use Tests\Feature\Teacher\Concerns\BuildsTeacherBlitzActivationContext;
use Tests\TestCase;

class StudentBlitzQuestionItemIdentifierPrivacyTest extends TestCase
{
    use AssertsQuestionItemIdentifierPrivacy;
    use BuildsTeacherBlitzActivationContext;
    use RefreshDatabase;

    public function test_blitz_start_item_ids_do_not_reveal_matching_pairs_or_ordering(): void
    {
        [, $teacher, , , , $student, $assessment] = $this->readyBlitzActivation('individual');
        $student->forceFill(['must_change_password' => false])->save();
        $this->authorKeyedQuestions($teacher, $assessment->id, 2);
        $this->activateBlitz($teacher, $assessment->id, body: '')->assertOk();

        $server = [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$student->createToken('blitz-item-privacy')->plainTextToken,
            'HTTP_IDEMPOTENCY_KEY' => (string) Str::uuid(),
        ];
        $start = $this->call('POST', '/api/v1/student/blitz/'.$assessment->id.'/attempts', [], [], [], $server,
            json_encode(['intent' => 'start_normal'], JSON_THROW_ON_ERROR))->assertCreated();

        $this->assertItemIdentifiersRevealNoKey($start->json('data.questions'));
    }
}
