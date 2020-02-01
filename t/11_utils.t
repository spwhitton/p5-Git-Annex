#!/usr/bin/perl

use 5.028;
use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Git::Annex;
use File::Spec::Functions qw(catfile);
use t::Setup;
use File::Slurp;

with_temp_annexes {
    my $temp  = shift;
    my $annex = Git::Annex->new("source1");
    my $unused_info = catfile($temp, qw(source1 .git annex unused_info));
    ok $annex->_git_path("blah") eq catfile($temp, qw(source1 .git blah)),
      "_git_path resolves a path";
    ok $annex->_unused_cache eq $unused_info,
      "_unused_cache resolves to correct path";
    $annex->{_unused} = { foo => "bar" };
    write_file $unused_info, "baz\n";
    $annex->_clear_unused_cache;
    ok !exists $annex->{_unused}, "_clear_unused_cache clears unused hashref";
    ok !-f $unused_info, "_clear_unused_cache deletes the cache";
};

done_testing;
