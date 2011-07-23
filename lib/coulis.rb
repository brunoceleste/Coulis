require "timeout"

class Coulis
  class << self
    attr_accessor :args, :_definitions, :_bin, :timeout

    def exec(*args, &block)
      self.new.exec *args, &block
    end

    def options(&block)
      self.new(&block)
    end

    def bin(p)
      @_bin = p.to_s
    end

    def _timeout(t)
      @timeout = t
    end

    def adef(name, option=nil, &block)
      (@_definitions||={})[name.to_sym] = (option || Proc.new { self.instance_eval(&block).flatten })
    end

    def method_missing(m, args=nil)
      m = m.to_s.gsub("=", "")
      @args ||= []
      definition = @_definitions[m.to_sym] rescue nil

      #puts "m: #{m}, def: #{definition.inspect} | args:#{args}"
      if definition.is_a?(Proc)
        definition.call
      else
        arg_name = "#{"-" if m[0..0] != "-"}#{m}"
        arg_name = "-" + arg_name.gsub("_", "-") if arg_name.size > 2

        if args.to_s.empty?
          @args << [ definition || arg_name ]
        else
          q = ""
          q = "'" if args.to_s[0..0] != "'"
          @args << [ definition || arg_name , "#{q}#{args}#{q}" ]
        end
      end
    end
  end

  attr_accessor :args

  def initialize(&block)
    self.class.instance_eval(&block) if block_given?
    @args = self.class.args
    self.class.args = []
    self
  end

  def options(&block)
    self.class.args = @args
    self.class.new(&block)
  end

  def remove(*args)
    new_args = []
    args.each do |a|
      @args.select {|b| b[0] == (self.class._definitions[a] || "-#{a}")}.each do |b|
        @args.delete(b)
      end
    end
    self.class.args = @args
    self
  end

  def reset
    @args = []
    self.class.args = []
  end

  def build_args
    return if @args.nil? or @args.empty?
    @args.flatten.join(" ")
  end

  def command
    "#{self.class._bin || self.class.to_s.downcase} #{build_args}".strip
  end

  def fire_command(&block)
    puts command + " (timeout: #{self.class.timeout || -1}) + #{block_given?}" if $DEBUG
    res = "" unless block_given?
    IO.popen(command + "  3>&2 2>&1") do |pipe|
      pipe.each("\r") do |line|
        if block_given?
          yield parse_output(line)
        else
          res << line
        end
      end
    end
    return (block_given? ? $? : parse_output(res))
  end

  def parse_output(output)
    output
  end

  def method_missing(m, args=nil)
    self.class.args = @args
    self.class.method_missing(m, args)
    @args = self.class.args
    self
  end

  def inspect
    "#<#{self.class.to_s} command=#{command} timeout=#{self.class.timeout || -1}>"
  end

  def exec(*args, &block)
    if args.size > 0
      i = 0
      (args.size / 2).times do
        self.class.send(args[i], args[i+1])
        i+=2
      end

      @args = self.class.args
      self.class.args = []
    end

    if self.class.timeout
      Timeout::timeout(self.class.timeout) do
        fire_command(&block)
      end
    else
      fire_command(&block)
    end
  end
end
