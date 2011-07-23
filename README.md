# Coulis: a simple CLI Wrapper #

With Coulis, you can create a wrapper for any CLI application very easily.

## Install ##

	sudo gem install coulis

## Getting started ##

To create a wrapper class, just create a class which inerits from the `Coulis` class. Example with the curl application:

``` ruby
class Curl < Coulis
  adef :user,    "-u"
  adef :request, "-X"
  adef :data,    "-d"
  adef :header,  "-H"
  adef :agent,   "-A"
  adef :form,    "-F"
  adef :proxy,   "-x"
  adef :head,    "-I"
end
```

To use the created class:

``` ruby
Curl.options {
  user    "user:passwd"
  request "POST"
  data    "url=http://site.com/video.avi"
  data    "title=MyTitle"
  url     "https://heywatch.com/download.json"
}.exec do |out|
  puts out
end
```

## Arguments ##

You can define an argument with the method `adef`. Note that all other short and long parameters (not defined in the class) are still available via their name. Example with the parameters `-e` and `--url`:

``` ruby
Curl.options {
  agent "Coulis / 0.1.2"
  e     "http://site.com/referer" # -e => referer
  url   "http://google.com"
}.exec {...}
```

## Profile ##

Let's say you want to set the user agent, user credentials and the header accept/json for each request. Let's define it in our class Curl:

``` ruby
class Curl < Coulis
  adef :user,    "-u"
  adef :request, "-X"
  adef :data,    "-d"
  adef :header,  "-H"
  adef :agent,   "-A"
  adef :form,    "-F"
  adef :proxy,   "-x"
  adef :head,    "-I"

  adef :accept_json do
    header "Accept: application/json"
  end

  adef :default do
    user "user:passwd"
    accept_json
    agent "Coulis / 0.1.0"
  end
end
```

Now to use our profile `default`:

``` ruby
Curl.options {
  default
  url "http://heywatch.com/account"
}.exec {...}
```

## Parsing Output ##

Define the method `parse_output` in your class to automatically parse the output, here is an example with `nslookup`:

``` ruby
class NSLookup < Coulis
  def parse_output(output)
    output.split("\n").
      map{|x| x.match(/Address: ([0-9\.]+)/)[1] rescue nil}.
      compact
  end
end

NSLookup.options {
  @args = ["google.com"]
}.exec do |ips|
  p ips # => ["209.85.148.106", "209.85.148.103", "209.85.148.147", "209.85.148.99", "209.85.148.105", "209.85.148.104"]
end
```

Released under the [MIT license](http://www.opensource.org/licenses/mit-license.php).

Author: Bruno Celeste [@sadikzzz](http://twitter.com/sadikzzz)