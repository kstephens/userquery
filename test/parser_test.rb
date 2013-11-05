require 'test/test_base'

module UserQuery

class ParserTest < TestBase

  ############################################
  # Simple stuff.
  #

  def test_create
    assert_not_nil qp = UserQuery::Parser.
      new()

    qp
  end

  def test_empty
    qp = test_create
    assert_equal qp << '  ', nil
  end

  def test_bad_syntax
    qp = test_create
    
    assert_raise(UserQuery::Parser::SyntaxError) {qp << '##@!@'}
  end

  def test_trailing_tokens
    qp = test_create
    
    assert_raise(UserQuery::Parser::SyntaxError) {qp << '=Foo bar'}
  end

  def test_word
    qp = test_create
    assert_equal [:like, [:word, 'hello', 'hello']], qp << 'hello' 

    assert_equal [:like, [:word, 'NOTfoo', 'NOTfoo']], qp << 'NOTfoo'

    assert_equal [:like, [:word, 'true', 'true']], qp << 'true' 

    assert_equal [:like, [:word, 'FALSE', 'FALSE']], qp << 'FALSE'
  end

  def test_word_trailing_whitespace
    qp = test_create
    assert_equal [:like, [:word, 'hello', 'hello']], qp << 'hello   ' 
  end

  def test_string
    qp = test_create
    assert_equal [:like, [:string, "", ""]], qp << '  ""  '
    assert_equal [:like, [:string, "  ", "  "]], qp << '  "  "  '
    assert_equal [:like, [:string, 'hello world!', 'hello world!']], qp << '"hello world!"'
  end

  def test_string_escape
    qp = test_create
    # qp.verbose = 1
    assert_equal [:like, [:string, "\\", "\\"]], qp << '"\\\\"'
    assert_equal [:like, [:string, "\"", "\""]], qp << '"\\""'
    assert_equal [:like, [:string, "\"foo\"", "\"foo\""]], qp << '"\\"foo\\""'
    assert_equal [:like, [:string, "he\\llo \"world!", "he\\llo \"world!"]], qp << '"he\\\\llo \"world!"' 
  end

  def test_integer
    qp = test_create
    assert_equal [:eq, [:number, '123', 123]], qp << 123 
    assert_equal [:eq, [:number, '123', 123]], qp << '123' 
    assert_equal [:eq, [:number, '-123', -123]], qp << '-123' 
    assert_equal [:eq, [:number, '-123', -123]], qp << '  -123' 
    assert_equal [:eq, [:number, '+1234', 1234]], qp << '+1234' 
  end

  def test_integer_like
    qp = test_create
    assert_equal [:like, [:string, '123', '123']], qp << 'LIKE 123' 
  end

  def test_float
    qp = test_create
    assert_equal [:eq, [:number, '1.23', 1.23]], qp << 1.23 
    assert_equal [:eq, [:number, '1.23', 1.23]], qp << '1.23' 
    assert_equal [:eq, [:number, '-12.34', -12.34]], qp << '-12.34' 
    assert_equal [:eq, [:number, '-0.3', -0.3]], qp << '-0.3' 
    assert_equal [:eq, [:number, '+1.2e10', 1.2e10]], qp << '+1.2e10' 
    assert_equal [:eq, [:number, '0.25e-8', 0.25e-8]], qp << '0.25e-8' 
  end

  def test_boolean
    qp = test_create

    qp.type = :boolean
    # qp.verbose = true
    assert_equal [:eq, [:boolean, 'true', true ]], qp << 'true' 
    assert_equal [:eq, [:boolean, 'false', false ]], qp << 'false' 
  end


  def test_money
    return true unless has_currency

    qp = test_create

    qp.type = :money
    # qp.verbose = true
    assert_equal [:eq, [:money, '123', Currency::Money.new('123')]], qp << '123' 
    assert_equal [:eq, [:money, '123.00', Currency::Money.new('123')]], qp << '123.00' 
    assert_equal [:eq, [:money, '-123.00', Currency::Money.new('-123')]], qp << '-123.00' 
    assert_equal [:eq, [:money, '123.45', Currency::Money.new('123.45')]], qp << '123.45'
    assert_equal [:gt, [:money, '1,234.56', Currency::Money.new('1234.56')]], qp << '>1,234.56' 
    assert_equal [:eq, [:money, '$123', Currency::Money.new('123')]], qp << '$123' 
    assert_equal [:eq, [:money, '$123.00', Currency::Money.new('123')]], qp << '$123.00' 
    assert_equal [:eq, [:money, '$-123.00', Currency::Money.new('-123')]], qp << '$-123.00' 
    assert_equal [:eq, [:money, '$123.45', Currency::Money.new('123.45')]], qp << '$123.45'
    assert_equal [:gt, [:money, '$1,234.56', Currency::Money.new('1234.56')]], qp << '>$1,234.56' 
  end


  def test_sequence
    qp = test_create
    # qp.verbose = true
    assert_equal [:and, [:like, [:word, 'hello', 'hello']], [:like, [:word, 'world', 'world']]], qp << 'hello world' 
  end


  def test_between
    qp = test_create
    assert_equal [:between, [:number, '1', 1], [:number, '5', 5]], qp << 'BETWEEN 1 AND 5' 
    assert_equal [:between, [:number, '2', 2], [:number, '199', 199]], qp << 'BETWEEN 2 ... 199' 

    assert_equal [:between, [:word, 'abraxas', 'abraxas'], [:word, 'zebra', 'zebra']], qp << 'BETWEEN abraxas...zebra' 
  end


  def test_elipsis
    qp = test_create
    assert_equal [:between, [:number, '1', 1], [:number, '19', 19]], qp << '1 ... 19' 
  end


  def test_and
    qp = test_create
    assert_equal [:and, 
                  [:like, [:word, 'foo', 'foo']],
                  [:and,
                   [:like, [:word, 'bar', 'bar']],
                   [:like, [:word, 'baz', 'baz']]]],
    qp << 'foo AND bar AND baz'

    qp = test_create
    assert_equal [:and, 
                  [:like, [:word, 'foo', 'foo']],
                  [:and,
                   [:like, [:word, 'bar', 'bar']],
                   [:not, [:like, [:word, 'baz', 'baz']]]]],
    qp << 'foo AND bar AND !baz'
  end


  def test_and_or
    qp = test_create
    assert_equal [:or, 
                  [:and,
                   [:like, [:word, 'foo', 'foo']],
                   [:like, [:word, 'bar', 'bar']]],
                  [:like, [:word, 'baz', 'baz']]],
    qp << 'foo AND bar OR baz'
  end


  def test_not
    qp = test_create

    assert_equal [:not, 
                  [:like, [:word, 'foo', 'foo']]
                  ],
    qp << 'NOT foo'

    #qp.verbose = true

    assert_equal [:not, 
                  [:and,
                   [:like, [:word, 'foo', 'foo']],
                   [:like, [:word, 'bar', 'bar']]
                   ]
                  ],
    qp << 'NOT (foo AND bar)'


    assert_equal [:not, 
                  [:and,
                   [:like, [:word, 'foo', 'foo']],
                   [:like, [:word, 'bar', 'bar']]
                   ]
                  ],
    qp << 'NOT foo bar'

  end


  def test_grouping
    qp = test_create
    #qp.verbose = true

    assert_equal [:or, 
                  [:and, 
                   [:like,
                    [:word, 'foo', 'foo']
                   ],
                   [:like,
                    [:word, 'bar', 'bar']
                   ]],
                  [:like,
                   [:word, 'baz', 'baz']
                  ]],
    qp << '(foo AND bar) OR baz'

    qp = test_create
    assert_equal [:and, 
                  [:like,
                    [:word, 'foo', 'foo']
                   ],
                  [:or, 
                   [:like,
                    [:word, 'bar', 'bar']
                   ],
                   [:like,
                    [:word, 'baz', 'baz']
                   ]]],
    qp << 'foo AND (bar OR baz)'
  end


  def test_year
    qp = test_create
    qp.type = :datetime

    assert_equal [:range, [:year, '2006', 2006], [:year, '2006', 2007]], qp << '2006' 
  end


  def test_month
    qp = test_create
    qp.type = :datetime

    assert_equal [:range, 
                  [:month, '4/2006', 2006, 4], 
                  [:month, '4/2006', 2006, 5]], 
    qp << '4/2006' 

    assert_equal [:range,
                  [:month, '04/2006', 2006, 4],
                  [:month, '04/2006', 2006, 5]],
    qp << '04/2006' 

    assert_equal [:range, 
                  [:month, '12/2006', 2006, 12],
                  [:month, '12/2006', 2007, 1]],
    qp << '12/2006' 
  end


  def test_day
    qp = test_create
    qp.type = :datetime

    assert_equal [:range, 
                  [:day, '2/4/2006', 2006, 2, 4],
                  [:day, '2/4/2006', 2006, 2, 5]],
    qp << '2/4/2006' 

    assert_equal [:range,
                  [:day, '2/04/2006', 2006, 2, 4],
                  [:day, '2/04/2006', 2006, 2, 5]],
    qp << '2/04/2006'

    assert_equal [:range,
                  [:day, '02/04/2006', 2006, 2, 4],
                  [:day, '02/04/2006', 2006, 2, 5]],
    qp << '02/04/2006'

    assert_equal [:range,
                  [:day, '02/4/2006', 2006, 2, 4],
                  [:day, '02/4/2006', 2006, 2, 5]],
    qp << '02/4/2006'

    assert_equal [:range,
                  [:day, '12/4/2006', 2006, 12, 4],
                  [:day, '12/4/2006', 2006, 12, 5]],
    qp << '12/4/2006' 
   
    assert_equal [:range,
                  [:day, '12/04/2006', 2006, 12, 4],
                  [:day, '12/04/2006', 2006, 12, 5]],
    qp << '12/04/2006' 

    assert_equal [:range,
                  [:day, '12/31/2006', 2006, 12, 31],
                  [:day, '12/31/2006', 2007, 1, 1]],
    qp << '12/31/2006' 

    qp.this_year = 2006
    assert_equal [:range,
                  [:day, '12/31', 2006, 12, 31],
                  [:day, '12/31', 2007, 1, 1]],
    qp << '12/31'
  end


  def test_hour
    qp = test_create
    qp.type = :datetime

    assert_equal [:range, 
                  [:hour, '2/4/2006 12am', 2006, 2, 4, 0], 
                  [:hour, '2/4/2006 12am', 2006, 2, 4, 1]], 
    qp << '2/4/2006 12am' 

    assert_equal [:range, 
                  [:hour, '2/4/2006 5', 2006, 2, 4, 5], 
                  [:hour, '2/4/2006 5', 2006, 2, 4, 6]], 
    qp << '2/4/2006 5' 
    assert_equal [:range, 
                  [:hour, '2/4/2006-5 AM', 2006, 2, 4, 5],
                  [:hour, '2/4/2006-5 AM',2006, 2, 4, 6]], 
    qp << '2/4/2006-5 AM' 

    assert_equal [:range, 
                  [:hour, '2/4/2006 12P', 2006, 2, 4, 12], 
                  [:hour, '2/4/2006 12P', 2006, 2, 4, 13]], 
    qp << '2/4/2006 12P' 

    assert_equal [:range, 
                  [:hour, '2/4/2006-2pm', 2006, 2, 4, 14],
                  [:hour, '2/4/2006-2pm', 2006, 2, 4, 15]],
    qp << '2/4/2006-2pm' 

    assert_equal [:range, 
                  [:hour, '2/4/2006-14', 2006, 2, 4, 14], 
                  [:hour, '2/4/2006-14', 2006, 2, 4, 15]], qp << '2/4/2006-14' 

  end


  def test_minute
    qp = test_create
    qp.type = :datetime

    assert_equal [:range, 
                  [:minute, '2/4/2006 12:30am', 2006, 2, 4, 0, 30],
                  [:minute, '2/4/2006 12:30am', 2006, 2, 4, 0, 31 ]], 
    qp << '2/4/2006 12:30am' 

    assert_equal [:range, 
                  [:minute, '2/4/2006 9:00p', 2006, 2, 4, 21, 00],
                  [:minute, '2/4/2006 9:00p', 2006, 2, 4, 21, 01 ]],
    qp << '2/4/2006 9:00p' 

    assert_equal [:range,
                  [:minute, '2/4/2006 1430', 2006, 2, 4, 14, 30],
                  [:minute, '2/4/2006 1430', 2006, 2, 4, 14, 31 ]],
    qp << '2/4/2006 1430' 


  end


  def test_second
    qp = test_create
    qp.type = :datetime

    assert_equal [:range, 
                  [:second, '2/4/2006 12:30:00am', 2006, 2, 4, 0, 30, 00 ],
                  [:second, '2/4/2006 12:30:00am', 2006, 2, 4, 0, 30, 01 ]], 
    qp << '2/4/2006 12:30:00am' 

    assert_equal [:range, 
                  [:second, '2/4/2006 9:00:05p', 2006, 2, 4, 21, 00, 05 ],
                  [:second, '2/4/2006 9:00:05p', 2006, 2, 4, 21, 00, 06 ]],
    qp << '2/4/2006 9:00:05p' 

    assert_equal [:range, 
                  [:second, '2/4/2006 9:00:59p', 2006, 2, 4, 21, 00, 59 ],
                  [:second, '2/4/2006 9:00:59p', 2006, 2, 4, 21, 01, 00 ]],
    qp << '2/4/2006 9:00:59p' 

    assert_equal [:range,
                  [:second, '2/4/2006 143033', 2006, 2, 4, 14, 30, 33 ],
                  [:second, '2/4/2006 143033', 2006, 2, 4, 14, 30, 34 ]],
    qp << '2/4/2006 143033' 


  end


  def test_time_now
    qp = test_create
    qp.type = :datetime

    qp.now = Time.utc(2006, 2, 4, 0, 30, 15)
    assert_equal [:range, 
                  [:second, 'now', 2006, 2, 4, 0, 30, 15 ],
                  [:second, 'now', 2006, 2, 4, 0, 30, 16 ]], 
    qp << 'now' 
  end


  def test_time_today
    qp = test_create
    qp.type = :datetime

    qp.now = Time.utc(2006, 2, 4, 0, 30, 15)
    assert_equal [:range, 
                  [:day, 'today', 2006, 2, 4 ],
                  [:day, 'today', 2006, 2, 5 ]], 
    qp << 'today' 


    assert_equal [:range, 
                  [:day, 'tomorrow', 2006, 2, 5 ],
                  [:day, 'tomorrow', 2006, 2, 6 ]], 
    qp << 'tomorrow' 

    assert_equal [:range, 
                  [:day, 'yesterday', 2006, 2, 3 ],
                  [:day, 'yesterday', 2006, 2, 4 ]], 
    qp << 'yesterday' 
  end


  def test_time_this_year
    qp = test_create
    qp.type = :datetime

    qp.now = Time.utc(2006, 2, 4, 0, 30, 15)
    assert_equal [:range, 
                  [:year, 'this year', 2006 ],
                  [:year, 'this year', 2007 ]], 
    qp << 'this year' 
  end


  def test_time_today_relative
    qp = test_create
    qp.type = :datetime

    qp.now = Time.utc(2006, 2, 4, 0, 30, 15)
    assert_equal [:range, 
                  [:day, 'today+1', 2006, 2, 5 ],
                  [:day, 'today+1', 2006, 2, 6 ]], 
    qp << 'today+1' 

    qp.now = Time.utc(2006, 2, 4, 0, 30, 15)
    assert_equal [:range, 
                  [:day, 'today-2', 2006, 2, 2 ],
                  [:day, 'today-2', 2006, 2, 3 ]], 
    qp << 'today-2' 
  end


  def test_between_day_and_year
    qp = test_create
    qp.type = :datetime
    
    assert_equal [:between, [:day, '2/4/2006', 2006, 2, 4], [:year, '2007', 2007]], qp << 'BETWEEN 2/4/2006 AND 2007'

    assert_equal [:between, [:day, '2/4/2006', 2006, 2, 4], [:year, '2007', 2007]], qp << '2/4/2006...2007'
  end


  def test_bad_between
    qp = test_create
    
    assert_raise(UserQuery::Parser::SyntaxError) {qp << 'BETWEEN 1 AND FOO'}
    assert_equal [:between, [:number, '1', 1], [:number, '5', 5]], qp << 'BETWEEN 1 AND 5'

    assert_equal [:between, [:word, 'BAR', 'BAR'], [:string, 'BAZ', 'BAZ']], qp << 'BETWEEN BAR AND "BAZ"'

    qp.type = :datetime
    assert_raise(UserQuery::Parser::SyntaxError) {qp << 'BETWEEN 12/31/2006 AND FOO'}
  end


  def test_eq
    qp = test_create
    assert_equal [:eq, [:number, '45', 45]], qp << '=45'
    assert_equal [:eq, [:number, '123', 123]], qp << '= 123'
    
    qp.type = :datetime
    assert_equal [:range, 
                  [:minute, '2/4/2006 1430', 2006, 2, 4, 14, 30], 
                  [:minute, '2/4/2006 1430', 2006, 2, 4, 14, 31 ]], 
                  qp << '= 2/4/2006 1430' 
    assert_equal [:range, 
                  [:hour, '2/4/2006 5', 2006, 2, 4, 5], 
                  [:hour, '2/4/2006 5', 2006, 2, 4, 6]], 
                  qp << ' = 2/4/2006 5' 
    assert_equal [:range, 
                  [:month, '12/2006', 2006, 12], 
                  [:month, '12/2006', 2007, 1]], 
                  qp << 'EQUAL TO 12/2006' 
    
  end


  def test_ne
    qp = test_create
    assert_equal [:ne, [:number, '76', 76]], qp << '!=76'
    assert_equal [:ne, [:number, '34', 34]], qp << '<> 34'
    assert_equal [:ne, [:number, '123', 123]], qp << '<>123'
    
    qp.type = :datetime
    assert_equal [:or, 
                  [:lt,
                   [:minute, '2/4/2006 1430', 2006, 2, 4, 14, 30]],
                  [:ge,
                   [:minute, '2/4/2006 1430', 2006, 2, 4, 14, 31 ]]], 
    qp << '<> 2/4/2006 1430' 
  end


  def test_complex_1
    qp = test_create
    # qp.verbose = true
    assert_equal [:and,
                  [:lt, [:number, '5', 5]],
                  [:gt, [:number, '2', 2]]
                  ],
    qp << '<5 AND >2'
  end


end # class

end # module

