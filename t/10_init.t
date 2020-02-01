#!/usr/bin/perl

use 5.028;
use strict;
use warnings;
use lib 't/lib';

use Test::More;
use Git::Annex;
use File::chdir;
use File::Temp qw(tempdir);
use t::Setup;
use File::Spec::Functions qw(catfile);

{
    my $temp = tempdir CLEANUP => 1;
    my $annex = Git::Annex->new($temp);
    ok $annex->toplevel eq $temp, "constructor sets toplevel to provided dir";
    local $CWD = $temp;
    $annex = Git::Annex->new;
    ok $annex->toplevel eq $temp, "constructor sets toplevel to pwd";
}

{
    my $temp = tempdir CLEANUP => 1;
    my $annex = Git::Annex->new($temp);
    ok !defined $annex->{git}, "Git::Wrapper instance lazily instantiated";
    ok $annex->git->isa("Git::Wrapper") && defined $annex->{git},
      "Git::Wrapper instance available";
    ok $annex->git->dir eq $temp, "Git::Wrapper has correct toplevel";
}

# lazy init of Git::Repository object requires an actual git repo, not
# just an empty tempdir
with_temp_annexes {
    my $annex = Git::Annex->new("source1");
    ok !defined $annex->{repo}, "Git::Repository instance lazily instantiated";
    ok $annex->repo->isa("Git::Repository") && defined $annex->{repo},
      "Git::Repository instance available";
    ok $annex->repo->work_tree eq catfile(shift, "source1"),
      "Git::Repository has correct toplevel";
};

done_testing;
