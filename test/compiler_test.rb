require 'test/unit'
require 'compiler'


class CompilerTest < Test::Unit::TestCase

  class TestCompiler < Compiler

    attr_reader :passed_after_fatal_error

    protected

    def compile0(source_code)
      info "Test"
      warning "Test2", 10
      error "Test3"
      fatal_error "Test4"
      @passed_after_fatal_error = true
    end

  end

  def test_basic_functionality
    test_compiler = TestCompiler.new
    result, messages = test_compiler.compile(nil)
    assert messages.map { |x| x.class } == [Compiler::Info, Compiler::Warning, Compiler::Error, Compiler::Error]
    assert messages[1].where == 10
    assert !test_compiler.passed_after_fatal_error
  end

end
