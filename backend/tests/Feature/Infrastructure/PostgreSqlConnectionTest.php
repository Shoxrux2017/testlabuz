<?php

namespace Tests\Feature\Infrastructure;

use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class PostgreSqlConnectionTest extends TestCase
{
    public function test_laravel_uses_the_isolated_postgresql_testing_database(): void
    {
        $this->assertSame('pgsql', config('database.default'));
        $this->assertSame('pgsql', DB::connection()->getDriverName());

        $currentDatabase = DB::selectOne('select current_database() as database_name')->database_name;

        $this->assertSame('testlabuz_testing', $currentDatabase);
        $this->assertNotSame('testlabuz', $currentDatabase);

        $connectivityCheck = DB::selectOne('select 1 as connectivity_check')->connectivity_check;
        $this->assertSame(1, (int) $connectivityCheck);

        $serverVersionNumber = (int) DB::selectOne(
            "select current_setting('server_version_num') as version_number"
        )->version_number;

        $this->assertGreaterThanOrEqual(180000, $serverVersionNumber);
        $this->assertLessThan(190000, $serverVersionNumber);
    }
}
