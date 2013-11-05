module UserQuery

class Generator
  class Error < Exception; end

  # Inputs
  attr_accessor :type
  attr_accessor :values_inline
  attr_accessor :target
  attr_accessor :verbose

  # Outputs
  attr_accessor :expr
  attr_accessor :values

  def initialize(*opts)
    self.target = '<<TARGET>>'
    self.values_inline = true
    self.type = :string
    opts = Hash[*opts]
    opts.each{|k, v| self.send("#{k}=", v)}
  end

  def sql(expr)
    @values = [ ]
    @expr = ''

    return nil if expr.nil?

    emit_sql(expr)

    @expr
  end
  
  private

  @@empty_hash = { }
  @@empty_hash.freeze

  @@OP_2_SQL = {
    true => { 
      :not => 'NOT',
      :and => 'AND',
      :or  => 'OR',
      :lt  => '<',
      :gt  => '>',
      :le  => '<=',
      :ge  => '>=',
      :eq  => '=',
      :ne  => '<>'
    },
    :null => {
      :eq => 'IS',
      :ne => 'IS NOT'
    }
  }

  def op_to_sql(type, expr = nil)
    #if true || @verbose
    #  $stderr.puts "opt_to_sql(#{type.inspect}, #{expr.inspect}) => "
    #end

    expr = expr && expr[0]
    sql = nil
    sql ||= (@@OP_2_SQL[expr] || @@empty_hash)[type] if expr
    sql ||= (@@OP_2_SQL[true])[type]
    raise Error, "Unknown operator #{type.inspect}" unless sql

    #if @verbose
    #  $stderr.puts "#{sql.inspect} "
    #end

    sql
  end

  def emit_sql(expr)
    case type = expr && expr[0]
    when :not
      emit("#{op_to_sql(type)} (")
      emit_sql(expr[1])
      emit(")")

    when :and, :or
      emit("(")
      emit_sql(expr[1])
      emit(" #{op_to_sql(type)} ")
      emit_sql(expr[2])
      emit(")")

    when :lt, :gt, :le, :ge, :eq, :ne
      emit("(")
      emit(target)
      emit(" #{op_to_sql(type, expr[1])} ")
      emit_sql_value(expr[1])
      emit(")")

    when :between
      emit("((")
      emit(target)
      emit(" >= ")
      emit_sql_value(expr[1])
      emit(") #{op_to_sql(:and)} (")
      emit(target)
      emit(" <= ")
      emit_sql_value(expr[2])
      emit("))")

    when :range
      emit("((")
      emit(target)
      emit(" >= ")
      emit_sql_value(expr[1])
      emit(") #{op_to_sql(:and)} (")
      emit(target)
      emit(" < ")
      emit_sql_value(expr[2])
      emit("))")

    when :like
      emit("(")
      emit(target)
      emit(" LIKE ")
      expr_1 = expr[1]
      expr_1 = [ :string, expr_1[1], expr_1[1] ]
      expr_1[1] = expr_1[1].gsub(/[%_\\]/){|x| "\\#{x}"} # Escape '%' and '_' in query
      expr_1[1] = '%' + expr_1[1] + '%'
      # $stderr.puts "LIKE #{expr_1[1]}"
      expr_1[2] = expr_1[1]
      emit_sql_value(expr_1, :no_internal_escape)
      emit(")")

    else
      emit("(")
      emit(target)
      emit(" #{op_to_sql(:eq, expr)} ")
      emit_sql_value(expr)
      emit(")")
    end
  end
  
  def to_string(value)
    to_simple(value)[0].to_s
  end

  def emit_sql_value(value, *options)
    value, type = to_simple(value)

    if values_inline
      case type
      when :null
        value = sql_quote(value)
      when :number, :boolean
        value = value.to_s
      else
        value = sql_quote(value, *options)
      end

      emit(value)
    else
      emit('?')
      @values << value
    end
  end

  def to_simple(value)
    case type = value && value[0]
      when :null
      value = nil

      when :string, :word, :number
      value = value[2]

      when :boolean
      value = value[2] ? 1 : 0 # MySQL tinyint(1)

      when :money
      type = :number
      value = value[2].rep

      # MySQL-specific timedate formats!?!
      when :year
      value = "#{'%04d' % value[2]}-01-01 00:00:00"

      when :month
      value = "#{'%04d' % value[2]}-#{'%02d' % value[3]}-01 00:00:00"

      when :day
      value = "#{'%04d' % value[2]}-#{'%02d' % value[3]}-#{'%02d' % value[4]} 00:00:00"

      when :hour
      value = "#{'%04d' % value[2]}-#{'%02d' % value[3]}-#{'%02d' % value[4]} #{'%02d' % value[5]}:00:00"

      when :minute
      value = "#{'%04d' % value[2]}-#{'%02d' % value[3]}-#{'%02d' % value[4]} #{'%02d' % value[5]}:#{'%02d' % value[6]}:00"
      when :second
      value = "#{'%04d' % value[2]}-#{'%02d' % value[3]}-#{'%02d' % value[4]} #{'%02d' % value[5]}:#{'%02d' % value[6]}:#{'%02d' % value[7]}"
      
    else
      raise Error, "Unknown value type #{value.inspect}"
    end

    [ value, type ]
  end

  def sql_quote(value, no_internal_escape = false)
    return 'NULL' if value.nil?
    "'" + (no_internal_escape ? 
          value.to_s.gsub(/(['])/){|x| "\\#{x}"} :
          value.to_s.gsub(/(['\\])/){|x| "\\#{x}"}) +
    "'"
  end

  def emit(raw)
    @expr << raw
  end

end

end # module
