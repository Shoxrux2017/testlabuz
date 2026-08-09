<?php

namespace Tests\Feature\Authorization;

use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

class RoleAuthorizationProductionRouteHygieneTest extends TestCase
{
    public function test_role_authorization_test_surfaces_are_absent_from_application_route_list(): void
    {
        $routeUris = collect(Route::getRoutes())
            ->map(fn ($route): string => $route->uri())
            ->values()
            ->all();

        foreach ($this->authorizationTestUris() as $testAuthorizationUri) {
            $this->assertNotContains($testAuthorizationUri, $routeUris);
        }

        Artisan::call('route:list');
        $routeListOutput = Artisan::output();

        foreach ($this->authorizationTestUris() as $testAuthorizationUri) {
            $this->assertStringNotContainsString($testAuthorizationUri, $routeListOutput);
        }
    }

    /**
     * @return list<string>
     */
    private function authorizationTestUris(): array
    {
        return [
            'api/v1/testing/authorization/platform_owner',
            'api/v1/testing/authorization/institution_admin',
            'api/v1/testing/authorization/teacher',
            'api/v1/testing/authorization/student',
            'api/v1/testing/authorization/parent',
            'api/v1/testing/authorization/teacher-student',
            'api/v1/testing/authorization/invalid-role',
        ];
    }
}
