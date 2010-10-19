require 'osx/cocoa'
require 'rbmacadmin/common'
require 'etc'
require 'tempfile'


include OSX

class User
  
  DSCL = '/usr/bin/dscl'
  DSEDITGROUP = '/usr/sbin/dseditgroup'
  @plist
  
  @account = [:AppleMetaNodeLocation, :AuthenticationAuthority, :GeneratedUID, :JPEGPhoto, :NFSHomeDirectory, :Picture, :PrimaryGroupID, :RealName, :RecordName, :UniqueID, :UserShell]
  
  # Not a great way to do UID to username translation, but its quick.
  def self.by_uid(uid)
    name = Etc.getpwuid(uid).name
    self.by_name(name)
  end

  def self.by_username(name)
    @name = name
    account = `DSCL -plist /Search -read /Users/#{name}`
    if $? == 0
      file = Tempfile.new('account')
      file.puts account
      file.close
      @plist = Plist.load(file.path)
      self.parse(@plist)
    else
      raise "#{DSCL} exited: #{$?}"
    end
  end
  
  def self.parse(plist)
    plist = plist.to_ruby
    x = self.new
    plist.each do |k,v|
      if k =~ Regexp.new(/^dsAttrTypeStandard:.*/)
      key = k.gsub(/dsAttrTypeStandard:/, "")
      x.instance_variable_set("@#{key}", v)
      end
    end
    return x
  end
  
  def self.is_admin?(name)
    answer = `#{DSEDITGROUP} -q -o checkmember -m #{name} admin`
    if $? != 0
      raise "#{DSEDITGROUP} exited: #{$?}"
    else
      true
    end
  end
    
  # Instance Methods
  def is_admin?
    is_admin?("#{@name}")
  end
  
  def is_member_of?(group)
    
  end
  
  def save_plist(path)
    
  end
  
  def create_user_home(template='/System/Library/User Template/English.lproj')

  end
  
  def write(path)
    super("#{path}/#{@name}", 1)
  end

end

require 'pp'
# x = User.by_uid(0)
x = User.by_username('bcw')
# puts x.class
# puts User.is_admin?('jraine')
# x.is_admin?
# x.write('/Users/Shared/bcw.plist', 1)
# pp x
pp x