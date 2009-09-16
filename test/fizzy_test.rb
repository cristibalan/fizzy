require File.expand_path('../test_helper', __FILE__)

class Fizzy
  def s(pattern, i = 0)
    s = simple_find(pattern)[i].last
    # puts "%-15.15s | %10.5f\n" % [pattern, s]
    s
  end
end

describe "Fizzy" do
  before do
    @fizzy ||= Fizzy.new(File.readlines(File.join(File.dirname(__FILE__), "fixtures", "list1.txt")).map{|f|f.chomp})
  end

  it "should fizzle like the shizzle" do
    f = Fizzy.new("test/functional/admin/members_controller_test.rb")

    f.s("mem").should > f.s("emb")                # start of word wins
    f.s("memcon").should > f.s("embcon")          # start of word wins over one segment match
    f.s("metr").should > f.s("cotr")              # start of word wins over one segment match
    f.s("metret").should < f.s("cotrte")          # start of word loses to two segment matches

    f.s("emb").should > f.s("emn")                # smaller number of runs wins
    f.s("emn").should > f.s("emnes")              # smaller number of runs wins
    f.s("emn").should < f.s("emntrolles")         # smaller number of runs eventually loses to longer match
    f.s("memb").should > f.s("mcon")              # smaller number of runs wins
    f.s("memb").should < f.s("mcontro")           # smaller number of runs wins

    f.s("ment").should < f.s("mest")              # end of word wins
    f.s("cont").should > f.s("cost")              # end of word loses to one segment match

    f1 = Fizzy.new("test/functional/admin/members_controller_test.rb")
    f2 = Fizzy.new("test/functional/admin/memabers_controller_test.rb")

    f1.s("mem").should > f2.s("mem")             # shorter paths win
  end
end

xdescribe "Fizzy, about performance" do
  # Conclusions after these benchmarks
  #   - optimised for empty strings and single letter searches
  #   - currently, two letter searches are the slowest
  it "should fizzle" do
    @fizzy ||= Fizzy.new(File.readlines(File.join(File.dirname(__FILE__), "fixtures", "list2.txt")).map{|f|f.chomp})

    require 'benchmark'
    n = 1
    Benchmark.bm do |x|
      x.report { n.times do; p @fizzy.fuf_find("").length; end }
      x.report { n.times do; p @fizzy.fuf_find("h").length; end }
      x.report { n.times do; p @fizzy.fuf_find("h/").length; end }
      x.report { n.times do; p @fizzy.fuf_find("h/a").length; end }
      puts "--"

      x.report { n.times do; p @fizzy.fuf_find("a").length; end }
      x.report { n.times do; p @fizzy.fuf_find("a/").length; end }
      x.report { n.times do; p @fizzy.fuf_find("a/h").length; end }
      x.report { n.times do; p @fizzy.fuf_find("a/h/").length; end }
      x.report { n.times do; p @fizzy.fuf_find("a/h/a").length; end }
      puts "--"

      x.report { n.times do; p @fizzy.fuf_find("e").length; end }
      x.report { n.times do; p @fizzy.fuf_find("em").length; end }
      x.report { n.times do; p @fizzy.fuf_find("emi").length; end }

      x.report { n.times do; @fizzy.fuf_find("a/help/oner").join("\n"); end }
    end
  end
end
