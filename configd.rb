require 'osx/cocoa'
include OSX

OSX.require_framework('SystemConfiguration')

# rbmacadmin bindings for Apple's System Configuration Framework
# * http://developer.apple.com/mac/library/DOCUMENTATION/Networking/Reference/SCDynamicStore/Reference/reference.html
# * In some cases, Cocoa methods from the SC APIs have been simplified for general use, in others, the whole method has been abstracted.
# * The Ruby method names have been conformed to match those found in the orig. Cocoa methods, with the convention that they are all lowercase, dot-notated.
module SCFramework
  
  # Simple Error Class for DynamicStore methods
  # * Cocoa returns nil objects when they fail. We need to trap those sanely.
  class DynamicStoreErr < RuntimeError
    def self.ok?(result)
      return false if result.nil?        
      return result
    end
  end
  
  # DynamicStore Class Methods
  # * Cocoa SCDynamicStore Bindings
  # * These are primitive wrappers, but they should raise an exception if a nil object is returned.
  class DynamicStore

    # Create a new SCDynamicStore session
    # * Instantiates a session, the first step in getting any information from the Store
    # * Parameter 1 is an arbitrary name for the session
    # * Parameter 2 is variable pointing to a block or proc (optional)
    #   This callout is fired when one of the watched keys changes. The callout will pass the sesssion's name, an array containing the modified keys, and the SCDynamicStoreContext (always nil) into the function.
    def self.create(name, callout = nil)
      if session = DynamicStoreErr.ok?(SCDynamicStoreCreate(nil, name, callout, nil))
        return session
      else
        raise DynamicStoreErr.new("There was an error creating a session.")
      end        
    end
    
    # Get a list of keys matching regex
    # * Required parameters: a valid session name and a regular expression used to match keys
    # * Third parameter is optional: used to get a Ruby style object. Default is a RubyCocoa object.
    def self.copykeys(session, regex, *style)
      if result = DynamicStoreErr.ok?(SCDynamicStoreCopyKeyList(session, regex))
        DynamicStore.pretty?(result, style)
      else
        raise DynamicStoreErr.new("No match for key(s) query: #{regex}")
      end
    end

    # Get the value of a Store's key
    # * Required parameters: a valid session name and a named key from the Dynamic Store
    # * Third parameter is optional: used to get a Ruby style object. Default is a RubyCocoa object.
    def self.copyvalue(session, key, *style)
      if result = DynamicStoreErr.ok?(SCDynamicStoreCopyValue(session, key))
        DynamicStore.pretty?(result, style)
      else
        raise DynamicStoreErr.new("There was an getting value for: #{key}")
      end
    end
    
    # * Specifies a set of keys and key patterns that should be monitored for changes.
    # * This is an exact abstraction of the orig. Cocoa method, even the comments here are identical.
    # * Parameters
    #   session: The dynamic store session being watched.
    #   keys: An array of keys to be monitored or NULL if no specific keys are to be monitored.
    #   patterns: An array of regex pattern strings used to match keys to be monitored or NULL if no key patterns are to be monitored.
    def self.setnotificationkeys(session, keys = nil, patterns = nil)
      if result = DynamicStoreErr.ok?(SCDynamicStoreSetNotificationKeys(session, keys, patterns))
        return result
      else
        raise DynamicStoreErr.new("There was an error setting notification keys for the specified session.")
      end
    end
    
    # Creates a run loop source object that can be added to the application's run loop.
    # * This is a dumbing down of the orig. Cocoa object. See the relevant Cocoa docs for more info.
    def self.createrunloopsource(session)
      if result = DynamicStoreErr.ok?(SCDynamicStoreCreateRunLoopSource(nil, session, 0))
        return result
      else
        raise DynamicStoreErr.new("There was an error creating a runloop source object for the given session.")
      end
    end
    
    private
    
    # Common method to produce Ruby friendly objects
    def self.pretty?(result, *style)
      return result.to_ruby if style.to_s =~ /pretty|p|ruby/
      return result
    end

  end  

end

