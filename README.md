fizzy
=====

Fizzy is gangsta file matching. Based on Jamis Buck's now unmaintained fuzzy_file_finder.

It does not do its own file exclusions, and is a more optimised for edge cases (empty pattern, one letter pattern).

Works great with [fuf-fizzy](http://github.com/evilchelu/fuf-fizzy)

Installing
----------

    sudo gem install evilchelu-fizzy

Usage
-----

    cmd = 'find -d . -type f -not -path "*.git*" -not -name .DS_Store -not -name "*.log" | sed -e "s/^\.\///"'
    fizzy = Fizzy.new(`#{cmd}`.map{|f|f.chomp})
    
    fizzy.find('pie')
    fizzy.find('mmm/pie')

TODO
----

* helper to grab files with find and convert an excludes list into 'find' excludes
* more tests

Note on Patches/Pull Requests
-----------------------------
 
* Fork the project.
* Create a feature branch
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a
  future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but 
   don't do it in the feature branch)
* Send me a pull request or add a github issue

Copyright
---------

Copyright (c) 2009 Cristi Balan.

Released under the [WTFPL](http://sam.zoy.org/wtfpl)
