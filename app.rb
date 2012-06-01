#!/usr/bin/env ruby
# encoding: UTF-8

require 'rubygems' if RUBY_VERSION >= '1.9'
require 'sinatra'
require 'pathname'
require 'httpclient'
require 'xml/xslt'

# a singleton class to provide an HTTPClient instance
class HttpClient
  
  # @return [HTTPClient] our single HTTPClient instance
  def self.httpClient
    # our HTTP client (for re-use)
    return @httpClient if @httpClient
    @httpClient = HTTPClient.new
    @httpClient.debug_dev = STDERR
    @httpClient.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    return @httpClient
  end
  
  # a wrapper around our HTTPClient instance
  def self.method_missing(name, *args, &block)
    STDERR.puts "Called #{name} with #{args.inspect} and #{block}"
    if block
      self.httpClient.send( name, *args, &block)
    else
      self.httpClient.send( name, *args )
    end
  end
end

# The Transformer uses a local XSLT style sheet to transform a remote XML file.
# @author Markus Strauss
class Transformer
  
  # this returns any problems the Transformer encountered during operation
  # @return [Array] of Problems (struct with fields 'code' and 'message')
  attr_reader :problems
  
  # Bad Request
  BAD_CLIENT_REQUEST = 400
  # Bad Gateway
  INVALID_UPSTREAM_RESPONSE = 502
  
  # returns the transformer with given name
  def self.get( name )
    Transformer.new( name )
  end
  
  # checks if the transformer with given name exists locally
  # @param [String] name of the transformer
  def self.exists?( name )
    xslt_path(name).exist?
  end
  
  def initialize( name )
    @problems = []
    unless Transformer.exists?(name)
      fail "Transformer definitions for '#{name}' not found. Please create '#{Transformer.xslt_path(name)}'."
    end
    @xslt = XML::XSLT.new
    @xslt.xsl = Transformer.xslt_path( name ).to_s
  end
  
  # @return [NilClass || Object] the XML data if successful, nil otherwise
  def transform( url )
    xml_data = xml_data( url )
    unless has_problems?
      @xslt.xml = xml_data
      @xslt.serve
    else
      nil
    end
  rescue XML::XSLT::ParsingError => error
    log_a_problem( INVALID_UPSTREAM_RESPONSE, error, __LINE__ )
  end
  
  # @param [String] the URL to fetch
  # @return the response body from URL
  def xml_data( url )
    uri = URI.parse(url)
    unless uri.host and uri.port and uri.scheme and uri.request_uri
      log_a_problem( BAD_CLIENT_REQUEST, "URI '#{uri}' is not valid." )
    else
      fetch_xml( uri )
    end
  end
  
  # Returns if we had any problems. If so, query #problems.
  def has_problems?
    @problems.size > 0
  end
  
  private
  
  # @param [String] transformer name
  # @return [Pathname] expected path of the local xslt file
  def self.xslt_path( name )
    Pathname( "#{name}.xslt" ).expand_path
  end
  
  def fetch_xml( uri )
    STDERR.puts "Fetching #{uri.to_s}"
    username, password = uri.userinfo.split(':') if uri.userinfo
    HttpClient.set_auth( uri.to_s, username, password ) if username and password
    response = HttpClient.get( uri )
    unless response.status_code == 200
      log_a_problem( INVALID_UPSTREAM_RESPONSE, response, __LINE__ )
    else
      response.body
    end
  rescue SocketError
    log_a_problem( INVALID_UPSTREAM_RESPONSE, $!, __LINE__ )
  end
  
  # Logs a problem to @problems and to STDERR
  # @param [Number] code: preferably any constant from this class
  # @param [#user_info, #to_s] error: an Exception type object or anything convertible to String
  # @param [Number] line: an optional line number to print on STDERR
  def log_a_problem( code, error, line = nil )
    STDERR.write "PROBLEM #{code}"
    STDERR.write " at line #{line}" if line
    STDERR.write ": "
    if error.respond_to?(:user_info)
      message = error.user_info
    else
      message = error.to_s
    end
    STDERR.puts message
    STDERR.puts error.backtrace if error.respond_to?(:backtrace)
    @problems << OpenStruct.new( :code => code, :message => message )
  end
  
end

class Exception
  def print_debug_info( out = STDERR )
    out.puts "=========================== EXCEPTION REPORT ============================"
    if self.instance_of?( StandardError )
      out.puts "EXCEPTION (StandardError): #{self.class}: #{self.message}"
    elsif self.instance_of?( RuntimeError )
      out.puts "EXCEPTION (RuntimeError): #{self.class}: #{self.message}"
    else
      out.puts "EXCEPTION: #{self.class}: #{self.message}"
    end
    out.puts "--- STACKTRACE ----------------------------------------------------------"
    out.puts self.backtrace.join($/)
    out.puts "======================== END OF EXCEPTION REPORT ========================"
  end
  
  def user_info
    "#{self.class}: #{self.message}. Consult the log for details."
  end
end

module HTTP
  class Message
    def user_info
      "Upstream Response: #{self.code} #{self.reason}"
    end
  end
end


get '/:transformer' do |transformer|
  url = request.query_string
  begin
    transformer = Transformer.get( transformer )
    html_output = transformer.transform( url )
    if transformer.has_problems?
      problem = transformer.problems.first
      halt problem.code, {'Content-Type' => 'text/plain'}, problem.message
    else
      html_output
    end
  rescue
    $!.print_debug_info
    halt 500, {'Content-Type' => 'text/plain'}, $!.user_info
  end
end

not_found do
  'This is nowhere to be found.'
end
