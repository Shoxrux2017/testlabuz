<?php

namespace Tests\Feature;

use App\Exceptions\Files\FileTooLargeException;
use App\Exceptions\Files\FileUploadFailedException;
use App\Exceptions\Files\UnsupportedFileTypeException;
use App\Exceptions\ResultClosedException;
use App\Exceptions\Teacher\TopicNotEditableException;
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

    public function test_unauthenticated_request_that_does_not_ask_for_json_still_returns_authentication_required(): void
    {
        $resourceId = '08000000-0000-4000-8000-000000000501';
        $requests = [
            ['GET', '/api/v1/auth/me', []],
            ['GET', '/api/v1/teacher/blitz', []],
            ['GET', "/api/v1/files/{$resourceId}/download", []],
            ['GET', '/api/v1/auth/me', ['HTTP_ACCEPT' => 'text/html']],
            ['POST', "/api/v1/teacher/blitz/{$resourceId}/activate", ['CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => '*/*']],
        ];

        foreach ($requests as [$method, $uri, $server]) {
            $response = $this->call($method, $uri, [], [], [], $server, $method === 'POST' ? '{}' : null);

            $decoded = $this->assertErrorContract($response, 401, 'authentication_required');
            $this->assertSame('Authentication is required.', $decoded->message, "$method $uri");
            $this->assertSame([], (array) $decoded->errors, "$method $uri");
        }
    }

    public function test_authorization_exception_returns_forbidden_contract(): void
    {
        Route::get('/api/v1/test-authorization', function () {
            throw new AuthorizationException;
        });

        $response = $this->getJson('/api/v1/test-authorization');

        $this->assertErrorContract($response, 403, 'forbidden');
    }

    public function test_topic_not_editable_exception_returns_specific_conflict_contract(): void
    {
        Route::patch('/api/v1/test-topic-not-editable', function () {
            throw new TopicNotEditableException;
        });

        $response = $this->patchJson('/api/v1/test-topic-not-editable');

        $decoded = $this->assertErrorContract($response, 409, 'topic_not_editable');
        $this->assertSame('The topic is not editable.', $decoded->message);
    }

    public function test_result_closed_exception_returns_specific_conflict_contract(): void
    {
        Route::put('/api/v1/test-result-closed', function () {
            throw new ResultClosedException;
        });

        $response = $this->putJson('/api/v1/test-result-closed');

        $decoded = $this->assertErrorContract($response, 409, 'result_closed');
        $this->assertSame('This result is closed and can no longer be changed.', $decoded->message);
    }

    public function test_unsupported_file_type_exception_returns_exact_file_error_contract(): void
    {
        Route::post('/api/v1/test-unsupported-file-type', function () {
            throw new UnsupportedFileTypeException;
        });

        $response = $this->postJson('/api/v1/test-unsupported-file-type');

        $decoded = $this->assertErrorContract($response, 422, 'unsupported_file_type');
        $this->assertSame('The uploaded file type is not supported.', $decoded->message);
        $this->assertSame(['Supported file types are PDF, DOCX, PPT, and PPTX.'], $decoded->errors->file);
    }

    public function test_file_too_large_exception_returns_exact_effective_limit_contract(): void
    {
        Route::post('/api/v1/test-file-too-large', function () {
            throw new FileTooLargeException(20 * 1_048_576);
        });

        $response = $this->postJson('/api/v1/test-file-too-large');

        $decoded = $this->assertErrorContract($response, 422, 'file_too_large');
        $this->assertSame('The uploaded file exceeds the allowed size.', $decoded->message);
        $this->assertSame(['The file must not exceed 20971520 bytes (20 MiB).'], $decoded->errors->file);
    }

    public function test_file_upload_failed_exception_returns_exact_safe_storage_error_contract(): void
    {
        Route::post('/api/v1/test-file-upload-failed', function () {
            throw new FileUploadFailedException('sensitive disk path');
        });

        $response = $this->postJson('/api/v1/test-file-upload-failed');

        $decoded = $this->assertErrorContract($response, 500, 'file_upload_failed');
        $this->assertSame('The file could not be uploaded.', $decoded->message);
        $this->assertSame([], get_object_vars($decoded->errors));
        $this->assertStringNotContainsString('sensitive', $response->getContent());
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
