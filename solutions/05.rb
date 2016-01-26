require 'digest/sha1'

class ObjectStore
  class << self
    def init
      repo = new
      repo.instance_eval(&Proc.new) if block_given?
      repo
    end

    private :new
  end

  def initialize
    @branches = BranchStore.new
  end

  def add(name, object)
    @branches.current_branch.add(name, object)
  end

  def remove(name)
    @branches.current_branch.remove(name)
  end

  def commit(message)
    @branches.current_branch.commit(message)
  end

  def checkout(commit_hash)
    @branches.current_branch.checkout(commit_hash)
  end

  def branch
    @branches
  end

  def log
    @branches.current_branch.log
  end

  def head
    @branches.current_branch.head
  end

  def get(name)
    @branches.current_branch.get(name)
  end
end

class Branch
  attr_accessor :name

  def initialize(name)
    @storage = {}
    @commit_add = {}
    @commit_remove = {}
    @commit_log = {}
    @name = name
  end

  def add(name, object)
    @commit_add[name] = object
    ResultOperation.new("Added #{name} to stage.", true, object)
  end

  def remove(name)
    if @storage.key?(name)
      @commit_remove[name] = 'remove'
      ResultOperation.new("Added #{name} for removal.", true, @storage[name])
    else
      Operation.new("Object #{name} is not committed.", false)
    end
  end

  def commit(message)
    if @commit_add.empty? and @commit_remove.empty?
      Operation.new('Nothing to commit, working directory clean.', false)
    else
      count_changes = perform_changes
      commit = Commit.new(message, true, @storage.values)
      @commit_log[commit.hash] = commit
      commit_message = "#{message}\n\t#{count_changes} objects changed"
      ResultOperation.new(commit_message, true, commit)
    end
  end

  def checkout(commit_hash)
    if @commit_log.key?(commit_hash)
      commit = @commit_log[commit_hash]
      @storage = commit.clone
      @commit_log.delete_if { |_, value| value.date < commit.date }
      @commit_add.clear
      @commit_remove.clear
      ResultOperation.new("HEAD is now at #{commit_hash}.", true, commit)
    else
      Operation.new("Commit #{commit_hash} does not exist.", false)
    end
  end

  def log
    if @commit_log.empty?
      Operation.new("Branch #{@name} does not have any commits yet.", false)
    else
      message = ''
      @commit_log.reverse_each do |_, commit|
        message += "Commit #{commit.hash}\nDate: "
        message += "#{commit.date.strftime('%a %b %d %H:%M %Y %z')}\n\n\t"
        message += "#{commit.message}\n\n"
      end
      Operation.new(message.chomp.chomp, true)
    end
  end

  def head
    if @commit_log.empty?
      message = "Branch #{name} does not have any commits yet."
      Operation.new(message, false)
    else
      message = @commit_log.values.last.message
      ResultOperation.new(message, true, @commit_log.values.last)
    end
  end

  def get(name)
    if @storage.key?(name)
      ResultOperation.new("Found object #{name}.", true, @storage[name])
    else
      Operation.new("Object #{name} is not committed.", false)
    end
  end

  private

  def perform_changes
    count_changes = @commit_add.count + @commit_remove.count
    @storage.merge!(@commit_add)
    @storage.delete_if { |key, _| @commit_remove.key?(key) }
    @commit_add.clear
    @commit_remove.clear
    count_changes
  end
end

class BranchStore
  attr_reader :current_branch

  def initialize
    @current_branch = Branch.new('master')
    @branches = { 'master' => @current_branch }
  end

  def create(branch_name)
    if @branches.key?(branch_name)
      Operation.new("Branch #{branch_name} already exists.", false)
    else
      branch = @current_branch.clone
      branch.name = branch_name
      @branches[branch_name] = branch
      Operation.new("Created branch #{branch_name}.", true)
    end
  end

  def checkout(branch_name)
    if @branches.key?(branch_name)
      @current_branch = @branches[branch_name]
      Operation.new("Switched to branch #{branch_name}.", true)
    else
      Operation.new("Branch #{branch_name} does not exist.", false)
    end
  end

  def remove(branch_name)
    if @branches.key?(branch_name)
      if @branches[branch_name] == @current_branch
        Operation.new('Cannot remove current branch.', false)
      else
        @branches.delete(branch_name)
        Operation.new("Removed branch #{branch_name}.", true)
      end
    else
      Operation.new("Branch #{branch_name} does not exist.", false)
    end
  end

  def list
    message = ''
    @branches.sort.map do |name, branch|
      if branch == @current_branch
        message += "* #{name}\n"
      else
        message += "  #{name}\n"
      end
    end
    Operation.new(message.chomp, true)
  end
end

class Operation
  attr_reader :message

  def initialize(message, success)
    @message = message
    @success = success
  end

  def success?
    @success
  end

  def error?
    not @success
  end
end

class ResultOperation < Operation
  attr_reader :result

  def initialize(message, success, result)
    super message, success
    @result = result
  end
end

class Commit < ResultOperation
  attr_reader :date, :hash, :objects

  def initialize(commit_message, success, objects = nil)
    @date = Time.now
    @hash = Digest::SHA1.hexdigest("#{date}#{commit_message}")
    @objects = objects.clone
    super commit_message, success, self
  end
end
