<?php

namespace App\Http\Controllers\Api\V1\Institution;

use App\Actions\Institution\ConnectInstitutionParentStudentRelationship;
use App\Actions\Institution\DisconnectInstitutionParentStudentRelationship;
use App\Http\Controllers\Controller;
use App\Http\Requests\Institution\InstitutionParentStudentRelationshipConnectRequest;
use App\Http\Requests\Institution\InstitutionParentStudentRelationshipDisconnectRequest;
use App\Http\Resources\Institution\InstitutionParentStudentRelationshipResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Response;
use Symfony\Component\HttpFoundation\Response as HttpResponse;

class InstitutionParentStudentRelationshipController extends Controller
{
    public function store(
        InstitutionParentStudentRelationshipConnectRequest $request,
        ConnectInstitutionParentStudentRelationship $connectInstitutionParentStudentRelationship,
    ): JsonResponse {
        /** @var User $actor */
        $actor = $request->user();

        $result = $connectInstitutionParentStudentRelationship(
            $actor,
            $request->parentId(),
            $request->studentId(),
        );

        return (new InstitutionParentStudentRelationshipResource($result->relationship))
            ->additional(['message' => 'Parent and student connected successfully.'])
            ->response()
            ->setStatusCode($result->created ? HttpResponse::HTTP_CREATED : HttpResponse::HTTP_OK);
    }

    public function destroy(
        InstitutionParentStudentRelationshipDisconnectRequest $request,
        string $relationship,
        DisconnectInstitutionParentStudentRelationship $disconnectInstitutionParentStudentRelationship,
    ): Response {
        /** @var User $actor */
        $actor = $request->user();

        $disconnectInstitutionParentStudentRelationship($actor, $relationship);

        return response()->noContent();
    }
}
