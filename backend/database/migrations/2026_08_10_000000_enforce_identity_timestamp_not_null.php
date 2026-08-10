<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    private const TARGET_COLUMNS = [
        'institutions' => [
            'created_at',
            'updated_at',
        ],
        'users' => [
            'created_at',
            'updated_at',
        ],
        'institution_settings' => [
            'created_at',
            'updated_at',
        ],
    ];

    public function up(): void
    {
        $this->assertTargetColumnsContainNoNulls();

        $this->alterTargetColumns('set not null');
    }

    public function down(): void
    {
        $this->alterTargetColumns('drop not null');
    }

    private function assertTargetColumnsContainNoNulls(): void
    {
        foreach (self::TARGET_COLUMNS as $table => $columns) {
            foreach ($columns as $column) {
                $result = DB::selectOne(
                    "select count(*)::int as null_count from {$table} where {$column} is null",
                );

                if ((int) $result->null_count > 0) {
                    throw new RuntimeException("Cannot enforce NOT NULL on {$table}.{$column}; existing NULL values were found.");
                }
            }
        }
    }

    private function alterTargetColumns(string $operation): void
    {
        foreach (self::TARGET_COLUMNS as $table => $columns) {
            foreach ($columns as $column) {
                DB::statement("alter table {$table} alter column {$column} {$operation}");
            }
        }
    }
};
