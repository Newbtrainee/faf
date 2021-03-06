module Faf
  module Security
    class << self
      def store!(options)
        Faf::Shell.system!(security('add', options))
      end

      def get(options)
        Faf::Shell.system!(security('find', options))
      rescue RuntimeError
        nil
      end

      private

      def security(command = nil, options = nil)
        run = [security_path]
        run << "#{command}-internet-password"
        run << "-a #{options[:username]}"
        run << "-s #{options[:server]}"
        if command == 'add'
          run << "-l #{options[:label]}"
          run << '-U'
          run << "-w #{options[:password]}" if options.key?(:password)
        else
          run << '-w'
        end
        run.join ' '
      end

      def security_path
        @security_path ||= begin
          `which security`.chomp
        rescue StandardError
          'security'
        end
      end
    end
  end
end
