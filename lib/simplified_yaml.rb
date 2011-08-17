require 'deps'
require 'facets'
require 'strscan'


# TODO: Doc.
class SimplifiedYAML

  # :call-seq:
  # new(source_str, options = {})
  #
  # +source_str+:: string to be converted into SimplifiedYAML.
  #
  # +options+::
  #      value for #options. It may be Options or Hash which Options can be
  #      created on. See Options for details.
  #
  def initialize(source_str, options = Options.new, pos_in_source = nil)
    @source_str = source_str
    @pos_in_source = pos_in_source || Position.new(self, 0, 0)
    @options =
      case options
      when Options then options
      when Hash then Options.new(options)
      else raise TypeError, "Can not convert #{options.inspect} to #{Options}"
      end
  end

  # If this SimplifiedYAML is part of other SimplifiedYAML then this property
  # shows position in source SimplifiedYAML from which this one starts. Otherwise
  # It is just zeroth Position.
  def pos_in_source
    @pos_in_source
  end

  alias pos pos_in_source

  # Options of this SimplifiedYAML.
  def options
    @options
  end

  alias opts options

  alias opt options

  # Entries of this SimplifiedYAML considered to be list.
  #
  # Example of SimplifiedYAML list is following (vertical lines and "+"-s denote
  # separate entries and dots represent spaces):
  #
  #   ^ ..Abc
  #   | ....Def
  #   | ....Ghi
  #   | ......Klm
  #   v ....Nop
  #     ..
  #   ^ ..Xxx
  #   | ....Yyyy
  #   | ....
  #   v ....Zzzz
  #     ..
  #   + ..Single line entry.
  #   + ..Another single line entry.
  #     ..
  #
  # Notice that the entries are automatically outdented and the list above has
  # following entries:
  #
  #   Abc
  #   ..Def
  #   ..Ghi
  #   ....Klm
  #   ..Nop
  #
  #   Xxx
  #   ..Yyyy
  #   ..
  #   ..Zzzz
  #
  #   Single line entry.
  #
  #   Another single line entry.
  #
  # And here is example of invalid SimplifiedYAML list:
  #
  #   ....Abc
  #   ......Def
  #   ..Ghi     <--- Invalid indentation. Is this line separate entry or what?
  #   ..        <--- Invalid indentation too.
  #   ....Klm
  #   ....Nop
  #
  # All entries are SimplifiedYAML-s.
  #
  def entries
    #
    indentation_size_of_entries = indentation_size_of(@source_str.lines.first)
    current_pos = pos_in_source
    #
    @source_str.lines.
      # Split to entries.
      filter([]) do |result, line|
        if indentation_size_of(line) == indentation_size_of_entries
          result << line
        elsif indentation_size_of(line) > indentation_size_of_entries
          if result.empty? then result << line; else result.last << line; end
        elsif indentation_size_of(line) < indentation_size_of_entries
          raise InvalidIndentation.new(pos_in_source + result.join.length, indentation_size_of_entries)
        end
      end.
      # Convert to SimplifiedYAML-s rejecting blank entries.
      filter([]) do |result, entry_string|
        begin
          unless entry_string.blank?
            result << new_simplified_yaml(
              entry_string.outdent(indentation_size_of_entries).chomp,
              current_pos + indentation_size_of_entries
            )
          end
        ensure
          current_pos += entry_string.length
        end
      end
  end

  # :call-seq:
  #   split(pattern, [limit])
  #
  # Divides this SimplifiedYAML into sub-SimplifiedYAML-s, returning an Array
  # of these sub-SimplifiedYAML-s.
  #
  # +pattern+ may be String or Regexp. The SimplifiedYAML is divided either
  # where the String occurrs or where the Regexp matches.
  #
  # If +limit+ is specified then at most +limit+ parts are returned, and the
  # SpecifiedYAML is not divided at the rest of +pattern+s.
  #
  # Example:
  #
  #   "abc|def|ghi" -> split("|")    -> "abc", "def", "ghi"
  #   "abc|def|ghi" -> split("|", 2) -> "abc", "def|ghi"
  #
  def split(pattern, limit = nil)
    raise "limit must be positive integer > 0 but it is #{limit.inspect}" unless limit.nil? or (limit.is_a?(Integer) and limit > 0)
    #
    scanner = new_scanner
    #
    result = []
    for i in (limit.nil? ? From0ToInfinity.new : 1...limit)
      break if scanner.eos?
      part, delimiter = scanner.scan_until(pattern)
      result << new_simplified_yaml(part, pos_in_source + scanner.pos)
    end
    #
    result << new_simplified_yaml(scanner.rest, pos_in_source + scanner.pos) unless scanner.rest.empty?
    #
    return result
  end

  # This SimplifiedYAML considered to be Mapping.
  #
  # SimplifiedYAML mapping is a key-value pair separated with colon and following
  # whitespace. Here are examples of SimplifiedYAML mappings (dots represent spaces):
  #
  #   Example    Key   Value
  #   -------    ---   -----
  #   Abc:.def   Abc   def
  #
  #   Abc:       Abc   Def
  #   ..Def            ..Ghi
  #   ....Ghi          Jkl
  #   ..Jkl
  #
  # Also SimplifiedYAML-s without colons are also mappings but with key equal
  # to the whole SimplifiedYAML and value equal to +nil+:
  #
  #   Example    Key       Value
  #   -------    ---       -----
  #
  #   Abc def.   Abc def.  nil
  #
  # Both key and value are SimplifiedYAML-s (or +nil+s).
  #
  def mapping
    #
    key, value = split(/\:( +\n?| *\n)/, 2)
    # Normalize value.
    if value.nil?
      # Do nothing.
    else
      value = value.outdent(value.indentation_size)
    end
    #
    return Mapping.new(key, value)
  end

  # Key of this SimplifiedYAML considered to be Mapping.
  #
  # See #mapping for details.
  #
  def key
    mapping.key
  end

  # Value of this SimplifiedYAML considered to be Mapping.
  #
  # See #mapping for details.
  #
  def value
    mapping.value
  end

  def outdent(indentation_size)
    raise "Can not outdent this #{SimplifiedYAML} more than by #{self.indentation_size} columns (but tried to outdent by #{indentation_size} columns)" unless indentation_size <= self.indentation_size
    new_simplified_yaml(@source_str.outdent(indentation_size), pos_in_source.indented(indentation_size))
  end

  # "How much this SimplifiedYAML is indented?"
  def indentation_size
    indentation_size_of(@source_str)
  end

  def to_s
    @source_str
  end

  class Mapping

    def initialize(key, value)
      @key, @value = key, value
    end

    attr_reader :key
    attr_reader :value

  end

  # Immutable.
  class Options

    # +hash+::
    #   Hash of Options' properties to their values.
    #   Example: <code>{ :escapes => /\\./ }</code>.
    def initialize(hash = {})
      (Options.public_instance_methods(false) + Options.protected_instance_methods(false) + Options.private_instance_methods(false)).
        select { |method| method.end_with? "=" }.
        map { |setter| [setter.chomp("=").to_sym, setter.to_sym] }.
        to_h.
        each_pair do |property, setter|
          self.send(setter, hash[property])
        end
    end

    # Array of escape sequences (sequences which are interpreted "as is") in
    # the form of Regexp-s.
    #
    # The property can be defined with Array of String-s or Regexp-s.
    #
    # Default is empty Array.
    #
    attr_reader :escapes

    # Array of "quote" sequences in the form of Regexp-s.
    #
    # The property can be defined with Array of String-s or Regexp-s.
    #
    # Default is empty Array.
    #
    attr_reader :quotes

    # Array of "left bracket" and "right bracket" sequences in the form of Regexp-s.
    # Each entry from this Array has got +left+ (AKA +opening+) and +right+
    # (AKA +closing+) methods.
    #
    # The property can be defined with Array of 2-element Array-s, with Hash of
    # "left bracket" to "right bracket" sequences or even with even-sized Array
    # of the sequences. The sequences theirself can be defined with String-s or
    # Regexp-s.
    #
    # Default is empty Array.
    #
    attr_reader :brackets

    protected

    def escapes=(value)
      @escapes = to_array_of_regexps(value || []).freeze
    end

    def quotes=(value)
      @quotes = to_array_of_regexps(value || []).freeze
    end

    def brackets=(value)
      @brackets = to_array_of_brackets(value || []).freeze
    end

    private

    def to_array_of_regexps(value)
      case value
      when Array
        value.map do |entry|
          raise TypeError, "Can not convert #{entry.inspect} to #{Regexp}" unless entry.respond_to? :to_re
          entry.to_re(true)
        end
      when Enumerable then to_array_of_regexps(value.to_a)
      else to_array_of_regexps([value])
      end
    end

    # Adds methods described in documentation for #brackets to entry from
    # the #brackets.
    def add_bracket_methods(brackets_entry)

      class << brackets_entry

        def left
          self[0]
        end

        alias opening left

        def right
          self[1]
        end

        alias closing right

      end

      return brackets_entry

    end

    # Converts specified value to what can be used as #brackets.
    def to_array_of_brackets(value)
      case value
      when Array
        # Someone may write "opt.brackets = %w{ ( ) < > }" and he will be right.
        if value.not_empty? and value.size.even? and not value.per.all?.is_a?(Array) then return to_array_of_brackets(value.each_by 2); end
        #
        value.map do |entry|
          raise TypeError, "Can not convert #{entry.inspect} to #{Array} of length 2" unless entry.is_a?(Array) and entry.size == 2
          entry = entry.map do |bracket_pattern|
            raise TypeError, "Can not convert #{bracket_pattern.inspect} to #{Regexp}" unless bracket_pattern.respond_to? :to_re
            bracket_pattern.to_re(true)
          end
          add_bracket_methods(entry)
        end
      when Enumerable, Hash
        to_array_of_brackets(value.to_a)
      else
        raise TypeError, "Can not convert #{value.inspect} to Array of 2-element #{Array}-s of #{Regexp}-s"
      end
    end

  end

  class Position

    def initialize(where, offset, indentation_size)
      raise "Indentation size (#{indentation_size}) can not be more than offset (#{offset})" if indentation_size > offset
      @where = where
      @indentation_size = indentation_size
      @offset = offset
    end

    # What this Position is defined in.
    attr_reader :where

    # How much element this Position points to is indented.
    attr_reader :indentation_size

    alias indent_size indentation_size

    # Offset of this Position in #where.
    attr_reader :offset

    # Line this Position points to in #where.
    def line
      where.to_s[0...offset].lines.count - 1
    end

    # Column this Position points to in #where.
    def column
      where.to_s[0...offset].lines.to_a.last.length
    end

    alias col column

    # Returns new Position which is +relative_offset+ characters farther from
    # this Position, considering #indentation_size.
    #
    # Examples:
    #
    # 1) +pos+ has #indentation_size 0 and points to where shown:
    #
    #     abc
    #     ^
    #     def
    #       ghi
    #       jkl
    #
    #     pos + 5 #=>
    #
    #     abc
    #     def
    #      ^
    #       ghi
    #       jkl
    #
    # 2) +pos+ has #indentation_size 2 and points to where shown:
    #
    #     abc
    #     def
    #       ghi
    #       ^
    #       jkl
    #
    #     pos + 5 #=>
    #
    #     abc
    #     def
    #       ghi
    #       jkl
    #        ^
    #
    def +(relative_offset)
      Position.new(
        where,
        offset + where.to_s[(offset - indent_size)..-1].outdent(indent_size)[0...relative_offset].indent(indent_size).length - indent_size,
        indent_size
      )
    end

    # Returns new Position indented from this one by specified size.
    def indented(relative_indentation_size)
      Position.new(
        where,
        offset + indent_size + relative_indentation_size,
        indent_size + relative_indentation_size
      )
    end

    alias indent indented

    def to_s
      "line #{line}, col #{col}: ``#{where.to_s.newlines.to_a[line]}''"
    end

  end

  class SyntaxError < Exception

    def initialize(pos, msg = "Syntax error at #{pos}")
      super(msg)
      @pos = pos
    end

    attr_reader :pos

  end

  class InvalidIndentation < SyntaxError

    def initialize(pos, expected_indentation_size, msg = "Invalid indentation size at #{pos}: #{expected_indentation_size} is expected")
      super(pos, msg)
      @expected_indentation_size = expected_indentation_size
    end

    attr_reader :expected_indentation_size

  end

  class ClosingQuoteNotFound < SyntaxError

    def initialize(opening_quote_pos, msg = "Closing quote is not found for quote at #{opening_quote_pos}")
      super(opening_quote_pos, msg)
    end

    def opening_quote_pos
      pos
    end

  end

  # TODO: Tabs?

  class ClosingBracketNotFound < SyntaxError

    def initialize(opening_bracket_pos, msg = "Closing bracket is not found for bracket at #{opening_bracket_pos}")
      super(opening_bracket_pos, msg)
    end

    def opening_bracket_pos
      pos
    end

  end

  class InvalidIndentation < SyntaxError

    def initialize(pos, expected_min_indentation_size)
      super(pos)
      @expected_min_indentation_size = expected_min_indentation_size
    end

    attr_reader :expected_min_indentation_size

  end

  private

  def indentation_size_of(str)
    str.lines.every[/^ */].every.length.min
  end

  # Returns new SimplifiedYAML based on +self+.
  def new_simplified_yaml(source_str, pos_in_source)
    SimplifiedYAML.new(source_str, options, pos_in_source)
  end

  # Returns new SpecializedStringScanner on specified string or, by default, on
  # +self+.
  def new_scanner(str = @source_str)
    SpecializedStringScanner.new(self, str)
  end

  class SpecializedStringScanner

    def initialize(outer, str)
      @outer = outer
      @scanner = StringScanner.new(str)
    end

    # Scans the string until one of specified patterns will appear or till the end,
    # considering escape sequences, brackets and quotes. The pattern found is consumed too.
    #
    # +patterns+:: Regexp-s or String-s to scan until.
    #
    # Returns consumed string and the pattern or just consumed string if
    # no patterns are found.
    #
    def scan_until(*patterns)
      patterns.every!.to_re(true)
      result = ""
      result << next_atom until (pattern = patterns.find { |pattern| scanner.check pattern }) or scanner.eos?
      return result, (scanner.scan pattern if pattern)
    end

    # Position which this SpecializedStringScanner currently points to in
    # the String.
    def pos
      scanner.pos
    end

    # "Is end of the string is reached?"
    def eos?
      scanner.eos?
    end

    # The rest, not consumed part of the String.
    def rest
      scanner.rest
    end

    private

    # Returns next atom from string or +nil+ if there are no more atoms.
    #
    # +atom_types+:: what types of atom to consider along with "character" atoms. The types may be +:escaped+, +:quoted+ or +:bracketed+. Default is all these.
    #
    def next_atom(*atom_types)
      if atom_types.size == 0 then atom_types = [:escaped, :quoted, :bracketed]; end
      #
      if atom_types.include?(:escaped) && (escape_pattern = outer.opts.escapes.find { |candidate_escape_pattern| scanner.check candidate_escape_pattern }) then
        return scanner.scan escape_pattern
      end
      #
      if atom_types.include?(:quoted) && (quote_pattern = outer.opts.quotes.find { |candidate_quote_pattern| scanner.check candidate_quote_pattern }) then
        opening_quote_pos = scanner.pos
        result = scanner.scan quote_pattern
        result << next_atom(:escaped) until (closing_quote = scanner.scan quote_pattern) or scanner.eos?
        raise ClosingQuoteNotFound.new(outer.pos_in_source + opening_quote_pos) unless closing_quote
        result << closing_quote
        return result
      end
      #
      if atom_types.include?(:bracketed) && (bracket_pattern = outer.opts.brackets.find { |candidate_bracket_pattern| scanner.check candidate_bracket_pattern.opening })
        opening_bracket_pos = scanner.pos
        result = scanner.scan bracket_pattern.opening
        result << next_atom until (closing_bracket = scanner.scan bracket_pattern.closing) or scanner.eos?
        raise ClosingBracketNotFound.new(outer.pos_in_source + opening_bracket_pos) unless closing_bracket
        result << closing_bracket
        return result
      end
      # Other (just a character).
      return scanner.getch unless scanner.eos?
    end

    # Helping StringScanner.
    attr_reader :scanner

    # Outer instance this object belongs to.
    attr_reader :outer

  end

  class From0ToInfinity

    is Enumerable

    def each
      n = 0
      loop { yield n; n += 1 }
    end

  end

end
