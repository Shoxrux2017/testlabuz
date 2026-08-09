<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement(
            'alter table institutions add constraint institutions_created_by_user_id_foreign foreign key (created_by_user_id) references users (id) on delete restrict'
        );
    }

    public function down(): void
    {
        DB::statement('alter table institutions drop constraint if exists institutions_created_by_user_id_foreign');
    }
};
