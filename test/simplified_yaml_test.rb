require 'test/unit'
require 'simplified_yaml'


class SimplifiedYAMLTest < Test::Unit::TestCase

  def test_entries_basic
    syaml = SimplifiedYAML.new <<EOS.gsub("*", " ")
  First entry:
    text
****
    more text
**
  Second entry:
    text
    more text
EOS
    entries = syaml.entries
    assert entries[0].to_s == <<EOS.gsub("*", " ").chomp
First entry:
  text
**
  more text
EOS
    assert entries[0].pos.offset == 2
    assert entries[1].to_s == <<EOS.chomp
Second entry:
  text
  more text
EOS
    assert entries[1].pos.offset == syaml.to_s.index("Second entry")
  end

  def test_entries_on_invalid_indentation
    begin
      syaml = SimplifiedYAML.new <<EOS
    First entry
Invalid entry
EOS
      syaml.entries
      fail %Q{#{SimplifiedYAML}.entries must fail on invalid list}
    rescue SimplifiedYAML::InvalidIndentation => e
      assert e.pos.offset == syaml.to_s.index("Invalid entry"), %Q{#{SimplifiedYAML}.entries must show correct position of error if error found}
    end
  end

  def test_split
    syaml = SimplifiedYAML.new "aaa, (bbb, ccc), ddd\\,eee, \"fff,ggg\", hhh",
      :escapes => /\\./,
      :quotes => /\"/,
      :brackets => %w{ ( ) }
    assert syaml.split(/\,\s*/).each { |x| assert x.is_a?(SimplifiedYAML), %Q{Result of #{SimplifiedYAML}.split must be #{SimplifiedYAML}-s also} }.every.to_s == ["aaa", "(bbb, ccc)", "ddd\\,eee", "\"fff,ggg\"", "hhh"]
    assert syaml.split(/\,\s*/, 4).every.to_s == ["aaa", "(bbb, ccc)", "ddd\\,eee", "\"fff,ggg\", hhh"]
  end

  def test_mapping_on_one_line_mapping
    syaml = SimplifiedYAML.new "abc: def"
    assert syaml.mapping.key.to_s == "abc"
    assert syaml.mapping.value.to_s == "def"
    assert syaml.mapping.value.pos_in_source.offset == 5
    assert syaml.mapping.value.pos_in_source.indentation_size == 0
  end

  def test_mapping_on_multiline_mapping
    syaml = SimplifiedYAML.new <<SYAML
abc:
  def
    ghi
  jkl
SYAML
    assert syaml.mapping.key.to_s == "abc"
    assert syaml.mapping.value.to_s == <<SYAML
def
  ghi
jkl
SYAML
    assert syaml.mapping.value.pos_in_source.offset == 7
    assert syaml.mapping.value.pos_in_source.indentation_size == 2
  end

  def test_mapping_on_multiline_mapping_with_hazardous_spaces_after_key
    syaml = SimplifiedYAML.new <<SYAML.gsub("*", " ")
abc:***
  def
    ghi
  jkl
SYAML
    assert syaml.mapping.key.to_s == "abc"
    assert syaml.mapping.value.to_s == <<SYAML
def
  ghi
jkl
SYAML
    assert syaml.mapping.value.pos_in_source.offset == 10
    assert syaml.mapping.value.pos_in_source.indentation_size == 2
  end

  def test_outdent_and_indentation_size
    syaml = SimplifiedYAML.new <<SYAML
      Abc
    Def
  Ghi
    Jkl
      Mno
SYAML
    assert syaml.indentation_size == 2
    assert syaml.outdent(2).to_s == <<SYAML
    Abc
  Def
Ghi
  Jkl
    Mno
SYAML
    assert syaml.outdent(2).pos_in_source.offset == 2
    assert syaml.outdent(2).pos_in_source.indentation_size == 2
    begin
      syaml.outdent(4)
      fail %Q{Outdenting too much must raise an exception}
    rescue
    end
  end

end
