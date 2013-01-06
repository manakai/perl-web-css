# -*- Makefile -*-

all:

PERL = ./perl
PROVE = ./prove

## ------ Setup ------

WGET = wget

deps: pmbp-install

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(WGET) -O $@ https://raw.github.com/wakaba/perl-setupenv/master/bin/pmbp.pl
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --update-pmbp-pl
pmbp-update: pmbp-upgrade
	perl local/bin/pmbp.pl --update
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl --install \
            --create-perl-command-shortcut perl \
            --create-perl-command-shortcut prove

## ------ Tests ------

test: test-deps test-main

test-deps: deps

test-main:
	$(PROVE) t/modules/*.t t/parsing/*.t

## License: Public Domain.
