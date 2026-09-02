<?php

namespace App\Domain\Assessment;

final class QuestionAuthoringLimits
{
    public const int MAX_QUESTIONS_PER_ASSESSMENT = 100;

    public const int MAX_PROMPT_LENGTH = 10000;

    public const int MAX_INSTRUCTIONS_LENGTH = 5000;

    public const int MAX_CHOICE_OPTIONS = 20;

    public const int MAX_OPTION_TEXT_LENGTH = 2000;

    public const int MAX_SHORT_ACCEPTED_ANSWERS = 20;

    public const int MAX_ACCEPTED_ANSWER_LENGTH = 1000;

    public const int MAX_MATCHING_PAIRS = 50;

    public const int MAX_MATCHING_ITEM_TEXT_LENGTH = 2000;

    public const int MAX_CLIENT_KEY_LENGTH = 80;

    public const int MAX_ORDERING_ITEMS = 50;

    public const int MAX_ORDERING_ITEM_TEXT_LENGTH = 2000;

    public const int MAX_FILL_BLANKS = 50;

    public const int MAX_ACCEPTED_ANSWERS_PER_BLANK = 20;
}
