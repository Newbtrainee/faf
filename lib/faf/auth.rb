module Faf
  class Auth
    def self.instance
      @instance ||= new
    end

    def token
      stored_options = { username: username, server: 'github.com', label: 'faf' }
      stored_token = Faf::Security.get(stored_options)
      unless stored_token
        stored_token = github_token
        Faf::Security.store!(stored_options.merge(password: stored_token))
        puts 'Token saved to keychain.'
      end
      stored_token
    end

    def username
      @username ||= begin
        username = get_git_username
        username.chomp! if username
        username = get_username if username.nil? || username.empty?
        username
      end
    end

    private

    def get_git_username
      Faf::Shell.system!('git config github.user')
    rescue RuntimeError
      nil
    end

    def github_token(code = nil)
      github(code).auth.create(scopes: ['public_repo'], note: note).token
    rescue Github::Error::Unauthorized => e
      case e.response_headers['X-GitHub-OTP']
      when /required/ then
        github_token(get_code)
      else
        raise e
      end
    rescue Github::Error::UnprocessableEntity => e
      raise e, 'A faf token already exists! Please revoke all previously-generated faf personal access tokens at https://github.com/settings/tokens.'
    end

    def password
      @password ||= get_password
    end

    def note
      "Fui (https://github.com/dblock/faf) on #{Socket.gethostname}"
    end

    def github(code = nil)
      Github.new do |config|
        config.basic_auth = [username, password].join(':')
        if code
          config.connection_options = {
            headers: {
              'X-GitHub-OTP' => code
            }
          }
        end
      end
    end

    def get_username
      print 'Enter GitHub username: '
      username = $stdin.gets
      username.chomp! if username
      username
    rescue Interrupt => e
      raise e, 'ctrl + c'
    end

    def get_password
      print "Enter #{username}'s GitHub password (never stored): "
      get_secure
    end

    def get_code
      print 'Enter GitHub 2FA code: '
      get_secure
    end

    def get_secure
      current_tty = `stty -g`
      system 'stty raw -echo -icanon isig' if $CHILD_STATUS.success?
      input = ''
      while (char = $stdin.getbyte) && !((char == 13) || (char == 10))
        if (char == 127) || (char == 8)
          input[-1, 1] = '' unless input.empty?
        else
          $stdout.write '*'
          input << char.chr
        end
      end
      print "\r\n"
      input
    rescue Interrupt => e
      raise e, 'ctrl + c'
    ensure
      system "stty #{current_tty}" unless current_tty.empty?
    end
  end
end
