require 'test/unit'
require 'simplified_yaml'


class SimplifiedYAML::PositionTest < Test::Unit::TestCase

  def test_basic
    syaml = SimplifiedYAML.new <<STRING
abc
def
  ghi
  jkl
    mno
    pqr
STRING
    pos = SimplifiedYAML::Position.new(syaml, 10, 2)
    char_at_pos = lambda { syaml.to_s[pos.offset] }
    assert char_at_pos[] == ?g
    pos += 5
    assert char_at_pos[] == ?k
    pos = (pos + 3).indented(+2)
    assert char_at_pos[] == ?m
    assert pos.column == 4
    assert pos.line == 4
    pos += 5
    assert char_at_pos[] == ?q
  end
  
end
