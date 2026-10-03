<?php

namespace Tests\Unit\Domain\Text;

use App\Domain\Text\UnicodeWhitespace;
use PHPUnit\Framework\Attributes\DataProvider;
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

    public function test_a_blank_value_becomes_empty_and_any_other_value_is_kept(): void
    {
        $this->assertSame('', UnicodeWhitespace::blankAsEmpty("\u{00A0}\u{3000}"));
        $this->assertSame("\u{00A0}Text\u{00A0}", UnicodeWhitespace::blankAsEmpty("\u{00A0}Text\u{00A0}"));
    }
}
