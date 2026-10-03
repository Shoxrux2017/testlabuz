<?php

namespace Tests\Unit\Domain\Text;

use App\Domain\Text\UnicodeWhitespace;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\RunInSeparateProcess;
use PHPUnit\Framework\TestCase;

class UnicodeWhitespaceTest extends TestCase
{
    /** @return array<string, array{string}> */
    public static function blankTexts(): array
    {
        return [
            'empty' => [''],
            'ascii spaces and controls' => [" \t\n\r\u{000B}\u{000C}"],
            'next line' => ["\u{0085}"],
            'no-break space' => ["\u{00A0}\u{00A0}"],
            'ogham space mark' => ["\u{1680}"],
            'en quad to hair space' => ["\u{2000}\u{2005}\u{200A}"],
            'line and paragraph separators' => ["\u{2028}\u{2029}"],
            'narrow no-break and medium mathematical space' => ["\u{202F}\u{205F}"],
            'ideographic space' => ["\u{3000}"],
            'byte order mark' => ["\u{FEFF}"],
        ];
    }

    #[DataProvider('blankTexts')]
    public function test_text_made_only_of_the_dart_trim_whitespace_set_is_blank(string $text): void
    {
        $this->assertTrue(UnicodeWhitespace::isBlank($text));
    }

    /** @return array<string, array{string}> */
    public static function nonBlankTexts(): array
    {
        return [
            'letter between no-break spaces' => ["\u{00A0}a\u{00A0}"],
            'zero width space is not whitespace' => ["\u{200B}"],
            'nul byte' => ["\0"],
            'punctuation' => ['.'],
        ];
    }

    #[DataProvider('nonBlankTexts')]
    public function test_text_with_any_other_character_is_not_blank(string $text): void
    {
        $this->assertFalse(UnicodeWhitespace::isBlank($text));
    }

    public function test_trim_removes_the_whitespace_set_only_at_both_ends(): void
    {
        $this->assertSame("Revise\u{00A0}question 4.", UnicodeWhitespace::trim("\u{3000}\u{00A0} Revise\u{00A0}question 4.\n\u{FEFF}"));
        $this->assertSame('', UnicodeWhitespace::trim("\u{00A0}\u{2009}"));
        $this->assertSame("\u{200B}x\u{200B}", UnicodeWhitespace::trim("\u{200B}x\u{200B}"));
    }

    public function test_trim_handles_a_trailing_whitespace_run_beyond_the_backtracking_limit(): void
    {
        // Pinned to the default, so a raised php.ini limit cannot hide a backtracking trim.
        $limit = ini_set('pcre.backtrack_limit', '1000000');

        try {
            $this->assertSame('x', UnicodeWhitespace::trim('x'.str_repeat(' ', 1_000_001)));
            $this->assertSame('x', UnicodeWhitespace::trim(str_repeat("\u{00A0}", 1_000_001).'x'));
        } finally {
            ini_set('pcre.backtrack_limit', (string) $limit);
        }
    }

    /** A separate process: PHP caches compiled patterns with their JIT code, so JIT must be off before the first use. */
    #[RunInSeparateProcess]
    public function test_trim_is_linear_for_long_whitespace_runs_inside_the_text(): void
    {
        // Without the PCRE JIT a backtracking trim takes about 2 seconds here and minutes at 200 000.
        $jit = ini_set('pcre.jit', '0');
        $text = 'x'.str_repeat(' ', 20000).'y';

        try {
            $started = hrtime(true);

            $this->assertSame($text, UnicodeWhitespace::trim(" {$text}\u{00A0}"));
            $this->assertSame($text, UnicodeWhitespace::trim($text));
            $this->assertLessThan(0.2, (hrtime(true) - $started) / 1e9);
        } finally {
            ini_set('pcre.jit', (string) $jit);
        }
    }

    public function test_a_blank_value_becomes_empty_and_any_other_value_is_kept(): void
    {
        $this->assertSame('', UnicodeWhitespace::blankAsEmpty("\u{00A0}\u{3000}"));
        $this->assertSame("\u{00A0}Text\u{00A0}", UnicodeWhitespace::blankAsEmpty("\u{00A0}Text\u{00A0}"));
    }
}
