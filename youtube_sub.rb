# Youtube_Sub.rb, a sweet ass-script to download new videos from your youtube subscription.
# Super useful for, say, Starcraft II videos where the resolutions are outrageous and
# Flash falls over, but Quicktime don't.
#
# This is based on work by Ionut Alex Chitu, at http://userscripts.org/scripts/show/25105
#
# Colin Curtin, colin.t.curtin@gmail.com, 12/2010
# Quick License That I Don't Want To Have To Type v.1
# Don't be a dick. This is free, you can do whatever you want with this software
# as long as you attribute it to me (Colin Curtin), and you keep this license here,
# right here, at the top. This probably won't work for whatever purpose you have
# in mind, but if it does, that'll make me happy. But if it breaks, don't come
# crying to me unless you're nice about it. Also, don't sue me.

require 'rubygems'
gem 'mechanize', '1.0.0'
gem 'json', '1.4.6'

require 'mechanize'
require 'json'
# require 'ruby-debug'
# Debugger.start

unless youtube_user = ARGV[0]
  puts "Missing youtube username. Usage: ruby youtube_sub.rb <username>"
  exit
end

FORMAT_LABELS={
  '5' => 'FLV 240p',
  '18' => 'MP4 360p',
  '22' => 'MP4 720p (HD)',
  '34' => 'FLV 360p',
  '35' => 'FLV 480p',
  '37' => 'MP4 1080p (HD)',
  '38' => 'MP4 Original (HD)',
  '43' => 'WebM 480p',
  '45' => 'WebM 720p (HD)'
};

EXTENSIONS = {[5,34,35] => 'flv', [18, 22, 37, 38] => 'mp4', [43, 45] => 'webm'}.inject({}) do |hash, (keys, val)|
  keys.each{|k| hash[k.to_s] = val}
  hash
end

a = Mechanize.new { |agent|
  agent.user_agent_alias = 'Mac Safari'
}

rss = a.get("http://gdata.youtube.com/feeds/base/users/#{youtube_user}/newsubscriptionvideos")
doc = Nokogiri.parse(rss.content)
entries = doc.search('entry').to_a

# Loop through the pages collecting entries. Let's do 3 pages.
next_link = doc.root.search('link[rel=next]').attr('href').value
3.times do |i|
  rss = a.get(next_link)
  doc = Nokogiri.parse(rss.content)
  entries += doc.search('entry').to_a
  next_link = doc.root.search('link[rel=next]').attr('href').value rescue nil
  break if next_link.nil?
end

entries.reverse.each do |entry|
  begin
    content = entry.search('content').inner_html
    _, youtube_watch, video_id = content.match(/href="(http:\/\/www.youtube.com\/watch\?v=([^&]+))/).to_a
    title = entry.search('title').inner_html
    author = entry.search('author name').inner_html
    published = Time.parse(entry.search('published').inner_text)
    
    if ENV['INTERACTIVE']
      puts "#{author} - #{title}?"
      case gets.chomp
      when 'n'
        next
      when 'd'
        debugger
      end
    end
  
    watch_page = a.get(youtube_watch)
    
    # Grab the urls form the watch page's JSON
    json = watch_page.search('script').select{|s| s.inner_html =~ /var swfConfig/}.first.inner_html[/var swfConfig = (\{.*\})/, 1]
    config = JSON.parse(json)
    video_ticket = config['args']['t']
    video_formats = config['args']['fmt_stream_map']
  
    formats = video_formats.split(',').inject({}) do |hash, group|
      id, url = group.split('|')
      hash[id] = CGI.unescape(url)
      hash
    end
    
    # We just want "nice" videos, in descending order of niceness
    url = formats.values_at('38', '37', '22', '18').compact.first ||
      raise("Couldn't find an acceptable format.")
    type = formats.invert[url]
    ext = EXTENSIONS[type]
    file_name = "#{author} - #{title}.#{ext}".gsub('/', '_')
    
    if File.exist?(file_name)
      puts "#{file_name} already exists."
    else
      command = "curl -L -D \"#{file_name}.txt\" -b \"#{a.cookies.map(&:to_s).join('; ')}\" \"#{url}\" > \"#{file_name}\""
      puts "Grabbing #{file_name} as #{FORMAT_LABELS[type]}\nlink: #{youtube_watch}\n"
  
      system(command)
      
      File.utime(Time.now, published, file_name)
    end
  rescue StandardError => se
    puts se.message
    retry
  end
end

