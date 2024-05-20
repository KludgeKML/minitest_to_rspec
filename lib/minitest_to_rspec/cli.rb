# frozen_string_literal: true

require 'fileutils'
require 'minitest_to_rspec'
require 'optimist'

module MinitestToRspec
  # Command-Line Interface (CLI) instantiated by `bin/mt2rspec`
  class CLI
    E_USAGE               = 1
    E_FILE_NOT_FOUND      = 2
    E_FILE_ALREADY_EXISTS = 3
    E_CONVERT_FAIL        = 4
    E_CANNOT_CREATE_TARGET_DIR = 5

    BANNER = <<~EOS
      Usage: mt2rspec [--rails] [--mocha] source_file [target_file]

      Reads source_file, writes target_file. If target_file is omitted,
      its location will be inferred. For example, test/fruit/banana_test.rb
      implies spec/fruit/banana_spec.rb. If the target directory doesn't
      exist, it will be created.

      Options:
    EOS
    OPT_MOCHA = 'Convert mocha to rspec-mocks. (Experimental)'
    OPT_RAILS = <<~EOS.tr("\n", ' ').freeze
      Requires rails_helper instead of spec_helper.
      Passes :type metadatum to RSpec.describe.
    EOS

    attr_reader :source, :target

    def initialize(args)
      opts = parse_args(args)
      @rails = opts[:rails]
      @mocha = opts[:mocha]
      case args.length
      when 2
        @source, @target = args
      when 1
        @source = args[0]
        @target = infer_target_from @source
      else
        warn 'Please specify source file or directory'
        exit E_USAGE
      end
    end

    def run
      if File.directory?(@source)
        Dir.glob("#{@source}/**/*_test.rb") do |file|
          convert_file(file, infer_target_from(file))
        end
      else
        convert_file(@source, @target)
      end
    end

    def convert_file(file_source, file_target)
      puts("Converting #{file_source} to #{file_target}")
      assert_file_exists(file_source)
      assert_file_does_not_exist(file_target)
      ensure_target_directory(file_target)
      File.write(file_target, converter.convert(File.read(file_source), file_source))
    rescue StandardError => e
      warn "ERROR: Failed to convert: #{e}"
    end

    private

    def assert_file_exists(file)
      unless File.exist?(file)
        raise "File not found: #{file}"
      end
    end

    def assert_file_does_not_exist(file)
      if File.exist?(file)
        raise "File already exists: #{file}"
      end
    end

    def converter
      Converter.new(mocha: @mocha, rails: @rails)
    end

    def ensure_target_directory(target)
      dir = File.dirname(target)
      return if Dir.exist?(dir)
      begin
        FileUtils.mkdir_p(dir)
      rescue SystemCallError => e
        raise "Cannot create target dir: #{dir} - #{e}"
      end
    end

    def infer_target_from(source)
      source
        .gsub(/\Atest/, 'spec')
        .gsub(/_test.rb\Z/, '_spec.rb')
    end

    def parse_args(args)
      Optimist.options(args) do
        version MinitestToRspec.gem_version.to_s
        banner BANNER
        opt :rails, OPT_RAILS, short: :none
        opt :mocha, OPT_MOCHA, short: :none
      end
    end

    def read_source
      File.read(source)
    end

    def write_target(str)
      File.write(target, str)
    end
  end
end
