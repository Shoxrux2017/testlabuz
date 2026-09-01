<?php

namespace Tests\Feature\Persistence;

use App\Enums\AssessmentAssignmentSource;
use App\Enums\AssessmentAttemptStatus;
use App\Models\Assessment;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentStudent;
use App\Models\HomeworkAssignment;
use App\Models\Institution;
use App\Models\Topic;
use App\Models\TopicResultPair;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Feature\Persistence\Concerns\AssertsDatabaseRejections;
use Tests\TestCase;

class AssessmentHomeworkPersistenceTest extends TestCase
{
    use AssertsDatabaseRejections;
    use RefreshDatabase;

    public function test_valid_assessments_persist_and_database_rejects_invalid_values_and_tenant_references(): void
    {
        $homework = Assessment::factory()->homework()->groupAssignment()->create([
            'total_possible_points' => '0.000000',
        ]);
        $blitz = Assessment::factory()->blitz()->selectedStudentsAssignment()->create([
            'total_possible_points' => '25.125000',
        ]);

        $this->assertDatabaseHas('assessments', ['id' => $homework->id, 'type' => 'homework']);
        $this->assertDatabaseHas('assessments', ['id' => $blitz->id, 'type' => 'blitz']);

        foreach ([
            ['type' => 'quiz'],
            ['assignment_mode' => 'individual'],
            ['title' => '   '],
            ['student_instructions' => '   '],
            ['total_possible_points' => '-0.000001'],
        ] as $invalidAttributes) {
            $this->assertDatabaseRejects(fn () => $this->updateById('assessments', $homework->id, $invalidAttributes));
        }

        $institution = Institution::factory()->create();
        $teacher = User::factory()->teacher($institution)->create();
        $topic = Topic::factory()->create([
            'institution_id' => $institution,
            'teacher_id' => $teacher,
        ]);
        $otherInstitution = Institution::factory()->create();
        $otherTeacher = User::factory()->teacher($otherInstitution)->create();
        $otherTopic = Topic::factory()->create([
            'institution_id' => $otherInstitution,
            'teacher_id' => $otherTeacher,
        ]);
        $attributes = [
            'institution_id' => $institution,
            'topic_id' => $topic,
            'teacher_id' => $teacher,
        ];

        $this->assertDatabaseRejects(fn () => Assessment::factory()->create(array_merge($attributes, [
            'topic_id' => $otherTopic,
        ])));
        $this->assertDatabaseRejects(fn () => Assessment::factory()->create(array_merge($attributes, [
            'teacher_id' => $otherTeacher,
        ])));
    }

    public function test_homework_lifecycle_accepts_only_valid_historical_shapes_and_timestamp_ordering(): void
    {
        HomeworkAssignment::factory()->draft()->create();
        HomeworkAssignment::factory()->active()->create();
        HomeworkAssignment::factory()->closed()->create();
        HomeworkAssignment::factory()->archivedFromDraft()->create();
        HomeworkAssignment::factory()->archivedAfterClose()->create();
        HomeworkAssignment::factory()->draft()->create(['deadline_at' => now()->subDay()]);

        $this->assertDatabaseCount('homework_assignments', 6);

        $draft = HomeworkAssignment::factory()->draft()->create();
        $createdAt = $draft->created_at;

        foreach ([
            ['status' => 'disabled'],
            ['status' => 'draft', 'activated_at' => now()],
            ['status' => 'active', 'activated_at' => null],
            ['status' => 'closed', 'activated_at' => now(), 'closed_at' => null],
            ['status' => 'archived', 'activated_at' => now(), 'closed_at' => null, 'archived_at' => now()],
            ['status' => 'archived', 'activated_at' => null, 'closed_at' => null, 'archived_at' => null],
            ['status' => 'active', 'activated_at' => $createdAt->copy()->subSecond()],
            [
                'status' => 'closed',
                'activated_at' => $createdAt->copy()->addMinute(),
                'closed_at' => $createdAt,
            ],
            [
                'status' => 'archived',
                'activated_at' => null,
                'closed_at' => null,
                'archived_at' => $createdAt->copy()->subSecond(),
            ],
            [
                'status' => 'archived',
                'activated_at' => $createdAt->copy()->addMinute(),
                'closed_at' => $createdAt->copy()->addMinutes(3),
                'archived_at' => $createdAt->copy()->addMinutes(2),
            ],
        ] as $invalidLifecycle) {
            $this->assertDatabaseRejects(
                fn () => $this->updateByKey('homework_assignments', 'assessment_id', $draft->assessment_id, $invalidLifecycle),
            );
        }
    }

