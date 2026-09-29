<?php

namespace Tests\Unit\Domain\Assessment\Checking;

use App\Domain\Assessment\Checking\AnswerTextNormalizer;
use LogicException;
use PHPUnit\Framework\TestCase;

class AnswerTextNormalizerTest extends TestCase
{
    private AnswerTextNormalizer $normalizer;

    protected function setUp(): void
    {
        $this->normalizer = new AnswerTextNormalizer;
    }

    public function test_nfc_composes_a_decomposed_letter(): void
    {
        $this->assertSame("\u{00E9}", $this->normalizer->normalize("e\u{0301}"));
        $this->assertSame(
            $this->normalizer->normalize("caf\u{00E9}"),
            $this->normalizer->normalize("cafe\u{0301}"),
        );
    }

    public function test_full_case_folding_is_locale_independent(): void
    {
        $this->assertSame('strasse', $this->normalizer->normalize('Straße'));
        $this->assertSame('ss', $this->normalizer->normalize("\u{1E9E}"));
        $this->assertSame("i\u{0307}", $this->normalizer->normalize("\u{0130}"));
        $this->assertSame('привет', $this->normalizer->normalize('ПРИВЕТ'));
        $this->assertSame('sherzod', $this->normalizer->normalize('SHERZOD'));
    }

    public function test_the_second_nfc_recomposes_case_folded_output(): void
    {
        // U+01F0 folds to "j" + combining caron; NFC composes it again.
        $this->assertSame("\u{01F0}", $this->normalizer->normalize("\u{01F0}"));
        $this->assertSame("\u{01F0}", $this->normalizer->normalize("J\u{030C}"));
    }

    public function test_every_apostrophe_variant_becomes_an_ascii_apostrophe(): void
    {
        foreach (["'", '`', "\u{00B4}", "\u{02BB}", "\u{02BC}", "\u{2018}", "\u{2019}"] as $apostrophe) {
            $this->assertSame("o'zbek", $this->normalizer->normalize("O{$apostrophe}zbek"), bin2hex($apostrophe));
        }
    }

    public function test_an_apostrophe_produced_by_case_folding_is_still_mapped(): void
    {
        // U+0149 folds to U+02BC followed by "n".
        $this->assertSame("'n", $this->normalizer->normalize("\u{0149}"));
    }

    public function test_every_whitespace_code_point_collapses_to_one_space(): void
    {
        $codePoints = [
            ...range(0x09, 0x0D),
            0x20, 0x85, 0xA0, 0x1680,
            ...range(0x2000, 0x200A),
            0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF,
        ];

        foreach ($codePoints as $codePoint) {
            $space = mb_chr($codePoint, 'UTF-8');
            $this->assertSame('a b', $this->normalizer->normalize("a{$space}b"), sprintf('U+%04X', $codePoint));
        }
    }

    public function test_whitespace_runs_collapse_and_the_ends_are_trimmed(): void
    {
        $this->assertSame('a b c', $this->normalizer->normalize(" \t a \u{00A0}\n b\u{3000}\u{FEFF}c \r\n"));
    }

    public function test_punctuation_and_other_symbols_stay_significant(): void
    {
        $this->assertSame('a.b', $this->normalizer->normalize('A.B'));
        $this->assertNotSame($this->normalizer->normalize('ab'), $this->normalizer->normalize('a-b'));
        $this->assertSame("\u{201C}a\u{201D}", $this->normalizer->normalize("\u{201C}A\u{201D}"));
        $this->assertSame("o\u{02B9}z", $this->normalizer->normalize("O\u{02B9}z"));
        $this->assertNotSame($this->normalizer->normalize('ab'), $this->normalizer->normalize("a\u{200B}b"));
    }

    public function test_invalid_utf8_throws(): void
    {
        $this->expectException(LogicException::class);

        $this->normalizer->normalize("\xFF");
    }
}
