#!/usr/bin/perl

use 5.028;
use strict;
use warnings;
use lib 't/lib';

use Cwd qw(realpath);
use Test::More;
use Git::Annex;
use File::Spec::Functions qw(catfile rel2abs);
use t::Setup;
use Storable;
use Data::Compare;
use File::chdir;
use File::Basename qw(basename);

with_temp_annexes {
    my $temp  = shift;
    my $annex = Git::Annex->new("source1");

    my $unused_info = catfile($temp, qw(source1 .git annex unused_info));
    is $annex->_git_path("blah", "foo"),
      catfile($temp, qw(source1 .git blah foo)),
      "_git_path resolves a path";
    is $annex->_unused_cache, $unused_info,
      "_unused_cache resolves to correct path";
    $annex->{_unused} = { foo => "bar" };
    $annex->_store_unused_cache;
    ok Compare($annex->{_unused}, retrieve $unused_info),
      "_store_unused_cache stores the cache";
    $annex->_clear_unused_cache;
    ok !exists $annex->{_unused}, "_clear_unused_cache clears unused hashref";
    ok !-f $unused_info, "_clear_unused_cache deletes the cache";

    {
        local $CWD = catfile qw(source1 foo foo2);
        my $contentlocation = realpath rel2abs readlink "baz";
        my $key             = basename readlink "baz";
        is $annex->abs_contentlocation($key), $contentlocation,
          "it returns an absolute path to the content for foo/foo2/baz";
        is $annex->abs_contentlocation("foo"), undef,
          "it returns undef for a nonsense key";
    }
};

done_testing;
