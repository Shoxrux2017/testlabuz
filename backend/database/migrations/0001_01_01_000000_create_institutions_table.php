<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const TYPE_VALUES = [
        'school',
        'college',
        'lyceum',
        'university',
        'institute',
        'learning_center',
        'training_center',
        'private_education',
        'other',
    ];

    private const STATUS_VALUES = [
        'active',
        'inactive',
    ];

    public function up(): void
    {
        Schema::create('institutions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name', 200);
            $table->string('type', 40);
            $table->string('status', 20);
            $table->string('contact_email', 254)->nullable();
            $table->string('contact_phone', 50)->nullable();
            $table->text('address')->nullable();
            $table->text('description')->nullable();
            $table->uuid('created_by_user_id')->nullable();
            $table->timestampTz('deactivated_at')->nullable();
            $table->timestampsTz();

            $table->index('status', 'institutions_status_index');
            $table->index('type', 'institutions_type_index');
        });

        DB::statement("alter table institutions add constraint institutions_name_not_empty_check check (name <> '')");
        DB::statement(sprintf(
            'alter table institutions add constraint institutions_type_check check (type in (%s))',
            $this->quotedValues(self::TYPE_VALUES),
        ));
        DB::statement(sprintf(
            'alter table institutions add constraint institutions_status_check check (status in (%s))',
            $this->quotedValues(self::STATUS_VALUES),
        ));
        DB::statement('create index institutions_lower_name_index on institutions (lower(name))');
    }

    public function down(): void
    {
        Schema::dropIfExists('institutions');
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
