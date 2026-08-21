<?php

namespace App\Http\Controllers\Api\V1\Institution;

use App\Actions\Institution\ListInstitutionParentStudents;
use App\Http\Controllers\Controller;
use App\Http\Requests\Institution\InstitutionParentStudentsIndexRequest;
use App\Http\Resources\Institution\InstitutionParentStudentRelationshipCollection;
use App\Models\User;

class InstitutionParentStudentsController extends Controller
{
    public function index(
        InstitutionParentStudentsIndexRequest $request,
        string $parent,
        ListInstitutionParentStudents $listInstitutionParentStudents,
    ): InstitutionParentStudentRelationshipCollection {
        /** @var User $actor */
        $actor = $request->user();

        $relationships = $listInstitutionParentStudents(
            actor: $actor,
            parent: $parent,
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
