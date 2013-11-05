# This class defined how query parameters are to be interpreted.
#
module UserQuery

class Schema
  @active_record_base = false
  begin
    # Kernel.require 'active_record'
    @@active_record_base = ActiveRecord::Base
  rescue Object => err
    @@active_record_base = false
  end

  @@empty_hash = { }
  @@empty_hash.freeze

  attr_accessor :verbose

  def initialize(*opts)
    @opt = Hash[*opts]

    @verbose = @opt[:verbose]

    @field_by_name = { }
    @field = [ ]

    field = @opt[:field]
    field = [ field ] unless field.kind_of?(Array)
    field.each{|x| add_field(x)}

    # Interpret ActiveRecord::Base subclass
    cls = @opt[:table]
    if is_active_record?(cls)
      columns = cls.columns
      table_name = cls.table_name;
      columns.each do |col|
        field = {
          :table => table_name,
          :name => col.name,
          :type => col.type,
        }
        field = add_field(field)
        # $stderr.puts "AR::Base column #{col.inspect} =>\n  #{field.inspect}"
      end
    end

  end

  def is_active_record?(cls)
    return false unless cls.kind_of?(Class)
    while cls
      if cls == @@active_record_base
        return true;
      end
      cls = cls.superclass
    end
    false
  end

private

  def add_field(field)
    field = { :name => field } unless field.kind_of?(Array) || field.kind_of?(Hash)
    field = { :name => field[0], :type => field[1], :table => field[2] } if field.kind_of?(Array)

    # Normalize name.
    field[:name] = field[:name].intern if field[:name].respond_to?(:intern);

    # Normalize table.
    field[:table] ||= @opt[:table]
    field[:table] = sql_table_name(field[:table])

    return nil if (@field_by_name[field[:table]] ||= {})[field[:name]]

    # Normalize type
    field[:type] ||= :string
    field[:type] = :string if field[:type] == :text
    field[:type] = :number if field[:type] == :integer
    field[:type] = :datetime if field[:type] == :date

    # Keep track of by table.column name.
    (@field_by_name[field[:table]] ||= {})[field[:name]] = field;
    @field << field

    field
  end

  def sql_table_name(x)
    x && (x.kind_of?(String) ? x : x.table_name)
  end

  def sql_field_table_name(field)
    sql_table_name(field[:table] || @opt[:table])
  end

  def sql_expr(field)
    field[:sql_expr] || sql_table_column(sql_field_table_name(field), field[:name].to_s)
  end

  def sql_table_column(table, column)
    table ? table + '.' + column : column
  end

public

  def sql(parameters, record = nil)
    record ||= parameters if parameters.respond_to?(:errors)
    

    sql = @field.map do |field| 
      f_sql = nil
      begin
        name = field[:name]
        type = field[:type]

        verbose = field[:verbose] || @verbose

        target = sql_expr(field)

        parameter = parameters.kind_of?(Hash) ?
        parameters[name] :
          parameters.send(name)
        
        query_expr = UserQuery::Parser.
          new(:type => type, 
              :verbose => verbose).
          parse(parameter)
        
        f_sql = UserQuery::Generator.
          new(:type => type,
              :target => target,
              :verbose => verbose).
          sql(query_expr)
        
        if verbose 
          $stderr.puts "name   = #{name.inspect}"
          $stderr.puts "target = #{target.inspect}"
          $stderr.puts "type   = #{type.inspect}"
          $stderr.puts "query  = #{parameter.inspect}"
          $stderr.puts "sql    = #{f_sql.inspect}"
        end
        
      rescue UserQuery::Parser::SyntaxError => err
        record.errors.add(name, err.to_s) if record
        $stderr.puts "\n#{self.class.name}: Error: #{err}" if verbose
        f_sql = nil
      end
      
      f_sql
    end.compact.join(' AND ')

    sql = nil if sql.empty?

    sql
  end

end

end # module
