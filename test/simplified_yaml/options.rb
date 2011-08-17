require 'test/unit'
require 'simplified_yaml'


class SimplifiedYAML::OptionsTest < Test::Unit::TestCase

  def test_escapes
    [ reference_escapes = [/a/], ["a"], /a/, "a" ].each do |value_for_escapes|
      assert SimplifiedYAML::Options.new(:escapes => value_for_escapes).escapes == reference_escapes, %Q{#{SimplifiedYAML::Options} must automatically convert #{value_for_escapes.inspect} to #{reference_escapes.inspect}}
    end
    assert_raise TypeError do SimplifiedYAML::Options.new(:escapes => 1); end
  end

  def test_quotes
    [ reference_quotes = [/a/], ["a"], /a/, "a" ].each do |value_for_quotes|
      assert SimplifiedYAML::Options.new(:quotes => value_for_quotes).quotes == reference_quotes, %Q{#{SimplifiedYAML::Options} must automatically convert #{value_for_quotes.inspect} to #{reference_quotes.inspect}}
    end
    assert_raise TypeError do SimplifiedYAML::Options.new(:quotes => 1); end
  end

  def test_brackets
    [
      reference_brackets = [[/a/, /b/], [/c/, /d/]],
      [%w{ a b }, %w{ c d }],
      {'a' => 'b', 'c' => 'd'},
      %w{ a b c d },
    ].each do |value_for_brackets|
      opts = SimplifiedYAML::Options.new(:brackets => value_for_brackets)
      assert opts.brackets == reference_brackets, %Q{#{SimplifiedYAML::Options} must automatically convert #{opts.brackets.inspect} to #{reference_brackets.inspect}}
      assert_nothing_thrown %Q{#{SimplifiedYAML::Options} must add helper methods to bracket patterns automatically} do opts.brackets[0].left; opts.brackets[0].right; end
    end
    assert_raise TypeError do SimplifiedYAML::Options.new(:brackets => %w{ a b c }); end
  end
  
end
