#!/usr/bin/env ruby

# Author: Marco Cosentino
# License: GPLv3

THIS_FILE = File.expand_path( File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__ )
THIS_DIR = File.dirname(THIS_FILE)

# Ruby stdlib requires
require 'yaml'
require 'tempfile'

# Local requires
require THIS_DIR + '/configuration'
require THIS_DIR + '/cmdline_parser'
require THIS_DIR + '/slogger'
require THIS_DIR + '/ftp_helper'

# Ensure we have the needed gems
begin
   require 'rubygems'
   gem 'xml-simple'
rescue LoadError, NameError
   SLogger.fatal "Required gem not found: " + $!.to_s
   puts $!.to_s
   exit 1
end

module SCMDeploy

   class FileMissingError < StandardError; end

   #
   # Main program class. It manages the process.
   #
   class SCMDeploy
      def initialize(conf)
	 @conf = conf
	 case @conf.protocol
	 when :ftp
	    @connector = FTP.new
	 end
	 SLogger.info "Connecting to host '" + @conf.host + "'"
	 @connector.connect(@conf.host, @conf.username, @conf.password)
      end

      def finalize
	 @connector.disconnect
      end

      def process
	 case @conf.scm
	 when :svn
	    svn_process
	 else
	    raise StandardError.new "Unsupported SCM: " + @conf.scm.to_s
	 end
      end

      private

      def svn_process

	 SLogger.info "Starting SVN process."
	 # Lookup the current deployed version
	 SLogger.info "Looking up for deployed version..."
	 deployed_data = lookup_deployed_data
	 deployed_version = (deployed_data['version'] if deployed_data) || 1
	 SLogger.info "Deployed version: " + deployed_version.to_s

	 # State changes
	 SLogger.info "Issuing `svn -u status --xml`"
	 svnstatus_output = `svn -u status --xml`
	 xmldata = XmlSimple.xml_in(svnstatus_output,{'ForceArray' => false})
	 xmldata['target'].delete 'against'
	 xmldata['target'].delete 'path'

	 if xmldata['target'].count > 0
	    SLogger.info "The copy is not clean. Aborting."
	    puts "Please, update or commit your working copy. The status should be clean."
	    return
	 end

	 # Raise an update to be sure the copy is up to date
	 SLogger.info "Issuing `svn update`"
	 `svn update`

	 # Gathering version info
	 SLogger.info "Issuing `svn info --xml`"
	 svninfo_output = `svn info --xml`
	 
	 xmldata = XmlSimple.xml_in(svninfo_output,{ 'ForceArray' => false})
	 current_version = xmldata['entry']['revision']
	 SLogger.info "Current version: " + current_version

	 if current_version == deployed_version
	    puts "Deployed version is up to date."
	    return 0
	 end

	 cmd = "svn diff --summarize -r#{deployed_version}:#{current_version} --xml"
	 SLogger.info "Issuing `#{cmd}`"
	 svndiff_output = `#{cmd}`

	 parse_svn_diff(svndiff_output)

	 # Apply changes
	 # First: create new directories
	 @new_dirs.each {|d| mkdir(d) }
	 @new_files.each {|f| upload(f) if not @conf.ignorelist.include?(f)}
	 @mod_files.each {|f| upload(f) if not @conf.ignorelist.include?(f)}
	 @del_files.each {|f| remove(f) if not @conf.ignorelist.include?(f)}
	 @del_dirs.each {|d| rmdir(d) }

	 # Update deployed data file
	 update_deployed_data({'version' => current_version})

	 # Report results
	 puts "Done!"

      end

      def lookup_deployed_data
	 begin
	    YAML.load( @connector.read_file(@conf.remotepath + @conf.remote_filename) )
	 rescue FileMissingError
	    SLogger.info "File '"+@conf.remote_filename+"' not found in remote directory '"+@conf.remotepath+"'."
	    nil
	 rescue StandardError => bang
	    SLogger.error "Error while downloading file '" + @conf.remotepath + @conf.remote_filename + "': " + bang.to_s
	    nil
	 end
      end

      def update_deployed_data(data)
	 yaml_data = YAML.dump(data)

	 begin
	    @connector.write_file( @conf.remotepath + @conf.remote_filename, yaml_data )
	 rescue StandardError => bang
	    SLogger.error "Error while uploading file '" + @conf.remotepath + @conf.remote_filename + "': " + bang.to_s
	 end
      end

      # Parses svn diff --summarize data.
      # Returns 3 arrays with new files, modified files and deleted files.
      def parse_svn_diff(data)
	 @new_dirs = []
	 @new_files = []
	 @mod_files = []
	 @del_files = []
	 @del_dirs = []

	 xmldata = XmlSimple.xml_in(data,{ 'ForceArray' => false})

	 xmldata['paths'].each do |k,v|
	    if k == 'path'
	       v.each {|path| process_svn_path_entry(path)}
	    end
	 end
	 binding.pry
      end

      def process_svn_path_entry(path)
	 content = path['content']
	 case path['kind']
	 when 'file'
	    case path['item']
	    when 'modified'
	       @mod_files << content
	    when 'added'
	       @new_files << content
	    when 'deleted'
	       @del_files << content
	    end
	 when 'directory'
	    case path['item']
	    when 'added'
	       @new_dirs << content
	    when 'deleted'
	       @del_dirs << content
	    end
	 end
      end

      def upload(filename)
	 actn = "Uploading file '#{filename}' in '#{@conf.remotepath + filename}'"
	 puts actn
	 SLogger.info actn
	 begin
	    @connector.upload(filename, @conf.remotepath + filename)
	 rescue StandardError => bang
	    puts "ERROR. See logs."
	    SLogger.error "File '"+filename+"' not uploaded. Error: " + bang.to_s
	 end
      end

      def remove(filename)
	 actn = "Removing file " + filename
	 puts actn
	 SLogger.info actn
	 begin
	    @connector.delete(@conf.remotepath + filename)
	 rescue StandardError => bang
	    puts "ERROR. See logs."
	    SLogger.error "File '#{filename}' not deleted Error: " + bang.to_s
	 end
      end

      def mkdir(dir)
	 actn = "Creating directory " + dir
	 puts actn
	 SLogger.info actn
	 begin
	    @connector.mkdir(@conf.remotepath + dir)
	 rescue StandardError => bang
	    puts "ERROR. See logs."
	    SLogger.error "Directory '#{dir}' not created Error: " + bang.to_s
	 end
      end

      def rmdir(dir)
	 actn = "Removing directory " + dir
	 puts actn
	 SLogger.info actn
	 begin
	    @connector.rmdir(@conf.remotepath + dir)
	 rescue StandardError => bang
	    puts "ERROR. See logs."
	    SLogger.error "Directory '#{dir}' not removed Error: " + bang.to_s
	 end
      end
   end
end

# ##################################
# MAIN - The application entry point
# ##################################

require 'xmlsimple'
include SCMDeploy

conf = Configuration.new
parser = CommandlineParser.new

# Parse command line
parser.parse()
conf.config_filename = parser.config_filename || conf.config_filename

# Load config file
begin 
   conf.load_config 
rescue StandardError => bang
   SLogger.fatal "Exception caught while loading configuration file: " + bang
   exit 1
end

# Override loaded configuration with command line args
parser.push_params(conf)

# Create the definitive logger
SLogger.logfile = conf.logfile
SLogger.loglevel = conf.loglevel
SLogger.info "Definitive logger created."

# Report errors
begin

   svnd = SCMDeploy::SCMDeploy.new(conf)
   svnd.process

rescue StandardError => bang
   SLogger.fatal "Exception caught: " + bang
   exit 1
ensure
   svnd.finalize
end
