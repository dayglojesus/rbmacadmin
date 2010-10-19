require 'osx/cocoa'
require 'time'
include OSX

OSX.require_framework('SystemConfiguration')

module Kernel
 private
    # Method Caller ID
    # * Sometimes we want to know the name of the method invoked
    # * This is a Ruby 1.8.7 hack for a Ruby 1.9.1 feature
    # * Specify a level to run back up the execution stack
    def scf_error_caller_id(level)
      caller[level] =~ /`([^']*)'/ and $1
    end
end

# rbmacadmin bindings for Apple's System Configuration Framework
# * http://developer.apple.com/mac/library/DOCUMENTATION/Networking/Reference/SCDynamicStore/Reference/reference.html
module SCFramework
  
  def warn(arg)
    Kernel.warn(arg) if SCFError.warn?
  end
  
  # Multi-purpose error accumulator for working with the System Configuration Framework
  # * SCFError provides a catch-all for Cocoa SCErrors
  # * For a list of status and errors codes, http://tinyurl.com/yk3hmp5
  # * Errors are Struct type
  class SCFError < StandardError
    
    # All errors are type Struct: time of error, method called, error produced
    # Error produced consists of: error desc, error code, and object passed in
    Error = Struct.new(:time, :caller, :error)
    
    @@warnings = false
    @@all_errors = Object::Array.new()
    @@last_error = nil
    
    # Checks the result of an SC framework operation
    # * If the result is nil, SCFError will raise an exception
    # * If the result is a empty object, SCFError will warn but continue
    # * If the result is "other" and the SCError code is not ZERO, warn and continue
    def self.check(result, mname=scf_error_caller_id(1))
      @@last_error = result
      error_code = SCError()
      error_desc = SCErrorString(error_code)
      unless result
        @@last_error = "SCError: #{error_desc} (#{error_code}), [#{result.class}]"
        @@all_errors << Error.new(Time.now.xmlschema, mname, @@last_error)
        warn @@last_error
        raise error_code
      end
      begin
        if result.empty?
          @@last_error = "Empty #{result.class} object returned."
          warn @@last_error
          @@all_errors << Error.new(Time.now.xmlschema, mname, @@last_error)
        end
      rescue
        if error_code == 0
          return error_code 
        else
          @@last_error = "SCError: #{error_desc} (#{error_code}), [#{result.class}]"
          @@all_errors << Error.new(Time.now.xmlschema, mname, @@last_error)
          warn @@last_error
        end
      end
      error_code
    end
    
    # Retrieves the last error that was accumulated
    def self.last
      @@all_errors.last
    end
    
    # Retrieves the all accumulated errors
    def self.all_errors
      @@all_errors
    end
    
    # Turn on/off warnings
    # * By itself, #warn? returns the state of @@warnings
    # * An optional true argument will set @@warnings
    def self.warn?(on=false)
      unless @@warnings == true
        @@warnings = on
      end
      @@warnings
    end
    
    private
    
  end
    
end







































