# This class can be used as a stand-in for an ActiveRecord class, while
# using the ActionPack input tag helpers and standard ActionPack::Controller
# idiom.
#
module UserQuery

class Parameters
  @active_record_errors = false
  begin
    # Kernel.require 'active_record'
    @@active_record_errors = ActiveRecord::Errors
  rescue Object => err
    @@active_record_errors = false
  end

  unless @@active_record_errors
    # Emulate ActiverRecord::Base errors support
    class Errors
      def initialize(obj)
        @obj = obj
        @name_errors = { }
        @errors = nil
      end
      def add(name, err)
        (@name_errors[name] ||= []).push(err)
        (@errors ||= []).push([name, err])
      end
      def [](name)
        (@name_errors[name] || []).join('\n')
      end
      def empty?
        (! @errors) || @errors.empty?
      end
    end
    @@active_record_errors = Errors
  end


  def initialize(*opts)
    @hash = opts.empty? ? {} : opts[0]
    @hash ||= { }
  end

  def _value_hash
    @hash
  end

  # Emulate ActiverRecord::Base errors support
  def errors
    # See ActiveRecord::Validations
    @errors ||= @@active_record_errors.new(self)
  end
  def self.human_attribute_name(x)
    x # PUNT
  end

  
  def [](key)
    @hash[key]
  end

  # OVERIDE Object
  def id
    @hash[:id]
  end
  def id=(x)
    @hash[:id] = x
  end

  def respond_to?(meth)
    true
  end

  def method_missing(method, *args)
    m = method.to_s.clone
    if m.sub!(/=$/, '') && args.size == 1
      $stderr.puts "set #{method.inspect} #{args[0].inspect}" if @verbose
      result = @hash[m.intern] = args[0]
    elsif m.sub!(/_before_type_cast$/, '') && args.size == 0
      $stderr.puts "get #{method.inspect}" if @verbose
      result = @hash[m.intern]
    elsif args.size == 0
      $stderr.puts "get #{method.inspect}" if @verbose
      result = @hash[method]
    else
      raise NotImplementedError, method
    end
      
    result
  end
end

end # module
