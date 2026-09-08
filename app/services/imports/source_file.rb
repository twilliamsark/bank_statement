# frozen_string_literal: true

require "stringio"
require "tmpdir"

module Imports
  # Normalizes an upload or filesystem path into a path the gem extractors can read.
  class SourceFile
    attr_reader :path, :original_filename, :import_format

    def self.open(path: nil, io: nil, filename: nil)
      new(path: path, io: io, filename: filename).tap(&:prepare!)
    end

    def initialize(path: nil, io: nil, filename: nil)
      @given_path = path
      @io = io
      @filename = filename
      @tempfile = nil
      @path = nil
      @original_filename = nil
      @import_format = nil
    end

    def prepare!
      if @given_path.present?
        raise Imports::Error, "file is required" if @given_path.to_s.strip.empty?
        raise Imports::Error, "file not found: #{@given_path}" unless File.exist?(@given_path)

        @path = @given_path.to_s
        @original_filename = File.basename(@path)
      elsif @io
        name = @filename.presence || (@io.respond_to?(:original_filename) && @io.original_filename)
        raise Imports::Error, "filename is required" if name.blank?

        @original_filename = File.basename(name.to_s)
        ext = File.extname(@original_filename)
        @tempfile = Tempfile.new([ "import", ext ])
        @tempfile.binmode
        IO.copy_stream(@io, @tempfile)
        @tempfile.flush
        @tempfile.rewind
        @path = @tempfile.path
      else
        raise Imports::Error, "path or io is required"
      end

      @import_format = format_for(@original_filename)
      self
    end

    def attach_to(record)
      # StringIO so Active Storage can re-read after this method returns
      # (File.open blocks close the handle before upload finishes).
      record.source_file.attach(
        io: StringIO.new(File.binread(path)),
        filename: original_filename,
        content_type: content_type
      )
    end

    def cleanup!
      return unless @tempfile

      @tempfile.close!
      @tempfile = nil
    end

    private

    def format_for(name)
      case File.extname(name.to_s).downcase
      when ".pdf" then "pdf"
      when ".csv" then "csv"
      else
        raise Imports::Error, "unsupported file type (expected .pdf or .csv): #{name}"
      end
    end

    def content_type
      import_format == "pdf" ? "application/pdf" : "text/csv"
    end
  end
end
