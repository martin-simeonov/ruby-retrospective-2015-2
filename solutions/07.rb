require 'date'

class LazyMode
  class << self
    def create_file(name)
      file = LazyMode::File.new(name)
      file.instance_eval(&Proc.new)
      file
    end
  end

  class Date
    attr_accessor :year, :month, :day

    def initialize(date)
      split = date.split('-')
      @year = split[0].to_i
      @month = split[1].to_i
      @day = split[2].to_i
    end

    def to_s
      date = "#{@year.to_s.rjust(4, '0')}-#{@month.to_s.rjust(2, '0')}"
      date + "-#{@day.to_s.rjust(2, '0')}"
    end

    def +(number)
      other = dup
      other.day += number
      other.send(:normalize)
      other
    end

    def check_schedule(schedule)
      date = Date.new(schedule.split[0])
      unless get_step(schedule)
        return Object::Date.parse(date.to_s) == Object::Date.parse(to_s)
      end
      while Object::Date.parse(date.to_s) < Object::Date.parse(to_s)
        date += get_step(schedule)
      end
      Object::Date.parse(date.to_s) == Object::Date.parse(to_s)
    end

    private

    def get_step(schedule)
      step = (/\d?[mdw]/.match schedule.split[1]).to_s
      eval(step.sub('m', '*30').sub('d', '*1').sub('w', '*7'))
    end

    def normalize
      while @day > 30
        @day -= 30
        @month += 1
      end
      while @month > 12
        @month -= 12
        @year += 1
      end
    end
  end

  class Agenda
    attr_reader :notes

    def initialize(notes)
      @notes = notes
    end

    def where(tag: nil, text: /.*/, status: nil)
      notes = @notes.find_all do |note|
        (tag.nil? or note.tags.include? tag) and
        (!(note.body =~ text).nil? or !(note.header =~ text).nil?) and
        (status.nil? or note.status == status)
      end

      Agenda.new(notes)
    end
  end

  class File
    attr_reader :name, :notes

    def initialize(name)
      @name = name
      @notes = Array.new
    end

    def daily_agenda(date)
      notes = @notes.find_all { |note| date.check_schedule(note.scheduled) }
      notes.each { |note| note.date = date }
      Agenda.new(notes)
    end

    def weekly_agenda(date)
      notes = Array.new
      (0..6).each { |day| notes += daily_agenda(date + day).notes }
      Agenda.new(notes)
    end

    private

    def note(header, *tags)
      note = Note.new(name, header, tags)
      @notes << note
      yield
    end

    def status(status)
      @notes.last.status = status
    end

    def body(body)
      @notes.last.body = body
    end

    def scheduled(scheduled)
      @notes.last.scheduled = scheduled
    end
  end

  class Note
    attr_accessor :header, :file_name, :tags, :body, :status, :scheduled, :date

    def initialize(file_name, header, tags)
      @file_name = file_name
      @header = header
      @tags = tags
      @status = :topostpone
      @body = ''
    end
  end
end
