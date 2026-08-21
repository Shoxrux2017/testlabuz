<?php

namespace App\Http\Controllers\Api\V1\Institution;

use App\Actions\Institution\ListInstitutionStudentParents;
use App\Http\Controllers\Controller;
use App\Http\Requests\Institution\InstitutionStudentParentsIndexRequest;
use App\Http\Resources\Institution\InstitutionParentStudentRelationshipCollection;
use App\Models\User;

class InstitutionStudentParentsController extends Controller
{
    public function index(
        InstitutionStudentParentsIndexRequest $request,
        string $student,
        ListInstitutionStudentParents $listInstitutionStudentParents,
    ): InstitutionParentStudentRelationshipCollection {
        /** @var User $actor */
        $actor = $request->user();

        $relationships = $listInstitutionStudentParents(
            actor: $actor,
            student: $student,
            search: $request->search(),
            isActive: $request->status(),
            sort: $request->sort(),
            direction: $request->direction(),
            page: $request->page(),
            perPage: $request->perPage(),
        );

        return new InstitutionParentStudentRelationshipCollection($relationships);
    }
}
