#!/usr/bin/perl

use 5.028;
use strict;
use warnings;
use lib 't/lib';

use Test::More;
use t::Setup;
use File::chdir;
use File::Spec::Functions qw(rel2abs);

# make sure that `make test` will always use the right version of the
# script we seek to test
my $aru = "annex-review-unused";
$aru = rel2abs "blib/script/annex-review-unused"
  if -x "blib/script/annex-review-unused";

with_temp_annexes {
    my (undef, $source1) = @_;

    {
        local $CWD = "source1";
        system $aru;
        ok !$?, "it exits zero when no unused files";
        sleep 1;
        $source1->rm("foo/foo2/baz");
        $source1->commit({ message => "rm" });
        my @output = `$aru --just-print`;
        my $exit = $? >> 8;
        ok $?, "it exits nonzero when unused files";
        ok 20 < @output && @output < 30, "it prints ~two log entries";
        like $output[5], qr/unused file #1/, "it prints an expected line";
    }
}
;

done_testing;
