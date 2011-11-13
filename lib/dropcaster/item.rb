module Dropcaster
  class Item < DelegateClass(Hash)
    include ERB::Util # for h() in the ERB template
    include HashKeys

    def initialize(channel, file_path, options = nil)
      super(Hash.new)
      self.channel = channel # item belongs_to channel

      Mp3Info.open(file_path){|mp3info|
        self[:file_name] = Pathname.new(File.expand_path(file_path)).relative_path_from(Pathname.new(Dir.pwd)).cleanpath.to_s
        self[:tag] = mp3info.tag
        self[:tag2] = mp3info.tag2
        self[:duration] = mp3info.length
      }
    
      self.page_file_name = self.file_name.chomp(File.extname(self.file_name)) << ".html"

      self[:file_size] = File.new(self.file_name).stat.size
      self[:uuid] = Digest::SHA1.hexdigest(File.read(self.file_name))

      unless self.tag2.TDR.blank?
        self[:pub_date] = DateTime.parse(self.tag2.TDR)
      else
        Dropcaster.logger.info("#{file_path} has no pub date set, using the file's modification time")
        self[:pub_date] = DateTime.parse(File.new(self.file_name).mtime.to_s)
      end

      # Remove iTunes normalization crap (if configured)
      if options && options[:strip_itunes_private]
        Dropcaster.logger.info("Removing iTunes' private normalization information from comments")
        self.tag2.COM.delete_if{|comment|
          comment =~ /^( [0-9A-F]{8}){10}$/
        }
      end

      # Convert lyrics frame into a hash, keyed by the three-letter language code
      self.lyrics = Hash.new
      unless tag2.ULT.blank?
        lyrics_parts = tag2.ULT.split(0.chr) # Split lyrics as they are separated by null characters. TODO This should be parsed by the ID3 parser, not us.

        if lyrics_parts && 3 == lyrics_parts.size
          self.lyrics[lyrics_parts[1]] = Redcarpet.new(lyrics_parts[2]).to_html
        end
      end
      
      @episode_erb_template = Dropcaster.build_template(options[:episode_template], 'episode.html.erb')
    end
    
    def to_html
      @episode_erb_template.result(binding)
    end
  end
end
