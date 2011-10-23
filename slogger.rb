##########################################################à
# this class implements the singleton pattern to provide a single instance of the
#logger class,
# Extends the logger class with a method to logs a stream content

require 'singleton'
require 'logger'

class SLogger
    include Singleton
    attr_accessor :log

   ["fatal","error","warn","info","debug"].each do |msg|
      code = "def SLogger.#{msg}(*args) SLogger.instance.log.#{msg}(args) end"
      SLogger.class_eval code
   end

    def initialize
      @log = Logger.new(STDERR)
      @log.level = Logger::WARN
    end

    def self.logfile=(file)
       SLogger.instance.log = Logger.new(file)
    end

    def self.loglevel=(level)
       SLogger.instance.log.level = level
    end

    protected


    def finalize
      @log.close
    end

end

