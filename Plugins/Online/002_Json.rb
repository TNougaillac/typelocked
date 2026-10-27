#===============================================================================
# Online - JSON
# The bridge speaks JSON; the game's Ruby has no json library. Enough for
# objects, arrays, strings, numbers, true, false and null.
#===============================================================================
module Online
  module Json
    module_function

    def dump(value)
      case value
      when Hash   then "{" + value.map { |k, v| "#{dump(k.to_s)}:#{dump(v)}" }.join(",") + "}"
      when Array  then "[" + value.map { |v| dump(v) }.join(",") + "]"
      when String then dump_string(value)
      when Symbol then dump_string(value.to_s)
      when nil    then "null"
      when true, false, Integer then value.to_s
      when Float  then value.finite? ? value.to_s : "null"
      else raise ArgumentError, "JSON : #{value.class} non pris en charge"
      end
    end

    def dump_string(str)
      escaped = str.gsub(/["\\\u0000-\u001f]/) do |c|
        { '"' => '\\"', "\\" => "\\\\", "\n" => "\\n", "\r" => "\\r", "\t" => "\\t" }[c] || format("\\u%04x", c.ord)
      end
      return "\"#{escaped}\""
    end

    # The value, or nil when text is not valid JSON.
    def parse(text)
      @text = text.to_s
      @pos = 0
      value = read_value
      skip_space
      return @pos == @text.length ? value : nil
    rescue ArgumentError
      return nil
    end

    def read_value
      skip_space
      case @text[@pos]
      when "{" then read_object
      when "[" then read_array
      when '"' then read_string
      when "t" then read_word("true", true)
      when "f" then read_word("false", false)
      when "n" then read_word("null", nil)
      else read_number
      end
    end

    def read_object
      @pos += 1
      hash = {}
      skip_space
      return (@pos += 1) && hash if @text[@pos] == "}"
      loop do
        skip_space
        raise ArgumentError if @text[@pos] != '"'
        key = read_string
        skip_space
        raise ArgumentError if @text[@pos] != ":"
        @pos += 1
        hash[key] = read_value
        skip_space
        @pos += 1
        return hash if @text[@pos - 1] == "}"
        raise ArgumentError if @text[@pos - 1] != ","
      end
    end

    def read_array
      @pos += 1
      array = []
      skip_space
      return (@pos += 1) && array if @text[@pos] == "]"
      loop do
        array.push(read_value)
        skip_space
        @pos += 1
        return array if @text[@pos - 1] == "]"
        raise ArgumentError if @text[@pos - 1] != ","
      end
    end

    ESCAPES = { '"' => '"', "\\" => "\\", "/" => "/", "b" => "\b", "f" => "\f", "n" => "\n", "r" => "\r", "t" => "\t" }.freeze

    def read_string
      @pos += 1
      str = +""
      loop do
        c = @text[@pos]
        raise ArgumentError if c.nil?
        @pos += 1
        return str if c == '"'
        if c != "\\"
          str << c
        elsif @text[@pos] == "u"
          code = @text[@pos + 1, 4].to_i(16)
          @pos += 5
          # Surrogate pair (characters beyond U+FFFF)
          if code.between?(0xD800, 0xDBFF) && @text[@pos, 2] == "\\u"
            low = @text[@pos + 2, 4].to_i(16)
            @pos += 6
            code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)
          end
          str << code.chr(Encoding::UTF_8)
        else
          str << (ESCAPES[@text[@pos]] || raise(ArgumentError))
          @pos += 1
        end
      end
    end

    def read_word(word, value)
      raise ArgumentError if @text[@pos, word.length] != word
      @pos += word.length
      return value
    end

    def read_number
      number = @text[@pos..][/\A-?\d+(\.\d+)?([eE][+-]?\d+)?/]
      raise ArgumentError if !number
      @pos += number.length
      return (number.include?(".") || number =~ /[eE]/) ? number.to_f : number.to_i
    end

    def skip_space
      @pos += 1 while @text[@pos] =~ /\s/
    end
  end
end
