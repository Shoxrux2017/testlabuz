<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const ROLE_VALUES = [
        'platform_owner',
        'institution_admin',
        'teacher',
        'student',
        'parent',
    ];

    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('institution_id')->nullable();
            $table->string('role', 32);
            $table->string('full_name', 200);
            $table->string('login_name', 191);
            $table->string('email', 254)->nullable();
            $table->string('phone', 50)->nullable();
            $table->string('password', 255);
            $table->boolean('is_active')->default(true);
            $table->boolean('must_change_password');
            $table->timestampTz('last_login_at')->nullable();
            $table->timestampTz('deactivated_at')->nullable();
            $table->uuid('created_by_user_id')->nullable();
            $table->timestampsTz();

            $table->unique('login_name', 'users_login_name_unique');
            $table->index(['institution_id', 'role', 'is_active'], 'users_institution_role_active_index');
            $table->index('role', 'users_role_index');
        });

        DB::statement(
            'alter table users add constraint users_institution_id_foreign foreign key (institution_id) references institutions (id) on delete restrict'
        );
        DB::statement(sprintf(
            'alter table users add constraint users_role_check check (role in (%s))',
            $this->quotedValues(self::ROLE_VALUES),
        ));
        DB::statement(
            "alter table users add constraint users_role_institution_check check ((role = 'platform_owner' and institution_id is null) or (role <> 'platform_owner' and institution_id is not null))"
        );
        DB::statement('create index users_institution_lower_full_name_index on users (institution_id, lower(full_name))');
    }

    public function down(): void
    {
        Schema::dropIfExists('users');
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
