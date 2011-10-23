require 'optparse'

class CommandlineParser

   def parse()
      @options = {}
      OptionParser.new do |opts|
	 opts.banner = "Usage: svndeploy.rb [options]"

#	 opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
#	    @options[:verbose] = v
#	 end
	 #
	 opts.on("-c CONNSTRING", "--connect CONNSTRING", "Specify the connection string. Format is user@host:port") do |cstr|
	    @options[:connstring] = cstr
	 end

	 opts.on("-s SCM", "--scm SCM", "Specify the Source Control Management system. Subversion: svn, Git: git") do |scm|
	    @options[:scm] = scm
	 end

	 opts.on("-p PASSWORD", "--password PASSWORD", "Specify the password") do |pwd|
	    @options[:password] = pwd
	 end


	 opts.on("-r PATH", "--remote-file PATH", "Use an alternative remote info storage file. Default is \".scmdeploy.yaml\"") do |file|
	    @options[:remote_filename] = file
	 end

	 opts.on("-f PATH", "--config-file PATH", "Use an alternative configuration file. Default is \".scmdfile\"") do |file|
	    @options[:config_filename] = file
	 end

	 opts.on("-h", "--help", "Prints help") do
	    puts opts
	    exit
	 end
      end.parse!
   end

   def push_params(conf)
      conf.scm = @options[:scm] if @options[:scm]
      conf.protocol = @options[:protocol] if @options[:protocol]
      conf.connstring = @options[:connstring] if @options[:connstring]
      conf.password = @options[:password] if @options[:password]
      conf.remote_filename = @options[:remote_filename] if @options[:remote_filename]
   end

   def config_filename
      @options[:config_filename]
   end

end
