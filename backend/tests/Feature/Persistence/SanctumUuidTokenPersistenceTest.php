<?php

namespace Tests\Feature\Persistence;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\TestCase;

class SanctumUuidTokenPersistenceTest extends TestCase
{
    use RefreshDatabase;

    public function test_sanctum_token_persistence_links_to_uuid_user_without_plaintext_storage(): void
    {
        $user = User::factory()->teacher()->create();
        $newAccessToken = $user->createToken('stage-1-persistence-test');
        $accessToken = $newAccessToken->accessToken->refresh();

        $this->assertInstanceOf(PersonalAccessToken::class, $accessToken);
        $this->assertSame(User::class, $accessToken->tokenable_type);
        $this->assertSame($user->id, $accessToken->tokenable_id);
        $this->assertNotSame($newAccessToken->plainTextToken, $accessToken->token);
        $this->assertSame(64, strlen($accessToken->token));

        $this->assertDatabaseHas('personal_access_tokens', [
            'id' => $accessToken->id,
            'tokenable_type' => User::class,
            'tokenable_id' => $user->id,
        ]);

        $accessToken->delete();

        $this->assertDatabaseMissing('personal_access_tokens', [
            'id' => $accessToken->id,
        ]);
    }
}
