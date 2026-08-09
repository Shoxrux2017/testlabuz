<?php

namespace Tests\Feature;

use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use RuntimeException;
use Tests\TestCase;

class ApiErrorContractTest extends TestCase
{
    public function test_unknown_api_route_returns_resource_not_found_contract(): void
    {
        $response = $this->getJson('/api/v1/missing-route');

        $this->assertErrorContract($response, 404, 'resource_not_found');
    }

    public function test_validation_failure_returns_validation_failed_contract(): void
    {
        Route::post('/api/v1/test-validation', function (Request $request) {
            $request->validate([
                'title' => ['required', 'string'],
            ]);

            return response()->noContent();
        });

        $response = $this->postJson('/api/v1/test-validation', []);

        $decoded = $this->assertErrorContract($response, 422, 'validation_failed');
        $this->assertObjectHasProperty('title', $decoded->errors);
        $this->assertIsArray($decoded->errors->title);
    }

    public function test_authentication_exception_returns_authentication_required_contract(): void
    {
        Route::get('/api/v1/test-authentication', fn () => response()->noContent())
            ->middleware('auth:sanctum');

        $response = $this->getJson('/api/v1/test-authentication');

        $this->assertErrorContract($response, 401, 'authentication_required');
    }

    public function test_authorization_exception_returns_forbidden_contract(): void
    {
        Route::get('/api/v1/test-authorization', function () {
            throw new AuthorizationException;
        });

        $response = $this->getJson('/api/v1/test-authorization');

        $this->assertErrorContract($response, 403, 'forbidden');
    }

    public function test_rate_limit_exception_returns_rate_limited_contract(): void
    {
        Route::get('/api/v1/test-rate-limit', fn () => response()->noContent())
            ->middleware('throttle:1,1');

        $this->getJson('/api/v1/test-rate-limit')->assertNoContent();
        $response = $this->getJson('/api/v1/test-rate-limit');

        $this->assertErrorContract($response, 429, 'rate_limited');
    }

    public function test_unexpected_failure_returns_production_safe_server_error_contract(): void
    {
        config(['app.debug' => false]);

        Route::get('/api/v1/test-unexpected-failure', function () {
            throw new RuntimeException('sensitive failure detail from G:\\project\\testlabuz\\.env');
        });

        $response = $this->getJson('/api/v1/test-unexpected-failure');

        $this->assertErrorContract($response, 500, 'server_error');
        $responseContent = $response->getContent();

        $this->assertStringNotContainsString(RuntimeException::class, $responseContent);
        $this->assertStringNotContainsString('sensitive failure detail', $responseContent);
        $this->assertStringNotContainsString('G:\\project\\testlabuz', $responseContent);
        $this->assertStringNotContainsString('.env', $responseContent);
        $this->assertStringNotContainsString('trace', $responseContent);
        $this->assertStringNotContainsString('APP_KEY', $responseContent);
        $this->assertStringNotContainsString('token', strtolower($responseContent));
    }

    public function test_generated_api_user_endpoint_is_not_exposed(): void
    {
        $response = $this->getJson('/api/user');

        $response->assertNotFound();
    }

    public function test_api_routes_are_configured_with_v1_prefix(): void
    {
        $bootstrap = file_get_contents(base_path('bootstrap/app.php'));

        $this->assertIsString($bootstrap);
        $this->assertStringContainsString("apiPrefix: 'api/v1'", $bootstrap);
    }

    private function assertErrorContract(TestResponse $response, int $status, string $code): object
    {
        $response->assertStatus($status);
        $response->assertHeader('content-type', 'application/json');

        $decoded = json_decode($response->getContent());

        $this->assertIsObject($decoded);
        $this->assertObjectHasProperty('message', $decoded);
        $this->assertIsString($decoded->message);
        $this->assertObjectHasProperty('code', $decoded);
        $this->assertSame($code, $decoded->code);
        $this->assertObjectHasProperty('errors', $decoded);
        $this->assertIsObject($decoded->errors);

        return $decoded;
    }
}
