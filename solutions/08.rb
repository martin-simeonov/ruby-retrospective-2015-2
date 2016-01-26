module Formulas
  def add(first, second, *other)
    first += second
    first += other.inject(&:+) unless other.empty?
    first
  end

  def multiply(first, second, *other)
    first *= second
    first *= other.inject(&:*) unless other.empty?
    first
  end

  def subtract(first, second)
    first - second
  end

  def divide(first, second)
    first /= second.to_f
    first = first.round(2)
    return first.to_i if first % 1 == 0.0
    first
  end

  def mod(first, second)
    first % second
  end
end

class Spreadsheet
  include Formulas

  class Error < StandardError
  end

  def initialize(table_string = '')
    @table = []
    return if table_string.empty?
    create_table(table_string)
  end

  def empty?
    @table.empty?
  end

  def cell_at(cell_index)
    row, column = get_index(cell_index)
    if row < 0
      raise Error, "Invalid cell index '#{cell_index}'"
    end
    begin
     cell = @table[row][column]
    rescue Exception
      raise Error, "Cell '#{cell_index}' does not exist"
    end
  end

  def [](cell_index)
    evaluate_cell(cell_at(cell_index))
  end

  def to_s
    table = ''
    @table.each do |row|
      row.each { |column| table += evaluate_cell(column) + "\t" }
      table.chop!
      table += "\n"
    end
    table.chop
  end

  private

  def create_table(table_string)
    table_string.strip!
    rows = table_string.split("\n")
    rows.map(&:strip!)
    rows.each do |row|
      columns = row.split(/\t|  /).map(&:strip)
      @table << columns
    end
  end

  def get_index(cell_index)
    row = column = ''
    cell_index.each_char do |char|
      if char =~ /[[:digit:]]/
        row += char
      else
        column += ((char.ord - 'A'.ord) + 1).to_s
      end
    end
    return [row.to_i - 1, column.to_i(26) - 1]
  end

  def evaluate_cell(cell)
    return cell if cell[0] != '='
    work_cell = cell.gsub(/[A-Z][0-9]/) do |match|
      raise Error, "Invalid expression '#{cell}'" if cell == cell_at(match)
      evaluate_cell(cell_at(match))
    end
    work_cell.downcase!
    work_cell[0] = ''
    begin
      work_cell = eval(work_cell)
    rescue NoMethodError => error
      raise Error, "Unknown function '#{error.name}'"
    rescue ArgumentError => error
      given, needed = error.message.scan(/\d/)
      name = work_cell.scan(/[a-z]+/)[0].upcase
      message = "Wrong number of arguments for '#{name}': expected"
      if given < needed
        raise Error, message + " at least #{needed}, got #{given}"
      else
        raise Error, message + " #{needed}, got #{given}"
      end
    rescue Exception => e
      raise Error, "Invalid expression '#{cell}'"
    end
    work_cell.to_s
  end
end
