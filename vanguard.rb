require 'nokogiri'
require 'rest-client'
require 'fileutils'

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
end

def parseFileList(nokogiri)
    output=[]#Getting rid of any data in output from before this ...
    nokogiri.xpath("/manifest/filelist/file").each{|f|
        output.push(File_dl.new)
        output[-1].location=f.xpath("@name").to_s
        output[-1].md5=f.xpath("@md5").to_s
        f.xpath("url/text()").each{|u|
            output[-1].urls.push(u.to_s)
        }
    }
    return output
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
        download_file(b.urls,"#{host_name}/#{b.location}", b.md5)
    }
    launch_options=noko_xml.xpath("/manifest/profiles/launch")
    #for the sake of sanity we are going to just autolaunch the first one
    exec("wine \"./#{host_name}/#{launch_options[0].xpath("@exec").to_s}\" #{launch_options[0].xpath("@params").to_s}")
end