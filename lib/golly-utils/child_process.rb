module GollyUtils

  # Start, manage, and stop a child process.
  class ChildProcess

    # The shell command to start the child process.
    # @return [String]
    attr_accessor :start_command

    # Whether to print startup/shutdown info to stdout, and whether or not to the stdout and stderr streams of the child
    # process (unless explictly redirected via :spawn_options)
    # @return [Boolean]
    attr_accessor :quiet
    alias :quiet? :quiet

    # Options to pass to `Process#spawn`.
    # @return [Hash]
    attr_accessor :spawn_options

    # Environment variables to set in the child process.
    # @return [Hash]
    attr_accessor :env

    # The PID of the child process if running.
    # @return [Fixnum, nil]
    attr_reader :pid

    # @option options [String] :start_command See {#start_command}.
    # @option options [Hash] :env See {#env}.
    # @option options [Boolean] :quiet (false) See {#quiet}.
    # @option options [Hash] :spawn_options See {#spawn_options}.
    def initialize(options={})
      options= {env: {}, quiet: false, spawn_options: {}}.merge(options)
      options[:spawn_options][:in] ||= '/dev/null'
      options.each {|k,v| send "#{k}=", v}
    end

    # Starts the child process.
    #
    # If it is already running, then this will do nothing.
    #
    # @return [self]
    def startup
      unless alive?
        opt= self.spawn_options
        if quiet?
          opt= opt.dup
          mute= [:out,:err] - opt.keys.flatten
          mute.each {|fd| opt[fd] ||= '/dev/null'}
        end
        unless quiet?
          e= ''
          env.each{|k,v| e+="#{k}=#{v} "} if env
          puts "> #{e}#{start_command}"
        end
        @pid= spawn env, start_command, opt
        Process.detach @pid
        puts "< Spawned process #@pid" unless quiet?
      end
      self
    end

    # Stops the child process.
    #
    # If it is already running, then this will do nothing.
    #
    # @return [Boolean] Boolean indicating whether shutdown was successful and process is down.
    def shutdown
      if alive?
        t= Thread.new{ attempt_kill }
        if quiet?
          t.join
        else
          puts "Stopping process #@pid..."
          t.join
        end
      end
      !alive?
    end

    # Checks if the process [*previously started by this class*] is still alive.
    #
    # If it is determined that the process is no longer alive then the internal {#pid PID} is cleared.
    #
    # @return [Boolean]
    def alive?
      return false if @pid.nil?
      alive= begin
          Process.getpgid(@pid) != -1
        rescue Errno::ESRCH
          false
        end
      @pid= nil unless alive
      alive
    end

    protected

    def kill_signals
      [
        ['TERM', 6],
        ['QUIT', 6],
        ['INT' , 6],
        ['KILL', 1],
      ]
    end

    private

    def attempt_kill
      kill_signals.each do |signal, wait_time|
        Process.kill(signal, @pid)
        start_time= Time.now
        sleep 0.1 while alive? and (Time.now - start_time) < wait_time
        break unless alive?
      end
      if alive?
        STDERR.puts "Failed to kill process, PID #@pid"
      end
    end

    # --------------------------------------------------------------------------------------------------------------------
    class << self
      # @!visibility private
      OPTION_TRANSLATION= {
        stdout: :out,
        stderr: :err,
        stdin: :in,
      }.freeze

      # @!visibility private
      def translate_options(prefix='')
        spawn_opts= {}
        OPTION_TRANSLATION.each do |from,to|
          if v= ENV["#{prefix}#{from}"] and !v.empty?
            spawn_opts[to]= v
          end
        end
        spawn_opts
      end
    end

  end
end
