require "test/unit"
require "coulis"

class Ls < Coulis
  adef :all, "-a"
  adef :human, "-h"

  adef :full do
    all; human
  end
end

class Ping < Coulis
  bin `whereis ping`.strip
  adef :count, "-c"
end

class NSLookup < Coulis
  def parse_output(output)
    output.split("\n").
      map{|x| x.match(/Address: ([0-9\.]+)/)[1] rescue nil}.
      compact
  end
end

class SimpleCliTest < Test::Unit::TestCase
  def teardown
    Ls.new.reset
    Ping.new.reset
  end

  def test_default_bin
    assert_equal Ls.new.command, "ls"
  end

  def test_defined_bin
    assert_equal Ping.new.command, `whereis ping`.strip
    assert_equal Ping.new.command, Ping._bin
  end

  def test_adef
    assert_equal Ls._definitions[:all], "-a"
    assert_equal Ls._definitions[:human], "-h"
  end

  def test_adef_with_block
    assert_instance_of Proc, Ls._definitions[:full]
    assert_equal Ls._definitions[:full].call, ["-a", "-h"]
  end

  def test_argument_added
    ls = Ls.options { all }
    assert true, ls.args[0] == "-a"
  end

  def test_all_arguments_from_adef_added
    ls = Ls.options { full }
    assert_equal ls.args.size, 2
  end

  def test_not_defined_argument
    ls = Ls.options { s }
    assert_equal ls.args.size, 1
    assert_equal ls.args.to_s, "-s"
  end

  def test_command
    assert_equal Ls.options { full; s }.command, "ls -a -h -s"
  end

  def test_add_options
    ls = Ls.options { a }
    assert_equal ls.args.flatten.size, 1
    ls.options { l; h }
    assert_equal ls.args.flatten.size, 3

    assert_equal ls.command, "ls -a -l -h"
  end

  def test_add_option
    ls = Ls.new
    ls.all
    assert_equal ls.args.flatten.size, 1
    assert_equal ls.command, "ls -a"

    ls.l
    assert_equal ls.args.flatten.size, 2
    assert_equal ls.command, "ls -a -l"
  end

  def test_add_option_with_args
    ping = Ping.options {
      @args << ["-c", 2] << ["google.com"]
    }

    assert_equal ping.command, "#{Ping._bin} -c 2 google.com"
  end

  def test_remove_options
    ls = Ls.options { a; l; h }
    ls.remove :a, :h
    assert_equal ls.command, "ls -l"

    ls.reset
    ls.all
    ls.remove :all
    assert_equal ls.command, "ls"
  end

  def test_reset
    ls = Ls.options { a; l; h }
    assert_equal ls.command, "ls -a -l -h"
    ls.reset
    assert_equal ls.command, "ls"
  end

  def test_exec
    ls = Ls.options { full }.exec

    assert_instance_of String, ls
    assert true, ls.size > 0
  end

  def test_exec_with_block
    ls = Ls.options { full }
    process = ls.exec do |out|
      assert_instance_of String, out
      assert true, out.size > 0
    end

    assert_instance_of Process::Status, process
    assert_equal process.exitstatus, 0
  end

  def test_timeout
    assert_raise Timeout::Error do
      Ping.options {
        @args << ["google.com"]
        _timeout 2
      }.exec
    end
    assert_equal Ping.timeout, 2
  end

  def test_stdout
    res = ""
    Ping.options {
      count 2
      @args << ["google.com"]
    }.exec do |out|
      res << out
    end

    assert true, res.size > 0
  end

  def test_parse_output
    NSLookup.options {
      @args = ["google.com"]
    }.exec do |ips|
      assert_instance_of Array, ips
      assert true, ips.size > 1
    end
  end
end
