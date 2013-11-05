require 'time'

module UserQuery

# Do:
#   require 'currency'
# for :type => :money
#

class Parser
  @now = nil
  @@now = nil
  @today = nil
  @@today= nil
  @this_year = nil
  @@this_year = nil

  class Error < Exception; end
  class SyntaxError < Error; end

  attr_accessor :default_join_op
  attr_accessor :default_literal_op
  attr_accessor :keywords
  attr_accessor :type
  attr_accessor :expr
  attr_accessor :verbose

  def initialize(*opts)
    self.verbose = false
    self.default_join_op = :and
    self.default_literal_op = :like
    self.keywords = [ ]
    self.type = :string
    opts = Hash[*opts]
    opts.each{|k, v| self.send("#{k}=", v)}
  end

  def parse(str)
    return nil if str.nil?

    str = str.to_s

    @level = 0
    @input_original = str.clone
    @input = str.clone
    @lex_next = nil
    @expr = lex_peek && parse_top_level

    eat_whitespace

    @lex_extra = lex_peek
    if @lex_extra
      raise SyntaxError, "extra characters for #{type.to_s} field at #{@lex_extra[1].inspect}"
    end

    if @verbose
      q_sql = UserQuery::Generator.new.sql(@expr)
      $stderr.puts "#{str.inspect} =>\n  " + @expr.inspect + " =>\n  " + q_sql.inspect
    end

    @expr
  end

  def <<(str)
    parse(str)
  end
  
  # Configuration

  def now=(t)
    @now = t
  end
  def now
    @now || @@now || Time.new
  end

  def this_year=(y)
    @this_year = y.respond_to?(:year) ? y.year : y
    y
  end
  def this_year
    @this_year || @@this_year || now.year
  end

  def today=(t)
    t = t && Time.utc(t.year, t.month, t.day, 0, 0, 0, 0)
    @today = t
  end
  def today
    t = @today || @@today 
    unless t
      t = now
      t = Time.utc(t.year, t.month, t.day, 0, 0, 0, 0)
    end
    t
  end

