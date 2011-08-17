require 'deps'
require 'facets'


class Compiler

  # Returns compiled code and CompileMessage-s. Note that if +source_code+
  # contains errors then the compiled code is unpredictable.
  def compile(source_code)
    @messages = []
    compiled_code = catch :compilation_stopped do compile0(source_code) end
    return compiled_code, messages
  end

  class CompileMessage

    def initialize(message, where = nil)
      @message = message
      @where = where
    end

    attr_reader :message
    alias msg message

    attr_reader :where

    def to_s
      (where ? "#{where}: " : "") + "#{self.class.methodize.gsub("_", " ").upcase}: #{message}"
    end

  end

  class Information < CompileMessage; end
  Info = Information
  class Warning < CompileMessage; end
  Warn = Warning
  class Error < CompileMessage; end

  protected

  # Implementation of #compile(), returns compiled code.
  def compile0(source_code)
    raise TypeError, "Abstraction is undefined"
  end

  # Current CompileMessage-s.
  attr_reader :messages

  # Adds CompileMessage to #messages.
  def message(message_class, message, where = nil)
    @messages << message_class.new(message, where)
  end

  # Adds Information to #messages.
  def information(msg, where = nil)
    message Info, msg, where
  end

  alias info information

  # Adds Warning to #messages.
  def warning(msg, where = nil)
    message Warning, msg, where
  end

  alias warn warning

  # Adds Error to #messages.
  def error(msg, where = nil)
    message Error, msg, where
  end

  # Adds Error to #messages and calls #stop_compilation().
  def fatal_error(msg, where = nil)
    error msg, where
    stop
  end

  alias fatal fatal_error
  alias fail fatal_error

  # Stops compilation prematurely. May be used in #compile0 only.
  def stop_compilation()
    throw :compilation_stopped
  end

  alias stop stop_compilation

end
