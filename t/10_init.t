#!/usr/bin/perl

use 5.028;
use strict;
use warnings;

use Test::More;
use Git::Annex;
use File::chdir;
use File::Slurp;
use File::Temp qw(tempdir);

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
with_temp_annex(sub {
    my $temp = shift;
    my $annex = Git::Annex->new($temp);
    ok !defined $annex->{repo}, "Git::Repository instance lazily instantiated";
    ok $annex->repo->isa("Git::Repository") && defined $annex->{repo},
      "Git::Repository instance available";
    ok $annex->repo->work_tree eq $temp, "Git::Repository has correct toplevel";
});

sub with_temp_annex {
    my $temp = tempdir CLEANUP => 1;
    {
        local $CWD = $temp;
        system qw(git init);
        system qw(git annex init);
        write_file "foo", "my cool big file\n";
        system qw(git annex add foo);
        system qw(git commit -madd);
    }
    &{$_[0]}($temp);
}

done_testing;
