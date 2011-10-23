# Author: Marco Cosentino
# License: GPLv3


# Ruby stdlib requires
require 'net/ftp'

module SCMDeploy

   # Define a common interface to remote file handling
   # The connection is held as a state variable
   class FTP
      # Starts a connection 
      def connect(host,username,password)
	 @connection = Net::FTP.new(host, username, password)
      end

      # Closes the connection
      def disconnect
	 @connection.close if @connection
      end

      def read_file(path)
	 buffer = ""
	 begin
	    @connection.gettextfile(path,"/dev/null") {|line| buffer += line + "\n"}
	 rescue Net::FTPPermError => bang
	    if bang.to_s.start_with?("550")
	       raise FileMissingError, bang
	    else
	       raise bang
	    end
	 end
	 buffer
      end

      def write_file(path,content)
	 tempfile = Tempfile.new('scmdeploy')
	 SLogger.debug "Created temp file '" + tempfile.path + "'"
	 tempfile.print content
	 tempfile.close

	 @connection.puttextfile(tempfile.path, path)
      end

      def upload(local,remote)
	 @connection.putbinaryfile(local, remote)
      end

      def remove(remote)
	 @connection.delete(remote)
      end

      def mkdir(remote)
	 @connection.mkdir(remote)
      end

      def rmdir(remote)
	 @connection.rmdir(remote)
      end
   end
end
