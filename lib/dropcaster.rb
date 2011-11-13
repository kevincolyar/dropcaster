$:.unshift File.dirname(__FILE__)

require 'bundler/setup'
require 'delegate'
require 'yaml'
require 'active_support/core_ext/date_time/conversions'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/module/attribute_accessors'
require 'erb'
require 'uri'
require 'mp3info'
require 'digest/sha1'
require 'redcarpet'

require 'logger'
require 'active_support/core_ext/logger'

require 'dropcaster/errors'
require 'dropcaster/log_formatter'
require 'dropcaster/hashkeys'
require 'dropcaster/channel'
require 'dropcaster/item'
require 'dropcaster/channel_file_locator'

module Dropcaster
  VERSION = File.read(File.join(File.dirname(__FILE__), *%w[.. VERSION]))
  CHANNEL_YML = 'channel.yml'
  STORAGE_UNITS = %w(Byte KB MB GB TB)
  
  mattr_accessor :logger
  
  unless @@logger
    @@logger = Logger.new(STDERR)
    @@logger.level = Logger::WARN
    @@logger.formatter = LogFormatter.new
  end
  
  #
  # Create a new ERB template from the given file path. Fall back to default if not found.
  #
  def Dropcaster.build_template(template_path, default_template)
    template = template_path || File.join(File.dirname(__FILE__), '..', 'templates', default_template)

    begin
      ERB.new(File.new(template), 0, "%<>")
    rescue Errno::ENOENT => e
      raise TemplateNotFoundError.new(e.message)
    end
  end

  # from http://stackoverflow.com/questions/4136248
  def Dropcaster.humanize_time(secs)
    [[60, :s], [60, :m], [24, :h], [1000, :d]].map{ |count, name|
      if secs > 0
        secs, n = secs.divmod(count)
        "#{n.to_i}#{name}"
      end
    }.compact.reverse.join(' ')
  end

  # Fixed version of https://gist.github.com/260184
  def Dropcaster.humanize_size(number)
    return nil if number.nil?

    storage_units_format = '%n %u'

    if number.to_i < 1024
      unit = number > 1 ? 'Bytes' : 'Byte'
      return storage_units_format.gsub(/%n/, number.to_i.to_s).gsub(/%u/, unit)
    else
      max_exp  = STORAGE_UNITS.size - 1
      number   = Float(number)
      exponent = (Math.log(number) / Math.log(1024)).to_i # Convert to base 1024
      exponent = max_exp if exponent > max_exp # we need this to avoid overflow for the highest unit
      number  /= 1024 ** exponent

      unit = STORAGE_UNITS[exponent]
      return storage_units_format.gsub(/%n/, number.to_i.to_s).gsub(/%u/, unit)
    end
  end
end
