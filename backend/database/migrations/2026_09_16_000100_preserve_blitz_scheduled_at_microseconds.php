<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('alter table blitz_tasks alter column scheduled_at type timestamp(6) with time zone');
    }

    public function down(): void
    {
        DB::transaction(function (): void {
            // Prevent a fractional schedule being written between the loss check and precision reduction.
            DB::statement('lock table blitz_tasks in access exclusive mode');

            if (DB::table('blitz_tasks')->whereRaw("scheduled_at <> date_trunc('second', scheduled_at)")->exists()) {
                throw new RuntimeException('Cannot reduce blitz_tasks.scheduled_at precision while fractional scheduled values exist.');
            }

            DB::statement('alter table blitz_tasks alter column scheduled_at type timestamp(0) with time zone');
        });
    }
};
