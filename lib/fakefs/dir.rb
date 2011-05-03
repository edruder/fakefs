module FakeFS
  class Dir
    include Enumerable

    def initialize(string)
      raise Errno::ENOENT, string unless FileSystem.find(string)
      @path = string
      @open = true
      @pointer = 0
      @contents = [ '.', '..', ] + FileSystem.find(@path).values
    end

    def close
      @open = false
      @pointer = nil
      @contents = nil
      nil
    end

    def each(&block)
      while f = read
        yield f
      end
    end

    def path
      @path
    end

    def pos
      @pointer
    end

    def pos=(integer)
      @pointer = integer
    end

    def read
      raise IOError, "closed directory" if @pointer == nil
      n = @contents[@pointer]
      @pointer += 1
      n.to_s.gsub(path + '/', '') if n
    end

    def rewind
      @pointer = 0
    end

    def seek(integer)
      raise IOError, "closed directory" if @pointer == nil
      @pointer = integer
      @contents[integer]
    end

    def self.[](pattern)
      glob(pattern)
    end

    def self.chdir(dir, &blk)
      FileSystem.chdir(dir, &blk)
    end

    def self.chroot(string)
      # Not implemented yet
    end

    def self.delete(string)
      raise SystemCallError, "No such file or directory - #{string}" unless FileSystem.find(string).values.empty?
      FileSystem.delete(string)
    end

    def self.entries(dirname)
      raise SystemCallError, dirname unless FileSystem.find(dirname)
      Dir.new(dirname).map { |file| File.basename(file) }
    end

    def self.foreach(dirname, &block)
      Dir.open(dirname) { |file| yield file }
    end

    def self.glob(pattern, &block)
      files = [FileSystem.find(pattern) || []].flatten.map(&:to_s).sort
      block_given? ? files.each { |file| block.call(file) } : files
    end

    def self.mkdir(string, integer = 0)
      parent = string.split('/')
      parent.pop
      raise Errno::ENOENT, "No such file or directory - #{string}" unless parent.join == "" || FileSystem.find(parent.join('/'))
      raise Errno::EEXIST, "File exists - #{string}" if File.exists?(string)
      FileUtils.mkdir_p(string)
    end

    def self.open(string, &block)
      if block_given?
        Dir.new(string).each { |file| yield(file) }
      else
        Dir.new(string)
      end
    end

    def self.tmpdir
      '/tmp'
    end

    def self.pwd
      FileSystem.current_dir.to_s
    end

    # This code has been borrowed from Rubinius
    def self.mktmpdir(prefix_suffix = nil, tmpdir = nil)
      case prefix_suffix
      when nil
        prefix = "d"
        suffix = ""
      when String
        prefix = prefix_suffix
        suffix = ""
      when Array
        prefix = prefix_suffix[0]
        suffix = prefix_suffix[1]
      else
        raise ArgumentError, "unexpected prefix_suffix: #{prefix_suffix.inspect}"
      end

      t = Time.now.strftime("%Y%m%d")
      n = nil

      begin
        path = "#{tmpdir}/#{prefix}#{t}-#{$$}-#{rand(0x100000000).to_s(36)}"
        path << "-#{n}" if n
        path << suffix
        mkdir(path, 0700)
      rescue Errno::EEXIST
        n ||= 0
        n += 1
        retry
      end

      if block_given?
        begin
          yield path
        ensure
          require 'fileutils'
          # This here was using FileUtils.remove_entry_secure instead of just
          # .rm_r. However, the security concerns that apply to
          # .rm_r/.remove_entry_secure shouldn't apply to a test fake
          # filesystem. :^)
          FileUtils.rm_r path
        end
      else
        path
      end
    end

    class << self
      alias_method :getwd, :pwd
      alias_method :rmdir, :delete
      alias_method :unlink, :delete
    end
  end
end