private
  # Recursive-descendent parser
  def parse_top_level
    show_where("parse_top_level")

    expr = parse_expression

    show_where("parse_top_level", expr)

    expr
  end

  def parse_expression
    show_where("parse_expression")

    expr = parse_conditional

    show_where("parse_expression", expr)

    expr
  end

  def parse_conditional
    show_where("parse_conditional")

    expr = parse_logical_or

    show_where("parse_conditional", expr)

    expr
  end

  def parse_logical_or
    show_where("parse_logical_or")

    expr = parse_logical_and

    l = lex_peek
    case type = l && l[0]
    when :or
      lex_read
      expr = [ :or, expr, parse_logical_or ]
    end

    show_where("parse_logical_or", expr)

    expr
  end

  def parse_logical_and
    show_where("parse_logical_and")

    expr = parse_relational

    l = lex_peek
    case type = l && l[0]
    when :and
      lex_read
      show_where("parse_logical_and: expr2")
      expr_2 = parse_logical_and
      show_where("parse_logical_and: expr2: ", expr_2)
      expr = [ :and, expr, expr_2 ]
    end

    show_where("parse_logical_and", expr)

    expr
  end


  def parse_relational
    show_where("parse_relational")

    expr = lex_peek
    case op = expr && expr[0]
    when :eq
      lex_read
      expr = ranged_value_eq(parse_literal)

    when :ne
      lex_read
      expr = ranged_value_ne(parse_literal)

    when :gt
      lex_read
      expr = ranged_value_gt(parse_literal)

    when :lt, :ge
      lex_read
      expr = [ op, parse_literal ]

    when :le
      lex_read
      expr = ranged_value_le(parse_literal)

    when :between
      lex_read
      expr_1 = parse_literal
      lex_eat(:and, :elipsis)
      expr_2 = parse_literal(*range_types(expr_1[0]))
      expr = [ op, expr_1, expr_2 ]

    else
      expr = parse_unary
    end

    show_where("parse_relational", expr)

    expr
  end

  def parse_unary
    show_where("parse_unary")

    expr = lex_peek
    case op = expr && expr[0]
    when :not
      lex_read
      expr = [ op, parse_sequence ]
    when :like
      lex_read
      expr = [ op, to_string(parse_literal) ]
    else
      expr = parse_sequence
    end

    show_where("parse_unary", expr)

    expr
  end

  def parse_sequence
    show_where("parse_sequence")

    expr = parse_primary
    
    while l = lex_match(:word, :string, :number, :money, :year, :month, :date, :hour, :minute)
      expr = [ default_join_op, expr, parse_primary ]
    end

    show_where("parse_sequence", expr)

    expr    
  end

  def parse_primary
    show_where("parse_primary")

    expr = lex_peek
    case type = expr && expr[0]
    when '('
      lex_read
      expr = parse_expression
      lex_eat(')')

    else
      expr = parse_singular
    end

    show_where("parse_primary", expr)

    expr    
  end


  def parse_singular
    show_where("parse_singular")

    expr = parse_literal

    l = lex_peek
    case type = l && l[0]
    when :elipsis
      lex_read
      expr = [ :between, expr, parse_literal ]
    else
      #  Literals are enconsed with the default literal op
      #  
      case type = expr && expr[0]
      when :number, :boolean, :money
        # Numericals should match exact.
        expr = [ :eq, expr ]

      when :string, :word
        # Strings are usually inexact so we use the default literal op.
        expr = [ default_literal_op, expr ]
        
      when :year, :month, :day, :hour, :minute, :second
        # datetime is inexact because intutively
        # a date should match all values with that date,
        # but datetime values have greater precision than just date
        # So we translate year, month, day to intuitive ranges.
        expr = [ :range, expr, ranged_value_plus_1(expr) ]
      end
    end

    show_where("parse_singular", expr)

    expr
  end

  def parse_literal(*types)
    types = types.flatten
    show_where("parse_literal")
    
    expr = lex_peek(*types)

    case type = expr && expr[0]
    when :null, :string, :word, :number, :boolean, :money 
      expr = lex_read(types)

    when :year, :month, :day, :hour, :minute, :second
      expr = lex_read(types)

    else
      raise SyntaxError, "Unexpected #{expr.inspect}"

    end

    show_where("parse_literal", expr)

    expr
  end

  ############################################################
  # Ranged values
  #

  # :datetime is a ranged value type.
  # because intutively a date should match all DATETIME values within 
  # that date, regardless of how much precision 
  # DATETIME has, i.e. down to the second.
  # 
  # For example:
  #
  # The query:
  #
  #  "12/31/2005"
  #
  # should generate SQL:
  #
  # column >= '2005-12-31 00:00:00' AND column < '2006-01-01 00:00:00'
  #
  # The query:
  #
  #  "!= 12/31/2005"
  #
  # should generate SQL:
  #
  # column < '2005-12-31 00:00:00' AND column >= '2006-01-01 00:00:00'
  #
  # The query:
  #
  #  "> 12/31/2005"
  #
  # should generate SQL:
  #
  # column >= '2006-01-01 00:00:00'
  #

  def range_types(type)
    case type
    when :word, :string
      type = [ :word, :string ]
    when :year, :month, :day, :hour, :minute, :second 
      type = [ :year, :month, :day, :hour, :minute, :second ]
    else
      type = [ type ]
    end

    type
  end

  
  def ranged_value_eq(expr)
    case type = expr && expr[0]
    when :year, :month, :day, :hour, :minute, :second
      expr_0 = expr
      expr_1 = ranged_value_plus_1(expr)
      expr = [ :range, expr_0, expr_1 ]

    else
      expr = [ :eq, expr ]
    end

    expr
  end

  def ranged_value_ne(expr)
    case type = expr && expr[0]
    when :year, :month, :day, :hour, :minute, :second
      expr_0 = expr
      expr_1 = ranged_value_plus_1(expr)
      expr = [ :or,
               [ :lt, expr_0 ],
               [ :ge, expr_1 ],
             ]

    else
      expr = [ :ne, expr ]
    end

    expr
  end

  def ranged_value_gt(expr)
    case type = expr && expr[0]
    when :year, :month, :day, :hour, :minute, :second
      expr = ranged_value_plus_1(expr)
      expr = [ :ge, expr ]

    else
      expr = [ :gt, expr ]

    end

    expr
  end

  def ranged_value_le(expr)
    case type = expr && expr[0]
    when :year, :month, :day, :hour, :minute
      expr = ranged_value_plus_1(expr)
      expr = [ :lt, expr ]

    else
      expr = [ :le, expr ]

    end

    expr
  end


  def ranged_value_plus_1(expr)
    case type = expr && expr[0]
    when :year
      expr = year_plus_1(expr)

    when :month
      expr = month_plus_1(expr)

    when :day
      expr = day_plus_1(expr)

    when :hour
      expr = hour_plus_1(expr)

    when :minute
      expr = minute_plus_1(expr)

    when :second
      expr = second_plus_1(expr)

    end

    expr
  end


  ############################################################
  # datetime helper
  #

  def year_plus_1(x)
    x = x.clone
    x[2] = x[2] + 1
    x
  end

  def month_plus_1(x)
    x = x.clone
    x[3] = x[3] + 1
    if x[3] > 12
      x[3] = 1
      x[2] = x[2] + 1
    end
    x
  end

  def day_plus_1(x)
    # $stderr.puts "day_plus_1(#{x.inspect})"
    t = Time.utc(x[2], x[3] || 1, x[4] || 1, 0, 0, 0, 0)
    t = t + (60 * 60 * 25) # Add one day, plus fudge for leap seconds
    x = [ x[0],
          x[1], # str
          t.year,
          t.month,
          t.day
        ]
    x
  end

  def hour_plus_1(x)
    t = Time.utc(x[2], x[3] || 1, x[4] || 1, x[5] || 0, 0, 0, 0)
    t = t + (65 * 60) # Add one hour, plus fudge for leap seconds
    x = [ x[0],
          x[1], # str
          t.year,
          t.month,
          t.day,
          t.hour
        ]
    x
  end

  def minute_plus_1(x)
    t = Time.utc(x[2], x[3] || 1, x[4] || 1, x[5] || 0, x[6] || 0, 0, 0)
    t = t + 65 # Add one minunte, plus fudge for leap seconds
    x = [ x[0],
          x[1], # str
          t.year,
          t.month,
          t.day,
          t.hour,
          t.min
        ]
    x
  end

  def second_plus_1(x)
    t = Time.utc(x[2], x[3] || 1, x[4] || 1, x[5] || 0, x[6] || 0, x[7] || 0, 0)
    t = t + 1 # Add one second
    x = [ x[0],
          x[1], # str
          t.year,
          t.month,
          t.day,
          t.hour,
          t.min,
          t.sec
        ]
    x
  end

  ############################################################
  # Push back interface w/ lexeme type checks
  #

  def show_where(str = "", expr = nil)
    @level = @level - 1 if expr != nil
    $stderr.puts "#{"  " * @level} #{str}: #{lex_peek.inspect} #{@input.inspect} #{expr && ' => '} #{expr && expr.inspect}" if @verbose
    @level = @level + 1 if expr == nil
  end

  def lex_match(*types)
    l = lex_peek
    types = types.flatten
    types.include?(l && l[0])
  end

  def lex_peek(*types)
    check_types(@lex_next ||= lex, types)
  end

  def lex_read(*types)
    l = @lex_next || lex
    @lex_next = nil
    check_types(l, types)
  end

  def lex_eat(*types)
    l = lex_read
    check_types(l, types)
  end

  def check_types(l, types)
    types = types.flatten
    unless types.empty?
      raise SyntaxError, "expected #{types.inspect}, found #{l.inspect}" unless types.include?(l && l[0])
    end
    l
  end

  def to_string(l)
    l = l.clone;
    l[0] = :string
    l[1] = l[1].to_s
    l[2] = l[2].to_s
    l
  end


  ############################################################
  # Low-level lexer
  #

  def lex
    # @verbose = true
    x = @input
    
    l = nil
    if eat_whitespace
      if false
        l = nil

      elsif md = match(/\ANULL\b/)
        l = [ :null, md[0] ]

      elsif md = match(/\A\.\.\./)
        l = [ :elipsis ]

      elsif md = match(/\A(AND\b|[&])/)
        l = [ :and ]

      elsif md = match(/\A(OR\b|[|])/)
        l = [ :or ]

      elsif md = match(/\ABETWEEN\b/)
        l = [ :between ]

      elsif md = match(/\A(NOT\s+EQUAL(\s+TO)?\b|!=|<>)/)
        l = [ :ne ]

      elsif md = match(/\A(LESS\s+THAN\s+ORs\+EQUAL\s+TO\b|<=)/)
        l = [ :le ]

      elsif md = match(/\A(GREATER\s+THAN\s+ORs\+EQUAL\s+TO\b|>=)/)
        l = [ :ge ]

      elsif md = match(/\A(BEFORE\b|LESS(\s+THAN)?\b|<)/)
        l = [ :lt ]

      elsif md = match(/\A(AFTER\b|GREATER(\s+THAN)?\b|>)/)
        l = [ :gt ]

      elsif md = match(/\A(EQUAL(\s+TO)?\b|==?)/)
        l = [ :eq ]

      elsif md = match(/\A(NOT\b|!)/)
        l = [ :not ]

      elsif md = match(/\A(LIKE\b|~)/)
        l = [ :like, ]

      elsif md = match(/\A([\(\)])/)
        l = [ md[1], md[0] ]

      elsif md = match(/\A"((\\.|[^\\"]+)*)"/)
        l = md[1]
        l.gsub!(/\\(.)/){|x| $1}
        @keywords << l
        l = [ :string, l, l ]

      elsif type == :boolean && (md = match(/\A(true)/i))
        l = [ :boolean, md[0], true ]

      elsif type == :boolean && (md = match(/\A(false)/i))
        l = [ :boolean, md[0], false ]

      elsif type == :money && (md = match(/\A(\$?[-+]?([\d,]+(\.\d+)?|\.\d+))/))
        l = [ :money, md[0], Currency::Money.new(md[1]) ]

      elsif type == :datetime && (md = match(/\A(\d\d?)\/(\d\d?)\/(\d\d\d\d)(-|\s+)(\d\d?):?(\d\d):?(\d\d)\s*([ap]?)m?/i))
        # mm/dd/yyyy hh:mm:ss(am|pm)
        hh = fix_hh_am_pm(md[5], md[8])
        mm = md[6].to_i
        ss = md[7].to_i
        l = [ :second, md[0], md[3].to_i, md[1].to_i, md[2].to_i, hh, mm, ss ]

      elsif type == :datetime && (md = match(/\A(\d\d?)\/(\d\d?)\/(\d\d\d\d)(-|\s+)(\d\d?):?(\d\d)\s*([ap]?)m?/i))
        # mm/dd/yyyy hh:mm(am|pm)
        hh = fix_hh_am_pm(md[5], md[7])
        mm = md[6].to_i
        l = [ :minute, md[0], md[3].to_i, md[1].to_i, md[2].to_i, hh, mm ]

      elsif type == :datetime && (md = match(/\A(\d\d?)\/(\d\d?)\/(\d\d\d\d)(-|\s+)(\d\d?)\s*([ap]?)m?/i))
        # mm/dd/yyyy hh
        hh = fix_hh_am_pm(md[5], md[6])
        l = [ :hour, md[0], md[3].to_i, md[1].to_i, md[2].to_i, hh ]

      elsif type == :datetime && (md = match(/\A(\d\d\d\d)\/(\d\d?)\/(\d\d?)/))
        # yyyy/mm/dd
        l = [ :day, md[0], md[1].to_i, md[2].to_i, md[3].to_i ]

      elsif type == :datetime && (md = match(/\A(\d\d?)\/(\d\d?)\/(\d\d\d\d)/))
        # mm/dd/yyyy
        l = [ :day, md[0], md[3].to_i, md[1].to_i, md[2].to_i ]

      elsif type == :datetime && (md = match(/\A(\d\d?)\/(\d\d\d\d)/))
        # mm/yyyy
        l = [ :month, md[0], md[2].to_i, md[1].to_i ]

      elsif type == :datetime && (md = match(/\A(\d\d?)\/(\d\d?)/))
        # mm/dd => THIS-YEAR/mm/dd
        l = [ :day, md[0], this_year, md[1].to_i, md[2].to_i ]
 
      elsif type == :datetime && (md = match(/\A(\d\d\d\d)\/(\d\d?)/))
        # yyyy/mm
        l = [ :month, md[0], md[1].to_i, md[2].to_i ]

      elsif type == :datetime && (md = match(/\A(\d\d\d\d)/))
        # yyyy
        l = [ :year, md[0], md[1].to_i ]

      elsif type == :datetime && (md = match(/\Anow\b/i))
        # now
        l = now
        l = [ :second, md[0], l.year, l.month, l.day, l.hour, l.min, l.sec ]

      elsif type == :datetime && (md = match(/\Athis\s*year\b/i))
        # this year => THIS-YEAR
        l = [ :year, md[0], this_year ]

      elsif type == :datetime && (md = match(/\Ayesterday\b|today\s*\-\s*(\d+)/i))
        # yesterday
        l = today - (24 * 60 * 60) * (md[1] ? md[1].to_i : 1)
        l = [ :day, md[0], l.year, l.month, l.day ]

      elsif type == :datetime && (md = match(/\Atomorrow\b|today\s*\+\s*(\d+)/i))
        # tomorrow
        l = today + (24 * 60 * 60) * (md[1] ? md[1].to_i : 1)
        l = [ :day, md[0], l.year, l.month, l.day ]

      elsif type == :datetime && (md = match(/\Atoday\b/i))
        # today
        l = today
        l = [ :day, md[0], l.year, l.month, l.day ]

      elsif md = match(/\A([-+]?((\d+|\.\d+|\d+\.\d*)[eE][-+]?\d+|\.\d+|\d+\.\d*))/)
        l = [ :number, md[0], md[1].to_f ]

      elsif md = match(/\A([-+]?\d+)/)
        l = [ :number, md[0], md[1].to_i ]

      elsif type == :string && md = match(/\A(\w+)/)
        @keywords << md[1]
        l = [ :word, md[0], md[1] ]
      else
        raise SyntaxError, "invalid character for #{type.to_s} field at #{@input.inspect}"
      end
    end

    $stderr.puts "lex #{x.inspect} => #{l.inspect}" if @verbose #

    l
  end

  def fix_hh_am_pm(hh, am_pm)
    hh = hh.to_i
    if am_pm 
      am_pm = am_pm.downcase
      hh = 0       if am_pm == 'a' && hh == 12
      hh = hh + 12 if am_pm == 'p' && hh != 12
    end
    hh
  end

  def eat_whitespace
    @input.sub!(/\A\s+/, '')
    ! @input.empty?
  end

  def match(rx)
    # $stderr.puts "m_a_a @ #{@input.inspect}"
    if md = rx.match(@input)
      @input = md.post_match
    end
    md
  end

end

end # module

