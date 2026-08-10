<?php

namespace Tests\Feature\Seeders;

use App\Models\Institution;
use App\Models\User;
use Database\Seeders\Stage1E2eSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use RuntimeException;
use Tests\TestCase;

class Stage1E2eSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_stage_1_e2e_seeder_requires_local_password_input(): void
    {
        $this->clearStage1E2ePassword();

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('STAGE1_E2E_PASSWORD must be provided');

        $this->seed(Stage1E2eSeeder::class);
    }

    public function test_stage_1_e2e_seeder_creates_only_prefixed_fixture_accounts(): void
    {
        $this->setStage1E2ePassword();

        $this->seed(Stage1E2eSeeder::class);

        $this->assertSame(9, User::query()->where('login_name', 'like', 'e2e_%')->count());
        $this->assertSame(2, Institution::query()->where('name', 'like', 'E2E % Institution')->count());
        $this->assertDatabaseHas('users', [
            'login_name' => 'e2e_teacher_must_change',
            'must_change_password' => true,
            'is_active' => true,
        ]);
        $this->assertDatabaseHas('users', [
            'login_name' => 'e2e_inactive_user',
            'must_change_password' => false,
            'is_active' => false,
        ]);
    }

    protected function tearDown(): void
    {
        $this->clearStage1E2ePassword();

        parent::tearDown();
    }

    private function setStage1E2ePassword(): void
    {
        $password = 'Test-'.Str::random(24).'Aa1!';
        putenv('STAGE1_E2E_PASSWORD='.$password);
        $_ENV['STAGE1_E2E_PASSWORD'] = $password;
        $_SERVER['STAGE1_E2E_PASSWORD'] = $password;
    }

    private function clearStage1E2ePassword(): void
    {
        putenv('STAGE1_E2E_PASSWORD');
        unset($_ENV['STAGE1_E2E_PASSWORD'], $_SERVER['STAGE1_E2E_PASSWORD']);
    }
}
