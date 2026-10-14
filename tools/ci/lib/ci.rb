#===============================================================================
# Shared helpers for the CI checks (run with plain Ruby, outside the game).
#===============================================================================
ROOT = File.expand_path("../../..", __dir__)

module CI
  module_function

  def errors
    @errors ||= []
  end

  # Records one problem. On GitHub Actions it also becomes an annotation on
  # the file in the PR diff.
  def error(file, line, message)
    file = file.sub("#{ROOT}/", "")
    errors.push([file, line, message])
    if ENV["GITHUB_ACTIONS"]
      puts "::error file=#{file}#{line ? ",line=#{line}" : ''}::#{message}"
    else
      puts "#{file}#{line ? ":#{line}" : ''}: #{message}"
    end
  end

  # Prints the summary and exits with 1 when anything was reported.
  def finish(name)
    if errors.empty?
      puts "#{name} : OK"
      exit 0
    end
    puts "#{name} : #{errors.length} erreur(s)"
    exit 1
  end

  def read_text(path)
    return File.read(path, encoding: "UTF-8").sub(/\A﻿/, "")
  end
end

#===============================================================================
# Minimal RGSS classes so Marshal can load Data/*.rxdata.
#===============================================================================
class Table
  attr_reader :xsize, :ysize, :zsize

  def self._load(data)
    table = allocate
    _dim, x, y, z, _size = data.unpack("V5")
    table.instance_variable_set(:@xsize, x)
    table.instance_variable_set(:@ysize, y)
    table.instance_variable_set(:@zsize, z)
    return table
  end
end

class Color
  def self._load(_data) = allocate
end

class Tone
  def self._load(_data) = allocate
end

module RPG
  class MapInfo
    attr_accessor :name, :parent_id
  end

  class Tileset
    attr_accessor :id, :name, :tileset_name, :autotile_names, :passages
  end
end

# Loads a .rxdata file, creating empty classes for any other RPG:: type met.
def load_rxdata(path)
  File.open(path, "rb") { |f| return Marshal.load(f) }
rescue ArgumentError => e
  raise unless e.message =~ /undefined class\/module RPG::(\S+)/
  parent = RPG
  $1.split("::").each do |name|
    parent.const_set(name, Class.new) unless parent.const_defined?(name, false)
    parent = parent.const_get(name, false)
  end
  retry
end
