require 'osx/cocoa'
include OSX

# The Common Module
# * This module hosts of a variety of common non-specific operations
module Common
  
  include OSX
  OSX.require_framework('SystemConfiguration')
  
  # Applescript osascript wrapper
  # * A primitive method that enables execution of a simple AppleScript expression
  def osascript(*script)
    begin
      system('/usr/bin/osascript', '-e', script.join(" "))
    rescue Exception => e
      puts "Error: #{e}"
    end
  end  
  
  # Class methods for controlling Mac system volume
  class VolumeControl
    
    # Mutes the Mac OS system volume
    def self.mute
      begin
        osascript 'set volume output muted true'
      rescue Exception => e
        puts "Error: #{e}"
      end
    end

    # Un-mutes the Mac OS system volume    
    def self.unmute
      begin
        osascript 'set volume output muted false'
      rescue Exception => e
        puts "Error: #{e}"
      end
    end
    
    # Set the Mac OS system volume to level
    # * Accepts an integer argument of 0-7
    # * Level values less than 0 are interpreted as min. value
    # * Level values greater than 7 are interpreted as max. value
    def self.level(level)
      begin
        osascript('set volume', level)
      rescue Exception => e
        puts "Error: #{e}"
      end
    end
    
  end
  
  class OSX::NSDictionary
    objc_alias_class_method('load:', 'dictionaryWithContentsOfFile:')
    objc_alias_method('write:', 'writeToFile:atomically:')
  end

  class Plist < OSX::NSDictionary
    # Wee-iz ehm-tay
    # Wee-iz teh fake
  end
  
  class UUID < String
    
    # 897A6343-628F-4964-80F1-C86D0FFA3F91
    UUID = '([A-Z0-9]{8})-([A-Z0-9]{4}-){3}([A-Z0-9]{12})'
    
    def initialize()
      uuid = CFUUIDCreateString(nil, CFUUIDCreate(nil))
      return super(uuid)
    end
    
    def self.match(string, options = nil)
      string =~ Regexp.new(UUID, options) ? $& : false
    end
    
    def self.valid?(uuid, options = nil)
      strictlyuuid = '^' + UUID + '$'
      uuid =~ Regexp.new(strictlyuuid, options) ? true : false
    end
        
  end

  # Class describing methods that pertain to common Mac OS X console qureries and operations
  class Console
    
    # Returns a Ruby Struct describing users that are logged via the Mac OS X Console
    # * This list includes any users utilizing Fast User Switching
    # * Struct: user names (array), UID/GID/name of the current console user (array), num of users logged on (int), all info parsed from the Dynamic Store (hash)
    def self.get_users()
        consoleUsers = Struct.new(:names, :current_user, :total_users, :info)
        sc_dynstore_session_name = Proc.new { self.class.to_s + Common::UUID.new() }   # Defined as a Proc to guarantee unique id
        sc_dynstore_session = SCDynamicStoreCreate(nil, sc_dynstore_session_name.call, nil, nil)
        key = SCDynamicStoreKeyCreateConsoleUser(nil)
        dict = SCDynamicStoreCopyValue(sc_dynstore_session, key)
        current_user = dict.to_ruby.reject { |k,v| k =~ /SessionInfo/ }
        total_users = dict['SessionInfo'].to_ruby.size
        names = dict['SessionInfo'].to_ruby.collect { |x| x['kCGSSessionUserNameKey'] }
        consoleUsers.new(names, current_user, total_users, dict.to_ruby)
    end
    
  end
  
end
