require "test/unit"
require "coulis"

class Ls < Coulis
  adef :all, "-a"
  adef :human, "-h"
  adef :full, "-a -h"
end

class FFMpeg < Coulis
  _no_double_dash
  adef :input, "-i"
end

class Ping < Coulis
  _bin `whereis ping`.strip
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
    #Ls.new.reset
    #Ping.new.reset
  end

  def test_shit
    #p Ls.options { full }
  end

  def test_default_bin
    assert_equal Ls.new.command, "ls"
  end

  def test_defined_bin
    assert_equal Ping.new.command, `whereis ping`.strip
    assert_equal Ping.new.command, Ping.bin
  end

  def test_adef
    assert_equal Ls._definitions[:all], "-a"
    assert_equal Ls._definitions[:human], "-h"
  end

  def test_adef_with_multiple_args
    assert_equal Ls._definitions[:full], "-a -h"
  end

  def test_argument_added
    ls = Ls.options { all }
    assert true, ls.args[0] == "-a"
  end

  def test_not_defined_short_argument
    ls = Ls.options { g }
    assert_equal 1, ls.args.size
    assert_equal "-g", ls.args.to_s
  end
  
  def test_not_defined_long_argument
    ls = Ls.options { color }
    assert_equal 1, ls.args.size
    assert_equal "--color", ls.args.to_s
  end

  def test_not_defined_long_argument_with_underscore
    ls = Ls.options { color_test }
    assert_equal 1, ls.args.size
    assert_equal "--color-test", ls.args.to_s
  end

  def test_no_double_dash_option
    ffmpeg = FFMpeg.options { vcodec "libx264" }
    assert_equal "ffmpeg -vcodec 'libx264'", ffmpeg.command
  end

  def test_remove_args_if_not_defined
    ffmpeg = FFMpeg.options { vcodec "libx264" }
    assert_equal 1, ffmpeg.args.size
    ffmpeg.remove :vcodec
    assert_equal 0, ffmpeg.args.size
  end

  def test_command
    assert_equal "ls -a -h -g", Ls.options { full; g }.command
  end

  def test_add_options
    ls = Ls.options { a }
    assert_equal 1, ls.args.flatten.size
    ls.options { l; h }
    assert_equal 3, ls.args.flatten.size

    assert_equal "ls -a -l -h", ls.command
  end

  def test_add_option
    ls = Ls.new
    ls.all
    assert_equal 1, ls.args.flatten.size
    assert_equal "ls -a", ls.command

    ls.l
    assert_equal 2, ls.args.flatten.size
    assert_equal "ls -a -l", ls.command
  end

  def test_add_option_with_args
    ping = Ping.options {
      @args << ["-c", 2] << ["google.com"]
    }

    assert_equal ping.command, "#{Ping.bin} -c 2 google.com"
  end

  def test_remove_options
    ls = Ls.options { a; l; h }
    ls.remove :a, :h
    assert_equal "ls -l", ls.command

    ls.reset
    ls.all
    ls.remove :all
    assert_equal "ls", ls.command
  end

  def test_reset
    ls = Ls.options { a; l; h }
    assert_equal "ls -a -l -h", ls.command
    ls.reset
    assert_equal "ls", ls.command
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
    assert_equal 0, process.exitstatus
  end

  def test_timeout
    assert_raise Timeout::Error do
      Ping.options {
        @args << ["google.com"]
        _timeout 2
      }.exec
    end
    assert_equal 2, Ping.timeout
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

  def test_success_event
    process = Ls.options {
      all
    }.on_success {|out| 
      assert_instance_of Process::Status, $?
      assert_equal 0, $?.exitstatus
      assert_instance_of String, out
    }.exec {|out| 
      assert_instance_of String, out
    }
  end

  def test_error_event
    process = Ls.options {
      @args = ["/not/a/path"]
    }.on_error {|out|
      assert_instance_of Process::Status, $?
      assert_equal 1, $?.exitstatus
      assert_instance_of String, out
    }.exec {|out| 
      assert_instance_of String, out
    }
  end

  def test_getting_value_by_arg
    ffmpeg = FFMpeg.options { input "video.mp4"; vcodec "libx264"}
    assert_equal "video.mp4", ffmpeg.value_by_arg(:input)
    assert_equal "libx264", ffmpeg.value_by_arg(:vcodec)
  end

  def test_adding_arg_before_another
    ffmpeg = FFMpeg.options {
      input "video.mp4"
      y "out.avi"
      vcodec "libx264", :before => "-y"
    }
    assert_equal "ffmpeg -i 'video.mp4' -vcodec 'libx264' -y 'out.avi'", ffmpeg.command
  end

  def test_adding_arg_after_another
    ffmpeg = FFMpeg.options {
      input "video.mp4"
      y "out.avi"
    }
    ffmpeg.vcodec "libx264", :after => :input
    assert_equal "ffmpeg -i 'video.mp4' -vcodec 'libx264' -y 'out.avi'", ffmpeg.command
  end

  def test_adding_uniq_arg
    ffmpeg = FFMpeg.options {
      input "video.mp4"
      y "out.avi"
    }
    ffmpeg.input "video2.mp4", :before => "-y", :uniq => true
    assert_equal "ffmpeg -i 'video2.mp4' -y 'out.avi'", ffmpeg.command
  end
end
