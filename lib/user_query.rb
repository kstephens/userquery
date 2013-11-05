
$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'user_query/user_query_version.rb'
require 'user_query/parameters.rb'
require 'user_query/parser.rb'
require 'user_query/generator.rb'
require 'user_query/schema.rb'

