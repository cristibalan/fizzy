class Fizzy
  class TooManyEntries < RuntimeError; end

  def initialize(files)
    @files = files
  end

  def search(pattern, &block)
    pattern.strip!
    dir_parts = pattern.split("/")

    if pattern[-1,1] == "/"
      file_part = ""
    else
      file_part = dir_parts.pop
    end

    if dir_parts.any?
      dir_regex_raw = "^(.*?)" + dir_parts.map { |part| make_pattern(part) }.join("(.*?/.*?)") + "(.*?)$"
      dir_regex = Regexp.new(dir_regex_raw, Regexp::IGNORECASE)
      dir_parts_length = dir_parts.length
      dir_parts = dir_parts.join("")
    end

    file_regex_raw = "^(.*?)" << make_pattern(file_part) << "(.*)$"
    file_regex = Regexp.new(file_regex_raw, Regexp::IGNORECASE)

    @dir_matches = {}
    @files.map do |file|
      dir_match = match_dir(File.dirname(file), dir_parts, dir_regex, dir_parts_length)
      next if dir_match[:missed]

      file_match = match_file(File.basename(file), file_part, file_regex)
      next if !file_match

      # Shorter files at the top
      # Doing this here instead of passing the full filename to match_file and match_dir
      path_length_offset = 1 + 1.0/file.length
      result = {
        :path => file,
        :score => dir_match[:score] * file_match[:score] * path_length_offset,
        :dir_score => dir_match[:score],
        :file_score => file_match[:score]
      }
      yield result
    end
  end

  def fuf_find(*args)
    res = []
    find(*args).each_with_index do |result, index|
      res << {
        :word => result[:path],
        :abbr => '%2d: %s' % [index + 1, result[:path]],
        :menu => '[%5d]' % [result[:score] * 10000]
      }
    end
    res
  end

  def simple_find(*args)
    find(*args).map do |result|
      [result[:path], result[:score] * 10000]
    end
  end

  def find(pattern, options={})
    options = {
      :max_matches => nil,
      :max_results => 30
    }.merge(options)

    results = case pattern.length
    when 0
      @files[0, options[:max_results]].map{ |f| { :path => f, :score => 0.0001 }}
    when 1
      matched = []
      letter_at_start_of_word_pattern = Regexp.new("(^|\/)#{pattern}[^\/]*$", Regexp::IGNORECASE)
      @files.each { |f| matched << f if f =~ letter_at_start_of_word_pattern; break if matched.length == options[:max_results] }

      if matched.length < options[:max_results]
        @files.each { |f| matched << f if f.index(pattern); break if matched.length == options[:max_results] }
      end
      matched.map{ |f| { :path => f, :score => 0.0001 }}
    else
      matched = []
      search(pattern) do |match|
        matched << match
        break if options[:max_matches] && matched.length >= options[:max_matches]
      end
      matched.sort_by { |r| [-r[:score], r[:path]] }[0, options[:max_results]]
    end
    results
  end

  def inspect
    "#<%s:0x%x>" % [self.class.name, object_id]
  end

  private

    # Takes the given pattern string "foo" and converts it to a new
    # string "(f)([^/]*?)(o)([^/]*?)(o)" that can be used to create
    # a regular expression so that
    #   odd-numbered captures are matches inside the pattern.
    #   even-numbered captures are matches outside the pattern's elements.
      def make_pattern(pattern)
      pattern = pattern.split(//)
      pattern << "" if pattern.empty?

      pattern.inject("") do |regex, character|
        regex << "([^/]*?)" if regex.length > 0
        regex << "(" << Regexp.escape(character) << ")"
      end
    end


    # ["ad", "m", "in_h", "e", "lper.rb"]   # => 2
    # ["", "m", "", "e", "mbers_helper.rb"] # => 1
    def number_of_inside_runs(captures)
      nr_inside_runs = 0
      concating = false

      captures.each_with_index do |s, i|
        if i % 2 == 0
          concating = false if s != ""
        else
          unless concating
            nr_inside_runs += 1
            concating = true
          end
        end
      end
      nr_inside_runs
    end

    # Not used for now.
    #
    # ["ad", "m", "in_h", "e", "lper.rb"]   # => [2, ["m", "e"], ["ad", "in_h", "lper.rb"], ["ad", "(m)", "in_h", "(e)", "lper.rb"]]
    # ["", "m", "", "e", "mbers_helper.rb"] # => [1, ["me"], ["mbers_helper.rb"], ["(me)", "mbers_helper.rb"]]
    def runs(captures)
      runs = []
      inside_runs = []
      outside_runs = []
      nr_inside_runs = 0
      concating = false

      captures.each_with_index do |s, i|
        if i % 2 == 0
          if s != ""
            if nr_inside_runs > 0
              runs.last << ")"
            end
            runs << s
            outside_runs << s
            concating = false
          end
        else
          if concating
            runs.last << s
            inside_runs.last << s
          else
            runs << "(#{s}"
            inside_runs << s
            nr_inside_runs += 1
            concating = true
          end
        end
      end
      [nr_inside_runs, inside_runs, outside_runs, runs]
    end

    # Given a MatchData object +match+ and a number of "inside"
    # segments to support, compute both the match score and  the
    # highlighted match string. The "inside segments" refers to how
    # many patterns were matched in this one match. For a file name,
    # this will always be one. For directories, it will be one for
    # each directory segment in the original pattern.
    def build_match_result(match, pattern, inside_segments)
      path = match.captures.join("")
      nr_inside_runs = number_of_inside_runs(match.captures)

      segment_bonuses = 0
      (0..(match.captures.length / 2 - 1)).each do |x|
        i = 2 * x + 1
        c = match.captures[i]

        if (
          match.captures[i-1][-1,1] == "-" ||
          match.captures[i-1][-1,1] == "_" ||
          match.captures[i+1][0,1] == "-" ||
          match.captures[i+1][0,1] == "_"
        )
          segment_bonuses += 1
        end
      end

      total_chars = path.length
      pattern_chars = pattern.length

      run_ratio = inside_segments.to_f / (nr_inside_runs+1)
      char_ratio = pattern_chars.to_f / total_chars

      starts_with = match.captures[0] == ""
      ends_with = match.captures.last == "" || match.captures.last == "." || match.captures.last =~ /#{pattern[-2,2]}\.\w+$/

      # score = char_ratio * (run_ratio ** 0.5) # more importance to spread apart matches
      score = char_ratio * (run_ratio ** 2) # low importance to spread apart matches
      score *= 1.99 if starts_with
      score *= 1.5 if ends_with
      score *= (segment_bonuses/2.0 + 1.01) # two segment starts are just a bit better than start of word

      # Fizzy is a positive thinker, no penalties yet.
      # Excluding all these files before they get ranked is probably wiser anyway.
      # score /= 2 if match.string =~ /\.(gif|jpg|png|tiff|exe|pdf|doc|xls|ppt)$/

      score = 0.001 if score == 0
      return { :score => score, :path => path }
    end

    # Match the given dir against the regex, caching the result in +dir_matches+.
    # If +dir+ is already cached in the dir_matches cache, just return the cached
    # value.
    def match_dir(dir, pattern, dir_regex, dir_parts_length)
      return @dir_matches[dir] if @dir_matches.key?(dir)

      @dir_matches[dir] = case pattern.length
      when 0
        { dir => dir, :score => 1 }
      when 1
        if dir =~ /(^|\/)#{pattern}/
          { :dir => dir,  :score => 2 }
        else
          if dir.index(pattern)
            { :dir => dir,  :score => 1.5 }
          else
            { :dir => dir, :score => 1, :missed => true }
          end
        end
      else
        if match = dir.match(dir_regex)
          build_match_result(match, pattern, dir_parts_length)
        else
          { :dir => dir, :score => 1, :missed => true }
        end
      end
    end

    def match_file(file, pattern, file_regex)
      case pattern.length
      when 0
        { :score => 1 }
      when 1
        case file.index(pattern)
        when 0
          score = 2
        when nil
          return nil
        else
          score = 1
        end
        { :score => score}
      else
        if match = File.basename(file).match(file_regex)
          build_match_result(match, pattern, 1)
        end
      end
    end
end
