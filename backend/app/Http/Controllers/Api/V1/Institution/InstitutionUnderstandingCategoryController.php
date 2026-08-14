<?php

namespace App\Http\Controllers\Api\V1\Institution;

use App\Actions\Institution\ListInstitutionUnderstandingCategories;
use App\Actions\Institution\ReplaceInstitutionUnderstandingCategories;
use App\Http\Controllers\Controller;
use App\Http\Requests\Institution\InstitutionUnderstandingCategoryIndexRequest;
use App\Http\Requests\Institution\InstitutionUnderstandingCategoryUpdateRequest;
use App\Http\Resources\Institution\InstitutionUnderstandingCategoryCollection;
use App\Models\User;

class InstitutionUnderstandingCategoryController extends Controller
{
    public function index(
        InstitutionUnderstandingCategoryIndexRequest $request,
        ListInstitutionUnderstandingCategories $listInstitutionUnderstandingCategories,
    ): InstitutionUnderstandingCategoryCollection {
        /** @var User $actor */
        $actor = $request->user();
        $categories = $listInstitutionUnderstandingCategories($actor);

        return new InstitutionUnderstandingCategoryCollection(
            $categories,
            configured: $categories->isNotEmpty(),
        );
    }

    public function update(
        InstitutionUnderstandingCategoryUpdateRequest $request,
        ReplaceInstitutionUnderstandingCategories $replaceInstitutionUnderstandingCategories,
    ): InstitutionUnderstandingCategoryCollection {
        /** @var User $actor */
        $actor = $request->user();

        return new InstitutionUnderstandingCategoryCollection(
            $replaceInstitutionUnderstandingCategories($actor, $request->categories()),
            configured: true,
        );
    }
}
