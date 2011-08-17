require 'test/unit'
require 'simplified_yaml'


class SimplifiedYAML::SpecializedStringScannerTest < Test::Unit::TestCase

  def test_basic
    test_string = <<'STRING'
Simple string,
Other simple string,
Some "Quoted string",
"Quoted string with escaped \" quote",
Bracketed (string),
(Bracketed (nested) string),
(Bracketed string, with comma),
(Bracketed (nested string, with) comma),
"Quoted string with some brackets: (((",
Complex case: (one (two (three "("), ) ),
STRING
    scanner = new_test_scanner(test_string)
    comma_separated_strings = []; comma_separated_strings << (str, ending = scanner.scan_until(/,\s*/); str) until scanner.eos?
    comma_separated_strings_ref = test_string.split(/,\n/)
    assert comma_separated_strings == comma_separated_strings_ref
  end

  def test_unclosed_quote
    test_string = %Q{Unclosed "quote}
    begin
      new_test_scanner(test_string).scan_until('end')
      fail %Q{#{SimplifiedYAML::SpecializedStringScanner} must fail on unclosed quotes}
    rescue Exception => e
      assert e.is_a?(SimplifiedYAML::ClosingQuoteNotFound), %Q{#{SimplifiedYAML::SpecializedStringScanner} must raise #{SimplifiedYAML::ClosingQuoteNotFound} on unclosed quote}
      assert e.opening_quote_pos.column == 9, %Q{#{SimplifiedYAML::SpecializedStringScanner} must report correct position of unclosed quote}
    end
  end

  def test_unclosed_bracket
    test_string = %Q{Unclosed (bracket (other brackets) (yet another brackets)}
    begin
      new_test_scanner(test_string).scan_until('end')
      fail %Q{#{SimplifiedYAML::SpecializedStringScanner} must fail on unclosed bracket}
    rescue Exception => e
      assert e.is_a?(SimplifiedYAML::ClosingBracketNotFound), %Q{#{SimplifiedYAML::SpecializedStringScanner} must raise #{SimplifiedYAML::ClosingBracketNotFound} on unclosed bracket}
      assert e.opening_bracket_pos.column == 9, %Q{#{SimplifiedYAML::SpecializedStringScanner} must report correct position of unclosed bracket}
    end
  end

  private

  def new_test_scanner(source_str)
    SimplifiedYAML::SpecializedStringScanner.new(
      SimplifiedYAML.new(
        source_str,
        :escapes => /\\./,
        :quotes => '"',
        :brackets => %w{ ( ) }
      ),
      source_str
    )
  end
  
end
