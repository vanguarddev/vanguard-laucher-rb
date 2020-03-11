require 'nokogiri'
require 'rest-client'
require 'fileutils'
class Launcher_Options
    def initialize
        @name=""
        @exec=""
        @order=-1
        @params=""
        @architecture=""
    end
    def name
        return @name
    end
    def exec
        return @exec
    end
    def order
        return @order
    end
    def params
        return @params
    end
    def architecture
        return @architecture
    end
    def name=(new_n)
        @name=new_n
    end
    def exec=(new_e)
        @exec=new_e
    end
    def order=(new_o)
        @order=new_o
    end
    def params=(new_p)
        @params=new_p
    end
    def architecture=(new_a)
        @architecture=new_a
    end
    def execute_string
        return "#{@exec} #{@params}"
    end
    class << self
        def from_nokogiri(noko_node)
            returner=Launcher_Options.new
            returner.exec=noko_node.xpath("@exec").to_s
            returner.order=noko_node.xpath("@order").to_s.to_i
            returner.params=noko_node.xpath("@params").to_s
            returner.architecture=noko_node.xpath("@architecture").to_s
            returner.name=noko_node.xpath("text()").to_s
            return returner
        end
    end
end
class File_dl
    def initialize
        @location=""
        @md5=""
        @urls=[]
    end
    def location
        @location
    end
    def md5
        @md5
    end
    def urls
        @urls
    end
    def location=(new_l)
        @location=new_l
    end
    def md5=(new_m)
        @md5=new_m
    end
    def urls=(new_u)
        @urls=new_u
    end
    def to_json()
        returner="\{\n\t\"location\"\: \"#{location},\"\n\t\"URLs\"\:\[\n"
        urls.each{|u| returner+="\t\t\"#{u}\",\n"}
        returner=returner[0..-3]#Hacky way of getting rid of that last character... a bit dumb, but it's hacky for a reason
        returner+="\n\t\]\n\t\"md5\"\:\"#{md5}\"\n\}"
    end
    def to_toml()
        # returner= "\[\[file\]\]\n"
        # returner+="name = \"#{@location}\"\n"
        # returner+="url  = \[#{urls.each{|u| '"'+u+'"'}\]\n"
        # retruner+="md5  = \"#{@md5}\"\n"
        return returner
    end
    class << self
        def from_nokogiri(noko_node)
            returner=File_dl.new
            returner.location=noko_node.xpath("@name").to_s
            returner.md5=noko_node.xpath("@md5").to_s
            noko_node.xpath("url/text()").each{|u| returner.urls.push(u.to_s.split(/\s/)[0])}
            return returner
        end
    end
end

def parseFileList(nokogiri)
    returner=[]
    nokogiri.xpath("/manifest/filelist/file").each{|f|
        returner.push(File_dl.from_nokogiri(f))
    }
    return returner
end
def parseLaunchers(nokogiri)
    returner=[]
    nokogiri.xpath("/manifest/profiles/launch").each {|l|
        returner.push(Launcher_Options.from_nokogiri(l))
    }
    return returner
end
def download_file(file_uris, file_name, md5)
    dirs=file_name.split('/')[0..-2].join('/')
    unless(dirs.length==0)
        FileUtils.makedirs dirs
    end
    unless(File.exist?(file_name) && Digest::MD5.hexdigest(File.read(file_name))==md5)
        puts "\t\tDownloading #{file_name}"
        raw=""
        file_uris.each do |file_uri|
            begin
                raw = RestClient::Request.execute(
                    method: :get, 
                    url: file_uri,
                    raw_response: true)
                break if(Digest::MD5.hexdigest(File.read(raw.file))==md5)
            rescue RestClient::NotFound => e
            rescue SocketError => e
            rescue RestClient::Forbidden => e
            end
        end
        FileUtils.mv(raw.file.path, "./#{file_name}")
        File.chmod(0774, "./#{file_name}")
    end
end

if(__FILE__==$0)
    url=ARGV[0]
    url="http://patch.savecoh.com/manifest.xml" if(url.nil?)
    host_name=URI.parse(url).host
    xml_text=RestClient.get(url).body
    noko_xml=Nokogiri::XML.parse(xml_text)
    boop=parseFileList(noko_xml)
    puts FileUtils.pwd()
    boop.each{|b|
        #puts b.to_json
        puts b.urls
        puts host_name
        puts b.location
        download_file(b.urls,"#{host_name}/#{b.location}", b.md5)
    }
    launch_options=noko_xml.xpath("/manifest/profiles/launch")
    #for the sake of sanity we are going to just autolaunch the first one
    launch="\"./#{host_name}/#{launch_options[0].xpath("@exec").to_s}\" #{launch_options[0].xpath("@params").to_s}"
    if ((/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil)
        exec(launch)
    else
        exec("wine #{launch}")
    end
end