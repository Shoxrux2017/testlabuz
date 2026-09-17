<?php

namespace App\Http\Controllers\Api\V1\Student;

use App\Actions\Student\ListStudentActiveBlitz;
use App\Actions\Student\ShowStudentBlitz;
use App\Http\Controllers\Controller;
use App\Http\Requests\Student\StudentBlitzActiveRequest;
use App\Http\Requests\Student\StudentBlitzShowRequest;
use App\Http\Resources\Student\StudentBlitzCollection;
use App\Http\Resources\Student\StudentBlitzResource;
use App\Models\User;

class StudentBlitzController extends Controller
{
    public function active(StudentBlitzActiveRequest $request, ListStudentActiveBlitz $listBlitz): StudentBlitzCollection
    {
        /** @var User $student */
        $student = $request->user();

        return new StudentBlitzCollection($listBlitz($student));
    }

    public function show(StudentBlitzShowRequest $request, string $blitz, ShowStudentBlitz $showBlitz): StudentBlitzResource
    {
        /** @var User $student */
        $student = $request->user();

        return new StudentBlitzResource($showBlitz($student, $blitz));
    }
}
