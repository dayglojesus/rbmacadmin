require 'osx/cocoa'
require 'pp'
require 'ping'
require 'rbmacadmin/common'
require 'rbmacadmin/scframework'
require 'timeout'

include Common
include SCFramework

#####################################
# Module: Network
#####################################

# Defines a mix of classes and methods developed against Cocoa APIs
# * All of the calls to NSHost have been wrapped in the Ruby Standard Library's 'timeout' to prevent excessive blocking.
module Network

  include OSX
  OSX.require_framework('SystemConfiguration')

  #####################################
  # Collective Methods
  #####################################
  
  # Simple Reverse DNS query
  # * Given address, retrieve hostname
  # * Two args: IP Address, and optional timeout. Default is 7 seconds.
  def get_hostname_with_address(target, timeout=7)
    timeout(timeout) {
      begin
        host = NSHost.hostWithAddress(target)
        return host.name.to_ruby unless host.nil? or host.name.nil?
        raise ArgumentError.new("Invalid IP Address: #{target}")
      rescue Timeout::Error
        false
      end
    }
    false
  end

  # Simple Forward DNS query
  # * Given hostname, retrieve address
  # * Two args: Hostname, and optional timeout. Default is 7 seconds.
  def get_address_with_hostname(target, timeout=7)
    timeout(timeout) {
      begin
        host = NSHost.hostWithName(target)
        return host.address.to_ruby unless host.nil? or host.address.nil?
        raise ArgumentError.new("Invalid Hostname: #{target}")
      rescue Timeout::Error
        false
      end
    }
    false
  end

  # Key: State:/Network/Global/SMB
  def my_netbiosname
    
  end    

  # Simple primary IP Address for your host
  # * If you have mutiple IPs, this method will not return them
  def my_ipaddress(timeout=7)
    timeout(timeout) {
      begin
        host = NSHost.currentHost
        return host.address.to_ruby unless host.nil? or host.address.nil?
        raise
      rescue Timeout::Error
        false
      end
    }
    false    
  end

  # Simple primary FQDN query for your host
  def my_hostname(timeout=7)
    timeout(timeout) {
      begin
        host = NSHost.currentHost
        return host.name.to_ruby unless host.nil? or host.name.nil?
        raise
      rescue Timeout::Error
        false
      end
    }
    false    
  end

  # Simple primary mDNS name query for your host
  # * This method returns the value of the name set in the Sharing Preferences pane
  def my_bonjourname(timeout=7)
    timeout(timeout) {
      begin
        host = NSHost.currentHost
        return host.localizedName.to_ruby unless host.nil? or host.localizedName.nil?
        raise
      rescue Timeout::Error
        false
      end
    }
    false        
  end

  class InterfaceErr < StandardError
  end
  
  #####################################
  # Class: Interface
  #####################################
  
  # Defines a Network Interface (NI) Ruby Struct type object replete with info about said device
  # * This class is meant to be one-stop shopping for information about a given Mac OS X NIC
  # * The Struct contains Ruby Hash objects which vary in structure but share common traits with their Cocoa object counterparts.
  #   In most cases, this class will contain Cocoa typed objects (ie. NSArray), but sometimes these values may actually be Ruby objects. There is never any purposeful type casting done, so whatever is returned by the Cocoa method is used. We get most of our information from the Setup Domain using SCPreferences. What we cannot derive from there, we gather from the DynamicStore (KSCDynamicStoreDomainState) using SCDynamicStore methods.
  # * Public Class methods are constructors based on common names of devices (ie. "Ethernet", "Airport" or "en1")
  # * Public Instance methods presently define easy ways of extracting data from the object.
  # * At present, no write methods for augmenting device paramteres are implemented.
  class Interface < 

    Struct.new(:names, :hardware, :ipv4_config, :ipv6_config, :dns_config, :dhcp_config)
    
    ERR_NO_SUCH_DEVICE  = 'No such device'
    ERR_NO_SUCH_VALUE   = 'No such value'
    
    @sc_prefs_session_name      = Proc.new { self.class.to_s + UUID.new() }   # Defined as a Proc to guarantee unique id
    @sc_dynstore_session_name   = @sc_prefs_session_name                      # Defined as a Proc to guarantee unique id
    @sc_prefs_session           = SCPreferencesCreate(nil, @sc_prefs_session_name.call, nil)
    @current_set_ref            = SCNetworkSetCopyCurrent(@sc_prefs_session)
    @current_set_services_refs  = SCNetworkSetCopyServices(@current_set_ref)

    #####################################
    # PUBLIC CLASS METHODS
    #####################################
    
    # Low-level Interface constrcutor    
    # * Raw method for constructing a NI object
    # * NetworkInterface.new() can be called to construct raw objects, but it is better to utilize the higher level constuctors
    def initialize(*args)
      unless args.length.eql?(self.members.length)
        raise ArgumentError.new("Wrong number of arguments (#{args.length} for #{self.members.length})")
      end
      args.each do |ivar|
        unless ivar.respond_to?(:each_key)
          raise TypeError.new("Expected type Hash, but got type: #{ivar.class} (#{ivar})")
        end
      end
      super(*args)
    end
    
    # High-level Interface constrcutor
    # * Returns a NI object based on the primary global IPv4 state
    # * Whichever interface is the primary IPv4 entity, is the source
    def self.get_interface_primary_ipv4()
      key = SCDynamicStoreKeyCreateNetworkGlobalEntity(nil, KSCDynamicStoreDomainState, KSCEntNetIPv4)
      sc_dynstore_session = SCDynamicStoreCreate(nil, @sc_dynstore_session_name.call, nil, nil)
      state = SCDynamicStoreCopyValue(sc_dynstore_session, key)
      primary_service_id = state[KSCDynamicStorePropNetPrimaryService]
      self.get_interface_by_service_id(primary_service_id.to_ruby)
    end

    # High-level Interface constrcutor    
    # * Returns an NI object based on a service's GUID
    # * Example: "3A2E92F6-DC14-47DF-BCD8-A51EF2B37A62"
    def self.get_interface_by_service_id(name)
      @current_set_services_refs.each do |service_ref|
        service_id = SCNetworkServiceGetServiceID(service_ref)
        if service_id.to_ruby.eql?(name)
          interface = interface_constructor(service_ref)
          return self.new(*interface)
        end
      end
      raise InterfaceErr.new(ERR_NO_SUCH_DEVICE + ": #{name}")
    end
    
    # High-level Interface constrcutor
    # * Returns an NI object based on a BSD style device name
    # * Example: "en0"
    def self.get_interface_by_bsd_name(name)
      @current_set_services_refs.each do |service_ref|
        iface_ref = SCNetworkServiceGetInterface(service_ref)
        bsd_name = SCNetworkInterfaceGetBSDName(iface_ref)
        unless bsd_name.nil?
          if bsd_name.to_ruby.eql?(name)
            interface = interface_constructor(service_ref)
            return self.new(*interface)
          end
        end
      end
      raise InterfaceErr.new(ERR_NO_SUCH_DEVICE + ": #{name}")
    end
    
    # High-level Interface constrcutor
    # * Returns an NI object based on Mac OS X User Defined name
    # * The User Defined Name, is the name used to identify a device in the Mac OS X "Network Preference" System Preferences pane.
    # * Example: "Ethernet 1"
    def self.get_interface_by_user_defined_name(name)
      @current_set_services_refs.each do |service_ref|
        user_defined_name = SCNetworkServiceGetName(service_ref) 
        if user_defined_name.to_ruby.eql?(name)
          interface = interface_constructor(service_ref)
          return self.new(*interface)
        end
      end
      raise InterfaceErr.new(ERR_NO_SUCH_DEVICE + ": #{name}")
    end
    
    #####################################
    # PUBLIC INSTANCE METHODS
    #####################################
    
    # Returns the device's primary IPv4 IP Address
    def get_ipv4_address
      self.ipv4_config[:addresses][0]
      rescue
        raise InterfaceErr.new("#{scf_error_caller_id(0)} returned: " + ERR_NO_SUCH_VALUE)
    end
    alias :ipaddr :get_ipv4_address

    # Returns the device's hardware MAC address
    def get_hardware_address
      self.hardware[:address]
      rescue
        raise InterfaceErr.new("#{scf_error_caller_id(0)} returned: " + ERR_NO_SUCH_VALUE)
    end
    alias :macaddr :get_hardware_address

    # Returns the device's DHCP lease start time
    def get_dhcp_lease_start_time
      DHCPInfoGetLeaseStartTime(dhcp_config[:config]).to_ruby
      rescue
        raise InterfaceErr.new("#{scf_error_caller_id(0)} returned: " + ERR_NO_SUCH_VALUE)
    end
    alias :dhcplease :get_dhcp_lease_start_time
        
    private
    #####################################
    # PRIVATE CLASS METHODS
    #####################################
    
    # Constructs a list of synonyms for the device in question
    def self.get_names(service_ref)
      names = Hash.new()
      iface_ref = SCNetworkServiceGetInterface(service_ref)
      names[:user_defined_name] = SCNetworkServiceGetName(service_ref)
      names[:service_id_str]    = SCNetworkServiceGetServiceID(service_ref)
      names[:bsd_name]          = SCNetworkInterfaceGetBSDName(iface_ref)
      names
    end
    
    # Constructs a list of hardware configuration information
    def self.get_hardware(service_ref)
      hardware = Hash.new()
      iface_ref = SCNetworkServiceGetInterface(service_ref)
      hardware[:enabled]        = SCNetworkServiceGetEnabled(service_ref)
      hardware[:address]        = SCNetworkInterfaceGetHardwareAddressString(iface_ref)
      hardware[:type]           = SCNetworkInterfaceGetInterfaceType(iface_ref)
      hardware[:configuration]  = SCNetworkInterfaceGetConfiguration(iface_ref)
      hardware
    end
    
    # Compiles information pertaining to the device's IPv4 config
    # * Most information is derived from KSCDynamicStoreDomainSetup
    #   In special cases where only "KSCDynamicStoreDomainState" information can be used to determine the true state of a device, we look for that. 
    #   An example of this would be when most of the interesting information about a device gets handed off via DHCP.
    def self.get_ipv4_config(service_ref, sc_dynstore_session, service_id_str)
      ipv4_config = Hash.new()
      domain = KSCDynamicStoreDomainSetup
      begin
        protocol_ref = SCNetworkServiceCopyProtocol(service_ref, KSCEntNetIPv4)
        SCFError.check(protocol_ref)
        ipv4_config[:config_method] = SCNetworkProtocolGetConfiguration(protocol_ref)[KSCPropNetIPv4ConfigMethod]
        unless ipv4_config[:config_method].to_ruby.eql?(KSCValNetIPv4ConfigMethodManual.to_ruby)
          domain = KSCDynamicStoreDomainState
        end
        key = SCDynamicStoreKeyCreateNetworkServiceEntity(nil, domain, service_id_str, KSCEntNetIPv4)
        values = SCDynamicStoreCopyValue(sc_dynstore_session, key)
        SCFError.check(values)
      rescue
        return ipv4_config
      end
      ipv4_config[:addresses]     = values[KSCPropNetIPv4Addresses]
      ipv4_config[:subnet_masks]  = values[KSCPropNetIPv4SubnetMasks]
      ipv4_config[:router]        = values[KSCPropNetIPv4Router]
      ipv4_config
    end

    # Compiles information pertaining to the device's IPv6 config
    # * This method is largely untested, and in environs where IPv6 is not configured or enabled, this method will return an empty Hash. You can expect warnings about this condition, if you are checking the SCFError accumulator.
    # * Most information is derived from KSCDynamicStoreDomainSetup
    #   In special cases where only "KSCDynamicStoreDomainState" information can be used to determine the true state of a device, we look for that. 
    #   An example of this would be when most of the interesting information about a device gets handed off via DHCP.
    def self.get_ipv6_config(service_ref, sc_dynstore_session, service_id_str)
      ipv6_config = Hash.new()
      domain = KSCDynamicStoreDomainSetup
      begin
        protocol_ref = SCNetworkServiceCopyProtocol(service_ref, KSCEntNetIPv6)
        SCFError.check(protocol_ref)
        ipv6_config[:config_method] = SCNetworkProtocolGetConfiguration(protocol_ref)[KSCPropNetIPv6ConfigMethod]
        unless ipv6_config[:config_method].to_ruby.eql?(KSCValNetIPv6ConfigMethodManual.to_ruby)
          domain = KSCDynamicStoreDomainState
        end
        key = SCDynamicStoreKeyCreateNetworkServiceEntity(nil, domain, service_id_str, KSCEntNetIPv6)
        values = SCDynamicStoreCopyValue(sc_dynstore_session, key)
        SCFError.check(values)
      rescue
        return ipv6_config
      end
      ipv6_config[:addresses]     = values[KSCPropNetIPv6Addresses]
      ipv6_config[:router]        = values[KSCPropNetIPv6Router]
      ipv6_config
    end

    # Compiles information pertaining to the device's DNS config
    # * Most information is derived from KSCDynamicStoreDomainSetup
    #   In special cases where only "KSCDynamicStoreDomainState" information can be used to determine the true state of a device, we look for that. 
    #   An example of this would be when most of the interesting information about a device gets handed off via DHCP.
    def self.get_dns_config(service_ref, sc_dynstore_session)
      dns_config = Hash.new()
      begin
        protocol_ref = SCNetworkServiceCopyProtocol(service_ref, KSCEntNetDNS)
        SCFError.check(protocol_ref)
        values = SCNetworkProtocolGetConfiguration(protocol_ref)
        if values.nil?
          key = SCDynamicStoreKeyCreateNetworkGlobalEntity(nil, KSCDynamicStoreDomainState, KSCEntNetDNS)
          values = SCDynamicStoreCopyValue(sc_dynstore_session, key)
          SCFError.check(values)
        end
      rescue
        return dns_config
      end
      dns_config[:server_addresses] = values[KSCPropNetDNSServerAddresses]
      dns_config[:search_domains]   = values[KSCPropNetDNSSearchDomains]
      dns_config
    end
    
    # Extracts and returns info about the DHCP options if info is available
    # * Mostly used for returning the DHCP lease
    def self.get_dhcp_config(sc_dynstore_session)
      dhcp_config = Hash.new()
      dhcp_config[:config] = SCDynamicStoreCopyDHCPInfo(sc_dynstore_session, nil)
      dhcp_config
    end

    # Constructor method that prepares the arguments before the Struct is instantianted
    # * Parameter is an SCNetworkServiceRef Cocoa type
    def self.interface_constructor(service_ref)
      iface = Array.new()
      sc_dynstore_session = SCDynamicStoreCreate(nil, @sc_dynstore_session_name.call, nil, nil)
      SCFError.check(sc_dynstore_session)      
      names       = self.get_names(service_ref)
      hardware    = self.get_hardware(service_ref)
      ipv4_config = self.get_ipv4_config(service_ref, sc_dynstore_session, names[:service_id_str])
      ipv6_config = self.get_ipv6_config(service_ref, sc_dynstore_session, names[:service_id_str])
      dns_config  = self.get_dns_config(service_ref, sc_dynstore_session)
      dhcp_config = self.get_dhcp_config(sc_dynstore_session)
      sc_dynstore_session = nil
      iface = [names, hardware, ipv4_config, ipv6_config, dns_config, dhcp_config]
    end
    
  end

  #####################################
  # Class: Test
  #####################################
  
  class Test
    
    # Performs a simple DNS query to check and see if we can resolve a hostname (Reverse)
    # * Arguments are optional: hostname ( A String, default: "www.google.com") and timeout (An Integer, default: 7 seconds)
    # * Returns Boolean
    def self.dnsok_by_name?(target='www.google.com', timeout=7)
      return true unless get_address_with_hostname(target, timeout).eql?(false)
      false
    end

    # Performs a simple DNS query to check and see if we can resolve a address (Forward)
    # * timeout argument is optional. See Test::dnsok_by_name? for more info
    # * Returns Boolean
    def self.dnsok_by_address?(target, timeout=7)
      return true unless get_hostname_with_address(target, timeout).eql?(false)
      false
    end
    
    # Performs a TCP ping against the specified target
    # * Uses the Ruby Std. Library 'ping'
    # * This is not an ICMP ping. Performs a TCP Connect to speficied port to try and determine the hsot's state.
    # * Arguments optional
    # * defaults: target='www.google.com', timeout=10, service=80
    # * Returns Boolean
    def self.host_reachable?(target='www.google.com', timeout=10, service=80)
      Ping.pingecho(target, timeout, service)
    end
  
    # Compares the DNS suffix of the provided domain argument agaist the DNS suffix of the current host
    # * Returns Boolean
    def self.on_home_network?(domain, timeout=7)
      host, suffix = my_hostname(timeout).split(/\./, 2)
      suffix.include? domain
    end
    
  end

end




