<?php

namespace App\Http\Requests\Teacher;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\UploadedFile;
use Illuminate\Validation\Validator;

class TeacherLearningMaterialReplaceRequest extends FormRequest
{
    private const ACCEPTED_INPUT_KEYS = ['file'];

    public function authorize(): bool
    {
        return true;
    }

    /** @return array<string, mixed> */
    public function validationData(): array
    {
        return array_merge($this->request->all(), $this->allFiles());
    }

    /** @return array<string, list<mixed>> */
    public function rules(): array
    {
        return ['file' => ['required', 'file']];
    }

    public function withValidator(Validator $validator): void
    {
        $unknownKeys = array_values(array_diff(array_keys($this->validationData()), self::ACCEPTED_INPUT_KEYS));
        $queryKeys = array_keys($this->query->all());
        $isMultipart = str_starts_with(strtolower((string) $this->headers->get('CONTENT_TYPE')), 'multipart/form-data');
        $upload = $this->file('file');

        $validator->after(function (Validator $validator) use ($unknownKeys, $queryKeys, $isMultipart, $upload): void {
            if (! $isMultipart) {
                $validator->errors()->add('body', 'The request body must use multipart/form-data.');
            }

            foreach ($queryKeys as $queryKey) {
                $validator->errors()->add((string) $queryKey, 'Query parameters are not allowed for this endpoint.');
            }

            foreach ($unknownKeys as $unknownKey) {
                $validator->errors()->add((string) $unknownKey, 'This field is not allowed.');
            }

            if ($upload instanceof UploadedFile && $upload->isValid() && $upload->getSize() === 0) {
                $validator->errors()->add('file', 'The file must not be empty.');
            }

            if ($upload instanceof UploadedFile && strlen($upload->getClientOriginalName()) > 500) {
                $validator->errors()->add('file', 'The original file name must not exceed 500 characters.');
            }
        });
    }

    public function upload(): UploadedFile
    {
        /** @var UploadedFile $upload */
        $upload = $this->validated('file');

        return $upload;
    }
}