    public function test_recipient_snapshot_uniqueness_values_and_same_institution_references_are_enforced(): void
    {
        $recipient = AssessmentStudent::factory()->create();
        $attributes = [
            'institution_id' => $recipient->institution_id,
            'assessment_id' => $recipient->assessment_id,
            'student_id' => $recipient->student_id,
            'assigned_by_user_id' => $recipient->assigned_by_user_id,
            'assignment_source' => AssessmentAssignmentSource::Group,
        ];

        $this->assertDatabaseRejects(fn () => AssessmentStudent::factory()->create($attributes));
        $this->assertDatabaseRejects(
            fn () => $this->updateById('assessment_students', $recipient->id, ['assignment_source' => 'roster']),
        );

        $otherInstitution = Institution::factory()->create();
        $otherAssessment = Assessment::factory()->create(['institution_id' => $otherInstitution]);
        $otherStudent = User::factory()->student($otherInstitution)->create();
        $otherAssigner = User::factory()->teacher($otherInstitution)->create();

        foreach ([
            ['assessment_id' => $otherAssessment->id],
            ['student_id' => $otherStudent->id],
            ['assigned_by_user_id' => $otherAssigner->id],
        ] as $foreignReference) {
            $this->assertDatabaseRejects(fn () => AssessmentStudent::factory()->create(array_merge(
                $attributes,
                ['student_id' => User::factory()->student()->state(['institution_id' => $recipient->institution_id])],
                $foreignReference,
            )));
        }
    }

