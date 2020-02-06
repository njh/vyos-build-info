RUBY := ruby


vyos-package-list.txt: vyos-package-list.rb
	$(RUBY) vyos-package-list.rb > $@ || rm -f $@

