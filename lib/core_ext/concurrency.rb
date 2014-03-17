module Enumerable

  def pmap
    self.map{|e| Thread.new{ yield e }}.map(&:join)
  end

end


module Kernel

  def future
    Future.new{yield}
  end

  def lazy
    Lazy.new{yield}
  end

end

class Future < BasicObject

  def initialize
    @thread = ::Thread.new do
      yield
    end
  end

  def respond_to? name, priv
    @thread.value.respond_to? name, priv
  end

  def method_missing *args, &blk
    @thread.value.send(*args, &blk)
  end

end


class Lazy < BasicObject

  def initialize &blk
    @blk = blk
  end

  def respond_to? name, priv
    __res.respond_to? name, priv
  end

  def method_missing *args, &blk
    __res.send(*args, &blk)
  end

  private

  def __res
    return @result if defined?(@result)
    @result = @blk.call
  end

end


class CyclicSynchronizer

  attr_reader :to_invoke, :sync_action, :yielders

  attr_accessor :current_generation

  def initialize(collection, to_invoke, &sync_action)
    @to_invoke = to_invoke
    @sync_action = sync_action

    @yielders = collection.map{|e| Yielder.new(e) }

    execute
  end


  def execute
    self.current_generation = Generation.new(self)

    yielders.pmap do |y|
      yield_method = y.method(:on_yield)

      result = case to_invoke
      when Proc
        to_invoke.call(y.element,&yield_method)
      when Syombol
        y.element.send(to_invoke,&yield_method)
      end

      y.kill

      result
    end
  end


  class Generation

    attr_accessor :sync_action_required, :synchronizer
    attr_reader :mutex, :threads

    def initialize(s)
      self.synchronizer = s
      @threads = []
      @mutex = Mutex.new
      self.sync_action_required = true

      synchronizer.yielders.each{|y| y.generation = self}
    end

    def perform_sync
      self.sync_action_required = false

      return if synchronizer.yielders.all?(&:killed?)

      to_return = synchronizer.sync_action.call(synchronizer.yielders.select{|y| y.did_yield}.map(&:yielded_value))

      synchronizer.current_generation = Generation.new(self.synchronizer)
      synchronizer.yielders.each{|y| y.to_return = to_return}
    end


    def progress
      needs_wakeup = false

      mutex.synchronize do
        threads << Thread.current
        mutex.sleep while sync_action_required && ! synchronizer.yielders.all?{|y| y.iteration_done?}
        # we're inside a mutex, so only one thread can and will see sync_action_required = true
        if sync_action_required
          perform_sync
          needs_wakeup = true
        end
      end

      threads.each(&:wakeup) if needs_wakeup
    end


  end

  class Yielder
    attr_accessor :element, :yielded_value, :did_yield, :to_return
    attr_reader :generation

    def initialize(e)
      self.element = e
    end


    def killed?
      @killed
    end

    def iteration_done?
      @killed || did_yield
    end

    def kill
      @killed = true
      generation.progress
    end

    def on_yield y
      raise "already yielded during current synchronization interval" if did_yield
      self.yielded_value = y
      self.did_yield = true
      generation.progress
      return to_return
    end

    def generation= g
      @generation = g
      self.yielded_value = nil
      self.did_yield = false
      self.to_return = nil
    end
  end



end






