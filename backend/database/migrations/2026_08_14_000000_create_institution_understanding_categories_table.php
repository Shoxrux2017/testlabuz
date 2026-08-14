<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const CATEGORY_CODES = [
        'understood_well',
        'partially_understood',
        'needs_revision',
        'needs_teacher_support',
        'not_completed',
    ];

    public function up(): void
    {
        Schema::create('institution_understanding_categories', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id');
            $table->string('code', 40);
            $table->smallInteger('min_score')->nullable();
            $table->smallInteger('max_score')->nullable();
            $table->smallInteger('sort_order');
            $table->uuid('updated_by_user_id');
            $table->timestampTz('created_at')->nullable(false);
            $table->timestampTz('updated_at')->nullable(false);

            $table->unique(
                ['institution_id', 'code'],
                'institution_categories_institution_code_unique',
            );
        });

        DB::statement(
            'alter table institution_understanding_categories add constraint institution_categories_institution_id_foreign foreign key (institution_id) references institutions (id) on delete restrict'
        );
        DB::statement(
            'alter table institution_understanding_categories add constraint institution_categories_updated_by_user_id_foreign foreign key (updated_by_user_id) references users (id) on delete restrict'
        );
        DB::statement(sprintf(
            'alter table institution_understanding_categories add constraint institution_categories_code_check check (code in (%s))',
            $this->quotedValues(self::CATEGORY_CODES),
        ));
        DB::statement(<<<'SQL'
            alter table institution_understanding_categories
            add constraint institution_categories_sort_order_check
            check (
                (code = 'understood_well' and sort_order = 1)
                or (code = 'partially_understood' and sort_order = 2)
                or (code = 'needs_revision' and sort_order = 3)
                or (code = 'needs_teacher_support' and sort_order = 4)
                or (code = 'not_completed' and sort_order = 5)
            )
            SQL);
        DB::statement(<<<'SQL'
            alter table institution_understanding_categories
            add constraint institution_categories_range_shape_check
            check (
                (
                    code in (
                        'understood_well',
                        'partially_understood',
                        'needs_revision',
                        'needs_teacher_support'
                    )
                    and min_score is not null
                    and max_score is not null
                    and min_score between 0 and 100
                    and max_score between 0 and 100
                    and min_score <= max_score
                )
                or (
                    code = 'not_completed'
                    and min_score is null
                    and max_score is null
                )
            )
            SQL);
    }

    public function down(): void
    {
        Schema::dropIfExists('institution_understanding_categories');
    }

    /**
     * @param  list<string>  $values
     */
    private function quotedValues(array $values): string
    {
        return collect($values)
            ->map(fn (string $value): string => DB::getPdo()->quote($value))
            ->implode(', ');
    }
};
