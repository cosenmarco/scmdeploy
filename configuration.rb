require 'logger'
module SCMDeploy

   class Configuration

      attr_accessor :remote_filename, :config_filename, :logfile, :loglevel, :protocol, :connstring, :password, :remotepath, :host, :port, :username, :ignorelist, :scm

      def initialize
	 @config_filename = "scmdfile"
	 @remote_filename = ".scmdeploy.yaml"
	 @logfile = STDOUT
	 @loglevel = Logger::INFO
      end

      # if connstring is spcified, it takes the precedence over single paramters host, username and password
      def load_config
	 raise ("Unable to find " + @config_filename) unless File.file?(@config_filename) 
	 raise ("Unable to read " + @config_filename) unless File.readable?(@config_filename)

	 instance_eval File.read(@config_filename)

	 if @connstring
	    if @connstring =~ %r{((.*)@)?(.*)(:(\d+))?}
	       @username, @host, @port = $2,$3,$5
	       @port ||= case @protocol
			 when :ftp  then 21
			 when :sftp then 22
			 else nil
			 end
	    else
	       raise "Connection string '" + @connstring + "' is wrong. The format is: \"username@host:port\""
	    end
	 end

	 # Adjust tailing slash
	 (@remotepath += "/") unless @remotepath =~ %r{/$}
      end

   end
end
