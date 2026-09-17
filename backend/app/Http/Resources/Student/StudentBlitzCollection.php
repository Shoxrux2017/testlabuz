<?php

namespace App\Http\Resources\Student;

use Illuminate\Http\Resources\Json\ResourceCollection;

class StudentBlitzCollection extends ResourceCollection
{
    public $collects = StudentBlitzSummaryResource::class;
}