    public function test_attempt_constraints_reject_invalid_machine_values_scores_ordering_and_duplicates(): void
    {
        $recipient = AssessmentStudent::factory()->create();
        $attempt = AssessmentAttempt::factory()->create([
            'assessment_student_id' => $recipient,
            'institution_id' => $recipient->institution_id,
            'assessment_id' => $recipient->assessment_id,
            'student_id' => $recipient->student_id,
            'possible_points' => '20.000000',
        ]);

        $this->assertDatabaseHas('assessment_attempts', [
            'id' => $attempt->id,
            'attempt_number' => 1,
            'status' => 'in_progress',
        ]);

        $baseAttributes = [
            'institution_id' => $recipient->institution_id,
            'assessment_id' => $recipient->assessment_id,
            'assessment_student_id' => $recipient->id,
            'student_id' => $recipient->student_id,
            'attempt_number' => 2,
            'status' => AssessmentAttemptStatus::InProgress->value,
            'started_at' => now(),
            'deadline_at' => null,
            'submitted_at' => null,
            'finalized_at' => null,
            'finalization_reason' => null,
            'locked_at' => null,
            'official_score_eligible' => true,
            'earned_points' => null,
            'possible_points' => '20.000000',
            'normalized_score' => null,
            'scoring_completed_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ];

        foreach ([
            ['attempt_number' => 0],
            ['attempt_number' => 4],
            ['status' => 'not_started'],
            ['status' => 'not_completed'],
            ['finalization_reason' => 'manual'],
            ['possible_points' => '-0.000001'],
            ['normalized_score' => '-0.00000001'],
            ['normalized_score' => '100.00000001'],
            ['earned_points' => '-0.00000001'],
            ['earned_points' => '20.00000001'],
            ['submitted_at' => now()->subMinute()],
            ['finalized_at' => now()->subMinute()],
            ['locked_at' => now()->subMinute()],
            ['scoring_completed_at' => now()->subMinute()],
        ] as $invalidAttributes) {
            $this->assertDatabaseRejects(fn () => DB::table('assessment_attempts')->insert(array_merge(
                $baseAttributes,
                ['id' => Str::uuid()->toString()],
                $invalidAttributes,
            )));
        }

        AssessmentAttempt::factory()->create([
            'assessment_student_id' => $recipient,
            'institution_id' => $recipient->institution_id,
            'assessment_id' => $recipient->assessment_id,
            'student_id' => $recipient->student_id,
            'attempt_number' => 2,
            'possible_points' => '20.000000',
        ]);
        $this->assertDatabaseRejects(fn () => DB::table('assessment_attempts')->insert(array_merge(
            $baseAttributes,
            ['id' => Str::uuid()->toString()],
        )));
    }

    public function test_attempt_foreign_keys_reject_every_cross_institution_reference_category(): void
    {
        $recipient = AssessmentStudent::factory()->create();
        $otherRecipient = AssessmentStudent::factory()->create();
        $baseAttributes = [
            'assessment_student_id' => $recipient,
            'institution_id' => $recipient->institution_id,
            'assessment_id' => $recipient->assessment_id,
            'student_id' => $recipient->student_id,
        ];

        foreach ([
            ['assessment_id' => $otherRecipient->assessment_id],
            ['assessment_student_id' => $otherRecipient->id],
            ['student_id' => $otherRecipient->student_id],
            ['institution_id' => $otherRecipient->institution_id],
        ] as $foreignReference) {
            $this->assertDatabaseRejects(fn () => AssessmentAttempt::factory()->create(array_merge(
                $baseAttributes,
                $foreignReference,
            )));
        }
    }

    public function test_result_pair_supports_partial_and_complete_pairs_and_enforces_history_shape(): void
    {
        $partial = TopicResultPair::factory()->create();
        $complete = TopicResultPair::factory()->withBlitz()->create();

        $this->assertNull($partial->blitz_assessment_id);
        $this->assertNotNull($complete->blitz_assessment_id);

        $locked = TopicResultPair::factory()->create([
            'designated_at' => now()->subMinutes(2),
            'cohort_snapshotted_at' => now()->subMinute(),
            'locked_at' => now(),
        ]);
        $this->assertNull($locked->blitz_assessment_id);

        $this->assertDatabaseRejects(fn () => TopicResultPair::factory()->create([
            'cohort_snapshotted_at' => now()->subMinute(),
            'locked_at' => now()->subMinutes(2),
        ]));
        $this->assertDatabaseRejects(fn () => TopicResultPair::factory()->create([
            'cohort_snapshotted_at' => null,
            'locked_at' => now(),
        ]));
        $this->assertDatabaseRejects(fn () => TopicResultPair::factory()->create([
            'designated_at' => now(),
            'cohort_snapshotted_at' => now()->subMinute(),
        ]));
    }

    public function test_result_pair_rejects_duplicate_cross_topic_cross_institution_and_same_assessment_links(): void
    {
        $institution = Institution::factory()->create();
        $teacher = User::factory()->teacher($institution)->create();
        $topic = Topic::factory()->create([
            'institution_id' => $institution,
            'teacher_id' => $teacher,
        ]);
        $otherTopic = Topic::factory()->create([
            'institution_id' => $institution,
            'teacher_id' => $teacher,
        ]);
        $homework = Assessment::factory()->homework()->create([
            'institution_id' => $institution,
            'topic_id' => $topic,
            'teacher_id' => $teacher,
        ]);
        $otherTopicAssessment = Assessment::factory()->blitz()->create([
            'institution_id' => $institution,
            'topic_id' => $otherTopic,
            'teacher_id' => $teacher,
        ]);
        $baseAttributes = [
            'institution_id' => $institution,
            'topic_id' => $topic,
            'homework_assessment_id' => $homework,
            'designated_by_user_id' => $teacher,
        ];

        $this->assertDatabaseRejects(fn () => TopicResultPair::factory()->create(array_merge($baseAttributes, [
            'topic_id' => $otherTopic,
        ])));
        $this->assertDatabaseRejects(fn () => TopicResultPair::factory()->create(array_merge($baseAttributes, [
            'blitz_assessment_id' => $otherTopicAssessment,
        ])));
        $this->assertDatabaseRejects(fn () => TopicResultPair::factory()->create(array_merge($baseAttributes, [
            'blitz_assessment_id' => $homework,
        ])));

        $foreignInstitution = Institution::factory()->create();
        $foreignTeacher = User::factory()->teacher($foreignInstitution)->create();
        $foreignHomework = Assessment::factory()->homework()->create([
            'institution_id' => $foreignInstitution,
            'teacher_id' => $foreignTeacher,
        ]);

        $this->assertDatabaseRejects(fn () => TopicResultPair::factory()->create(array_merge($baseAttributes, [
            'topic_id' => Topic::factory()->state([
                'institution_id' => $foreignInstitution,
                'teacher_id' => $foreignTeacher,
            ]),
        ])));
        $this->assertDatabaseRejects(fn () => TopicResultPair::factory()->create(array_merge($baseAttributes, [
            'homework_assessment_id' => $foreignHomework,
        ])));
        $this->assertDatabaseRejects(fn () => TopicResultPair::factory()->create(array_merge($baseAttributes, [
            'designated_by_user_id' => $foreignTeacher,
        ])));

        TopicResultPair::factory()->create($baseAttributes);
        $this->assertDatabaseRejects(fn () => TopicResultPair::factory()->create($baseAttributes));
    }

    public function test_restrictive_foreign_keys_preserve_assessment_and_homework_history(): void
    {
        $homework = HomeworkAssignment::factory()->create();
        $assessment = $homework->assessment;
        $recipient = AssessmentStudent::factory()->create([
            'assessment_id' => $assessment,
            'institution_id' => $assessment->institution_id,
        ]);
        AssessmentAttempt::factory()->create([
            'assessment_student_id' => $recipient,
            'institution_id' => $recipient->institution_id,
            'assessment_id' => $recipient->assessment_id,
            'student_id' => $recipient->student_id,
        ]);
        $pair = TopicResultPair::factory()->create([
            'institution_id' => $assessment->institution_id,
            'topic_id' => $assessment->topic_id,
            'homework_assessment_id' => $assessment,
        ]);

        foreach ([
            $recipient,
            $assessment,
            $assessment->topic,
            $assessment->teacher,
            $recipient->student,
            $recipient->assignedBy,
            $pair->designatedBy,
            $assessment->institution,
        ] as $referencedModel) {
            $this->assertDatabaseRejects(fn () => $referencedModel->delete());
        }
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function updateById(string $table, string $id, array $attributes): void
    {
        $this->updateByKey($table, 'id', $id, $attributes);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function updateByKey(string $table, string $key, string $id, array $attributes): void
    {
        DB::table($table)->where($key, $id)->update($attributes);
    }
}
