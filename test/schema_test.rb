require 'test/test_base'
#require 'active_record' # OPTIONAL

module UserQuery

class SchemaTest < TestBase

  ############################################
  # Simple stuff.
  #

  def test_create(params = {})
    @params = params
    assert_not_nil @p = UserQuery::Parameters.
      new(params)
    assert_not_nil @s = UserQuery::Schema.
      new(:table => 'foo',
          :field => [
                     [ :id, :number ],
                     [ :n, :number ],
                     [ :date, :datetime ],
                     [ :memo, :string ],
                     [ :amount, :money ]
                    ]
          )
  end


  def test_empty
    test_create
    assert_equal nil, @s.sql(@params)
  end


  def test_NULL
    test_create({:n => "NULL"})
    # @s.verbose = true
    assert_equal "(foo.n IS NULL)", @s.sql(@params, @p)

    test_create({:n => "! NULL"})
    assert_equal "NOT ((foo.n IS NULL))", @s.sql(@params, @p)

    test_create({:n => "NOT NULL"})
    assert_equal "NOT ((foo.n IS NULL))", @s.sql(@params, @p)
  end


  def test_syntax_error
    test_create({:memo => "$!"})
    assert_equal nil, @s.sql(@params, @p)
    assert       ! @p.errors.empty?
    assert       @p.errors[:memo] =~ /invalid character .* at "\$/
    # $stderr.puts @p.errors[:memo]
  end


  def test_id
    test_create({:id => "500"})
    assert_equal "(foo.id = 500)", @s.sql(@params, @p)
  end


  def test_id_gt
    test_create({:id => ">500"})
    assert_equal "(foo.id > 500)", @s.sql(@params, @p)

  end


  def test_number_like
    test_create({:n => "LIKE 50"})
    assert_equal "(foo.n LIKE '%50%')", @s.sql(@params, @p)
  end


  def test_like
    test_create({:memo => "~foo"})
    assert_equal "(foo.memo LIKE '%foo%')", @s.sql(@params, @p)

    test_create({:memo => 'LIKE "95%"'})
    assert_equal "(foo.memo LIKE '%95\\%%')", @s.sql(@params, @p)

    test_create({:memo => 'LIKE "UNDER_SCORE"'})
    assert_equal "(foo.memo LIKE '%UNDER\\_SCORE%')", @s.sql(@params, @p)
  end


  def test_number_errors
    test_create({:n => "foo"})
    assert_equal nil, @s.sql(@params, @p)
    assert       ! @p.errors.empty?
    # $stderr.puts "p.errors = #{@p.errors.inspect}"
    assert       @p.errors[:n] =~ /invalid character .* at "foo"$/
  end


  def test_date
    test_create({:date => "12/31/2005"})
    assert_equal "((foo.date >= '2005-12-31 00:00:00') AND (foo.date < '2006-01-01 00:00:00'))", @s.sql(@params, @p)

    test_create({:date => "12/31/2005 12:00:00am"})
    assert_equal "((foo.date >= '2005-12-31 00:00:00') AND (foo.date < '2005-12-31 00:00:01'))", @s.sql(@params, @p)

    test_create({:date => "12/31/2005 11:59:59pm"})
    assert_equal "((foo.date >= '2005-12-31 23:59:59') AND (foo.date < '2006-01-01 00:00:00'))", @s.sql(@params, @p)

    test_create({:date => "BEFORE 2005"})
    assert_equal "(foo.date < '2005-01-01 00:00:00')", @s.sql(@params, @p)
  end


  def test_money

    return true unless has_currency

    test_create({:amount => ".56"})
    assert_equal "(foo.amount = 56)", @s.sql(@params, @p)

    test_create({:amount => "-.41"})
    assert_equal "(foo.amount = -41)", @s.sql(@params, @p)

    test_create({:amount => "1,234.56"})
    assert_equal "(foo.amount = 123456)", @s.sql(@params, @p)

    test_create({:amount => "LESS THAN $123.01"})
    assert_equal "(foo.amount < 12301)", @s.sql(@params, @p)

    test_create({:amount => "-123.01"})
    assert_equal "(foo.amount = -12301)", @s.sql(@params, @p)
  end

end

end # module

