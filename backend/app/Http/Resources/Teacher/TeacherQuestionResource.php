<?php

namespace App\Http\Resources\Teacher;

use App\Domain\Assessment\QuestionConfigurationValidator;
use App\Models\Question;
use App\Support\Assessment\QuestionConfigurationReader;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use InvalidArgumentException;
use LogicException;
use stdClass;

/** @mixin Question */
class TeacherQuestionResource extends JsonResource
{
    /** @return array<string, mixed> */
    public function toArray(Request $request): array
    {
        $configuration = (new QuestionConfigurationReader)->read($this->resource);

        try {
            (new QuestionConfigurationValidator)->validate(
                $this->type,
                $this->checking_mode,
                $this->prompt,
                $configuration,
            );
        } catch (InvalidArgumentException $exception) {
            throw new LogicException('Persisted Question configuration is invalid.', previous: $exception);
        }

        return [
            'id' => $this->id,
            'type' => $this->type->value,
            'prompt' => $this->prompt,
            'instructions' => $this->instructions,
            'points' => (float) $this->points,
            'position' => $this->position,
            'checking_mode' => $this->checking_mode->value,
            'configuration' => $configuration === [] ? new stdClass : $configuration,
        ];
    }
}
