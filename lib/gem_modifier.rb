require 'ruby_parser'
require 'fileutils'
require 'tempfile'

module Hokkaido
  class GemModifier
    attr_reader :gem_name, :init_lib, :lib_folder

    def initialize(info)
      @gem_name, @init_lib, @lib_folder = info
      @require_libs = []
    end

    def manifest!
      parse_gem(@init_lib)
      write_manifest
    end

    def parse_gem(init_lib)
      puts "Processing: #{init_lib}"
      init_file = File.read(init_lib)
      current_file = ""

      init_file.each_line do |line|
        if line.strip =~ /^require/
          parser = RubyParser.new
          sexp = parser.parse(line)
          call = sexp[2]


          unless call == :require
            # WEIRD SHIT IS HAPPENING
            current_file += line
            next
          end

          require_type = sexp[3][1][0]
          library = sexp[3][1][1]

          if require_type == :str && library.match(@gem_name)
            # fold in
            appfiles = INCLUDE_STRING.gsub("RELATIVE_LIBRARY_PATH", "#{library}.rb")
            unless @require_libs.include?(appfiles)
              @require_libs << appfiles
              full_rb_path = File.join([@lib_folder, "#{library}.rb"])
              parse_gem(full_rb_path)
            end
          else
            current_file += "# FIXME: #require is not supported in RubyMotion\n"
            current_file += "# #{line}"
            next
          end
          # comment it out
          current_file += "# #{line}"
          next
        end

        # dont intefere
        current_file += line
      end

      # replace file
      File.open(init_lib, 'w') {|f| f.write(current_file) }

    end

    def write_manifest

      # creates config manifest
      @manifest = RUBYMOTION_GEM_CONFIG.gsub("MAIN_CONFIG_FILES", @require_libs.uniq.join("\n"))

      File.open(@init_lib, 'a') {|f| f.puts(@manifest) }

    end
  end
end